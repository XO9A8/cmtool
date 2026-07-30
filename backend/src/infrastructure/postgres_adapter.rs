use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

#[allow(dead_code)]
pub struct MatchRecordDb {
    pub player_id: Uuid,
    pub opponent_id: Uuid,
    pub match_type: String,
    pub result: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub possession: f64,
    pub passes_completed: i32,
    pub passes_attempted: i32,
    pub shots_on_target: i32,
    pub shots_total: i32,
    pub interceptions: i32,
    pub screenshot_hash: String,
    pub new_rating: i32,
}

#[allow(dead_code)]
pub async fn save_match_transaction(
    pool: &PgPool,
    record: &MatchRecordDb,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    let match_id = Uuid::new_v4();

    // 1. Insert Match Record
    sqlx::query(
        r#"
        INSERT INTO Match_Records (
            id, player_id, opponent_id, match_type, result, goals_for, goals_against,
            possession, passes_completed, passes_attempted, shots_on_target, shots_total,
            interceptions, screenshot_hash
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        "#,
    )
    .bind(match_id)
    .bind(record.player_id)
    .bind(record.opponent_id)
    .bind(&record.match_type)
    .bind(&record.result)
    .bind(record.goals_for)
    .bind(record.goals_against)
    .bind(record.possession)
    .bind(record.passes_completed)
    .bind(record.passes_attempted)
    .bind(record.shots_on_target)
    .bind(record.shots_total)
    .bind(record.interceptions)
    .bind(&record.screenshot_hash)
    .execute(&mut *tx)
    .await?;

    // 2. Fetch Old Skill Rating
    let old_rating_row: Option<(i32,)> = sqlx::query_as(
        "SELECT skill_rating FROM Player_Profiles WHERE user_id = $1",
    )
    .bind(record.player_id)
    .fetch_optional(&mut *tx)
    .await?;

    let old_rating = old_rating_row.map(|r| r.0).unwrap_or(1000);

    // 3. Upsert Player Profile Rating
    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id, skill_rating, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET skill_rating = EXCLUDED.skill_rating, updated_at = NOW()
        "#,
    )
    .bind(record.player_id)
    .bind(record.new_rating)
    .execute(&mut *tx)
    .await?;

    // 4. Log Elo Rating History
    sqlx::query(
        r#"
        INSERT INTO Elo_History (player_id, match_record_id, rating_before, rating_after)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(record.player_id)
    .bind(match_id)
    .bind(old_rating)
    .bind(record.new_rating)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(match_id)
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct LeaderboardRow {
    pub username: String,
    pub skill_rating: Option<i32>,
    pub play_style: Option<String>,
}

pub async fn get_club_leaderboard_db(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<LeaderboardRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, LeaderboardRow>(
        r#"
        SELECT u.username, pp.skill_rating, pp.form_rating, pp.play_style
        FROM Club_Memberships cm
        JOIN Users u ON u.id = cm.player_id
        LEFT JOIN Player_Profiles pp ON pp.user_id = u.id
        WHERE cm.club_id = $1
        ORDER BY pp.skill_rating DESC NULLS LAST
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(Debug, Serialize)]
pub struct H2hDbResult {
    pub total_matches: i64,
    pub p1_wins: i64,
    pub draws: i64,
    pub p2_wins: i64,
    pub avg_goal_diff: f64,
}

pub async fn get_h2h_record_db(
    pool: &PgPool,
    p1_id: Uuid,
    p2_id: Uuid,
) -> Result<H2hDbResult, sqlx::Error> {
    let row: Option<(i64, i64, i64, i64, Option<f64>)> = sqlx::query_as(
        r#"
        SELECT 
            COUNT(*) as total_matches,
            COUNT(*) FILTER (WHERE (player_id = $1 AND result = 'win') OR (opponent_id = $1 AND result = 'loss')) as p1_wins,
            COUNT(*) FILTER (WHERE result = 'draw') as draws,
            COUNT(*) FILTER (WHERE (player_id = $2 AND result = 'win') OR (opponent_id = $2 AND result = 'loss')) as p2_wins,
            AVG(CASE WHEN player_id = $1 THEN goals_for - goals_against ELSE goals_against - goals_for END)::FLOAT as avg_goal_diff
        FROM Match_Records
        WHERE (player_id = $1 AND opponent_id = $2) OR (player_id = $2 AND opponent_id = $1)
        "#,
    )
    .bind(p1_id)
    .bind(p2_id)
    .fetch_optional(pool)
    .await?;

    if let Some((total_matches, p1_wins, draws, p2_wins, avg_gd)) = row {
        Ok(H2hDbResult {
            total_matches,
            p1_wins,
            draws,
            p2_wins,
            avg_goal_diff: avg_gd.unwrap_or(0.0),
        })
    } else {
        Ok(H2hDbResult {
            total_matches: 0,
            p1_wins: 0,
            draws: 0,
            p2_wins: 0,
            avg_goal_diff: 0.0,
        })
    }
}
