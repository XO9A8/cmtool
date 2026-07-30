//! # PostgreSQL Infrastructure Adapter Module
//!
//! Provides transaction-safe database interactions with PostgreSQL using SQLx,
//! including match record insertion, player profile Elo rating updates, Elo history logging,
//! real-time club rankings queries, and Head-to-Head stats queries.

use sqlx::{FromRow, PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::domain::{
    elo::EloResult,
    mps::MpsResult,
    play_style::{classify_play_style, PlayerMatchStatsSummary},
};

/// Parameters required to execute a transaction-safe match record insertion and rating update.
pub struct SaveMatchTransactionInput {
    pub player_id: Uuid,
    pub opponent_id: Uuid,
    pub club_id: Option<Uuid>,
    pub match_type: String,
    pub goals_for: u32,
    pub goals_against: u32,
    pub possession: f64,
    pub passes_completed: u32,
    pub passes_attempted: u32,
    pub shots_on_target: u32,
    pub shots_total: u32,
    pub interceptions: u32,
    pub screenshot_hash: String,
    pub elo_result: EloResult,
    pub mps_result: MpsResult,
}

/// Executes an atomic PostgreSQL database transaction that:
/// 1. Inserts the match stats record into `Match_Records`.
/// 2. Upserts the player's updated skill rating and form rating into `Player_Profiles`.
/// 3. Logs rating changes into `Elo_History` audit trail.
pub async fn save_match_transaction(
    pool: &PgPool,
    input: SaveMatchTransactionInput,
) -> Result<Uuid, sqlx::Error> {
    let mut tx: Transaction<'_, Postgres> = pool.begin().await?;

    let match_id = Uuid::new_v4();

    // 1. Insert match record
    sqlx::query(
        r#"
        INSERT INTO Match_Records (
            id, player_id, opponent_id, club_id, match_type, goals_for, goals_against,
            possession, passes_completed, passes_attempted, shots_on_target, shots_total,
            interceptions, match_performance_score, screenshot_hash
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        "#,
    )
    .bind(match_id)
    .bind(input.player_id)
    .bind(input.opponent_id)
    .bind(input.club_id)
    .bind(input.match_type)
    .bind(input.goals_for as i32)
    .bind(input.goals_against as i32)
    .bind(input.possession)
    .bind(input.passes_completed as i32)
    .bind(input.passes_attempted as i32)
    .bind(input.shots_on_target as i32)
    .bind(input.shots_total as i32)
    .bind(input.interceptions as i32)
    .bind(input.mps_result.mps)
    .bind(input.screenshot_hash)
    .execute(&mut *tx)
    .await?;

    // 2. Upsert player profile rating
    let pass_acc = if input.passes_attempted > 0 {
        (input.passes_completed as f64 / input.passes_attempted as f64) * 100.0
    } else {
        0.0
    };
    let shot_eff = if input.shots_on_target > 0 {
        (input.goals_for as f64 / input.shots_on_target as f64) * 100.0
    } else {
        0.0
    };

    let play_style = classify_play_style(&PlayerMatchStatsSummary {
        avg_possession: input.possession,
        avg_pass_accuracy: pass_acc,
        avg_shot_efficiency: shot_eff,
        avg_interceptions: input.interceptions as f64,
    });

    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id, skill_rating, form_rating, play_style)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id) DO UPDATE SET
            skill_rating = $2,
            form_rating = $3,
            play_style = $4,
            updated_at = NOW()
        "#,
    )
    .bind(input.player_id)
    .bind(input.elo_result.new_rating)
    .bind(input.mps_result.mps)
    .bind(play_style.as_str())
    .execute(&mut *tx)
    .await?;

    // 3. Log Elo History audit log
    sqlx::query(
        r#"
        INSERT INTO Elo_History (player_id, match_record_id, rating_before, rating_after, rating_delta)
        VALUES ($1, $2, $3, $4, $5)
        "#,
    )
    .bind(input.player_id)
    .bind(match_id)
    .bind(input.elo_result.new_rating - input.elo_result.rating_delta)
    .bind(input.elo_result.new_rating)
    .bind(input.elo_result.rating_delta)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(match_id)
}

/// Club leaderboard database row representation.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct LeaderboardRow {
    pub user_id: Uuid,
    pub username: String,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
}

/// Fetches real-time club player rankings sorted by skill rating.
#[allow(dead_code)]
pub async fn get_club_leaderboard_db(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<LeaderboardRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, LeaderboardRow>(
        r#"
        SELECT u.id as user_id, u.username, p.skill_rating, p.form_rating, p.play_style
        FROM Club_Memberships cm
        JOIN Users u ON cm.player_id = u.id
        JOIN Player_Profiles p ON u.id = p.user_id
        WHERE cm.club_id = $1
        ORDER BY p.skill_rating DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Head-to-Head database query result row.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct H2hDbResult {
    pub total_matches: i64,
    pub p1_wins: i64,
    pub draws: i64,
    pub p2_wins: i64,
}

/// Queries historical Head-to-Head match records between two players.
#[allow(dead_code)]
pub async fn get_h2h_record_db(
    pool: &PgPool,
    p1_id: Uuid,
    p2_id: Uuid,
) -> Result<H2hDbResult, sqlx::Error> {
    let row = sqlx::query_as::<_, H2hDbResult>(
        r#"
        SELECT 
            COUNT(*) as total_matches,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for > goals_against) OR (opponent_id = $1 AND goals_against > goals_for)) as p1_wins,
            COUNT(*) FILTER (WHERE goals_for = goals_against) as draws,
            COUNT(*) FILTER (WHERE (player_id = $2 AND goals_for > goals_against) OR (opponent_id = $2 AND goals_against > goals_for)) as p2_wins
        FROM Match_Records
        WHERE (player_id = $1 AND opponent_id = $2) OR (player_id = $2 AND opponent_id = $1)
        "#,
    )
    .bind(p1_id)
    .bind(p2_id)
    .fetch_one(pool)
    .await?;

    Ok(row)
}
