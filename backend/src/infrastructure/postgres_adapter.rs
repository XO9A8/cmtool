//! # PostgreSQL Infrastructure Adapter Module
//!
//! Provides transaction-safe database interactions with PostgreSQL using SQLx,
//! including match record insertion, player profile Elo rating updates, Elo history logging,
//! real-time club rankings queries, Head-to-Head stats queries, clubs management,
//! dispute persistence, tournament bracket fetching, and player analytics.

use sqlx::{FromRow, PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::domain::{
    elo::EloResult,
    mps::MpsResult,
    play_style::{classify_play_style, PlayerMatchStatsSummary},
};

// ─────────────────────────────────────────────────────────────────────────────
// Match Submission Transaction
// ─────────────────────────────────────────────────────────────────────────────

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
    pub form_rating: f64,
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
            id, player_id, opponent_id, match_type, goals_for, goals_against,
            possession, passes_completed, passes_attempted, shots_on_target, shots_total,
            interceptions, screenshot_hash, verification_status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        "#,
    )
    .bind(match_id)
    .bind(input.player_id)
    .bind(input.opponent_id)
    .bind(&input.match_type)
    .bind(input.goals_for as i32)
    .bind(input.goals_against as i32)
    .bind(input.possession)
    .bind(input.passes_completed as i32)
    .bind(input.passes_attempted as i32)
    .bind(input.shots_on_target as i32)
    .bind(input.shots_total as i32)
    .bind(input.interceptions as i32)
    .bind(&input.screenshot_hash)
    .bind("approved")
    .execute(&mut *tx)
    .await?;

    // 2. Upsert player profile rating + form rating + play style
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
            form_rating  = $3,
            play_style   = $4,
            updated_at   = NOW()
        "#,
    )
    .bind(input.player_id)
    .bind(input.elo_result.new_rating)
    .bind(input.form_rating)
    .bind(play_style.as_str())
    .execute(&mut *tx)
    .await?;

    // 3. Log Elo History audit entry
    sqlx::query(
        r#"
        INSERT INTO Elo_History (player_id, match_record_id, rating_before, rating_after)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(input.player_id)
    .bind(match_id)
    .bind(input.elo_result.new_rating - input.elo_result.rating_delta)
    .bind(input.elo_result.new_rating)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(match_id)
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Analytics & MPS History
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the last N MPS values for a player (oldest first), used for EWMA form calculation.
pub async fn get_player_mps_history(
    pool: &PgPool,
    player_id: Uuid,
    n: i64,
) -> Result<Vec<f64>, sqlx::Error> {
    let rows: Vec<(f64,)> = sqlx::query_as(
        r#"
        SELECT possession * 0.20
             + (CASE WHEN passes_attempted > 0 THEN passes_completed::float / passes_attempted * 100 ELSE 0 END) * 0.30
             + (CASE WHEN shots_on_target  > 0 THEN goals_for::float      / shots_on_target         * 100 ELSE 0 END) * 0.30
             + LEAST(100, interceptions * 10)::float * 0.20
          AS mps
        FROM Match_Records
        WHERE player_id = $1
        ORDER BY created_at DESC
        LIMIT $2
        "#,
    )
    .bind(player_id)
    .bind(n)
    .fetch_all(pool)
    .await?;

    // Reverse so oldest is first for EWMA computation
    let mut values: Vec<f64> = rows.into_iter().map(|(v,)| v).collect();
    values.reverse();
    Ok(values)
}

/// Player profile row returned for analytics endpoint.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct PlayerAnalyticsRow {
    pub user_id: Uuid,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
    pub matches_played: i64,
    pub wins: i64,
    pub draws: i64,
    pub losses: i64,
}

/// Retrieves aggregated player analytics from the database.
pub async fn get_player_analytics(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<PlayerAnalyticsRow, sqlx::Error> {
    let row = sqlx::query_as::<_, PlayerAnalyticsRow>(
        r#"
        SELECT
            p.user_id,
            p.skill_rating,
            COALESCE(p.form_rating, 50.0)::FLOAT8 AS form_rating,
            p.play_style,
            COUNT(m.id)                                               AS matches_played,
            COUNT(*) FILTER (WHERE m.goals_for > m.goals_against)    AS wins,
            COUNT(*) FILTER (WHERE m.goals_for = m.goals_against)    AS draws,
            COUNT(*) FILTER (WHERE m.goals_for < m.goals_against)    AS losses
        FROM Player_Profiles p
        LEFT JOIN Match_Records m ON m.player_id = p.user_id
        WHERE p.user_id = $1
        GROUP BY p.user_id, p.skill_rating, p.form_rating, p.play_style
        "#,
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await?;

    Ok(row.unwrap_or(PlayerAnalyticsRow {
        user_id: player_id,
        skill_rating: 1000,
        form_rating: 50.0,
        play_style: Some("Unclassified".into()),
        matches_played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
    }))
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Leaderboard
// ─────────────────────────────────────────────────────────────────────────────

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
pub async fn get_club_leaderboard_db(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<LeaderboardRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, LeaderboardRow>(
        r#"
        SELECT u.id as user_id, u.username, p.skill_rating, 
               COALESCE(p.form_rating, 50.0)::FLOAT8 as form_rating, p.play_style
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

// ─────────────────────────────────────────────────────────────────────────────
// Head-to-Head Queries
// ─────────────────────────────────────────────────────────────────────────────

/// Head-to-Head database query result row.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct H2hDbResult {
    pub total_matches: i64,
    pub p1_wins: i64,
    pub draws: i64,
    pub p2_wins: i64,
    pub avg_goal_diff: f64,
}

/// Queries historical Head-to-Head match records between two players.
pub async fn get_h2h_record_db(
    pool: &PgPool,
    p1_id: Uuid,
    p2_id: Uuid,
) -> Result<H2hDbResult, sqlx::Error> {
    let row = sqlx::query_as::<_, H2hDbResult>(
        r#"
        SELECT
            COUNT(*) as total_matches,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for > goals_against)
                               OR  (opponent_id = $1 AND goals_against > goals_for)) as p1_wins,
            COUNT(*) FILTER (WHERE goals_for = goals_against) as draws,
            COUNT(*) FILTER (WHERE (player_id = $2 AND goals_for > goals_against)
                               OR  (opponent_id = $2 AND goals_against > goals_for)) as p2_wins,
            COALESCE(AVG(ABS(goals_for - goals_against)), 0.0)                       as avg_goal_diff
        FROM Match_Records
        WHERE (player_id = $1 AND opponent_id = $2)
           OR (player_id = $2 AND opponent_id = $1)
        "#,
    )
    .bind(p1_id)
    .bind(p2_id)
    .fetch_one(pool)
    .await?;

    Ok(row)
}

// ─────────────────────────────────────────────────────────────────────────────
// Clubs Management
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a new club and adds the owner as an admin member. Returns the new club UUID.
pub async fn create_club(
    pool: &PgPool,
    name: &str,
    invite_code: &str,
    owner_id: Uuid,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    // Auto-provision user & profile if not existing (prevents foreign key violation)
    sqlx::query(
        r#"
        INSERT INTO Users (id, username, password_hash)
        VALUES ($1, 'user_' || SUBSTRING($1::text, 1, 8), 'placeholder_hash')
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(owner_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id)
        VALUES ($1)
        ON CONFLICT (user_id) DO NOTHING
        "#,
    )
    .bind(owner_id)
    .execute(&mut *tx)
    .await?;

    let club_id = Uuid::new_v4();
    sqlx::query(
        r#"INSERT INTO Clubs (id, name, invite_code, owner_id) VALUES ($1, $2, $3, $4)"#,
    )
    .bind(club_id)
    .bind(name)
    .bind(invite_code)
    .bind(owner_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"INSERT INTO Club_Memberships (player_id, club_id, role) VALUES ($1, $2, 'admin')"#,
    )
    .bind(owner_id)
    .bind(club_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(club_id)
}

/// Joins a player to a club after validating the invite code. Returns an error if code mismatches.
pub async fn join_club_by_invite(
    pool: &PgPool,
    player_id: Uuid,
    invite_code: &str,
) -> Result<Uuid, sqlx::Error> {
    let row: (Uuid,) = sqlx::query_as(
        r#"SELECT id FROM Clubs WHERE invite_code = $1 AND deleted_at IS NULL"#,
    )
    .bind(invite_code)
    .fetch_one(pool)
    .await?;

    let club_id = row.0;

    sqlx::query(
        r#"
        INSERT INTO Club_Memberships (player_id, club_id, role)
        VALUES ($1, $2, 'player')
        ON CONFLICT (player_id, club_id) DO NOTHING
        "#,
    )
    .bind(player_id)
    .bind(club_id)
    .execute(pool)
    .await?;

    Ok(club_id)
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Confirmation
// ─────────────────────────────────────────────────────────────────────────────

/// Confirms a pending match record as the opponent. Flips verification_status → approved.
pub async fn confirm_match(
    pool: &PgPool,
    match_id: Uuid,
    opponent_id: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        UPDATE Match_Records
        SET verification_status = 'approved', updated_at = NOW()
        WHERE id = $1 AND opponent_id = $2 AND verification_status = 'pending'
        "#,
    )
    .bind(match_id)
    .bind(opponent_id)
    .execute(pool)
    .await?;

    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// Dispute Persistence
// ─────────────────────────────────────────────────────────────────────────────

/// Persists a new match dispute into the `Match_Disputes` table. Returns the dispute UUID.
pub async fn save_dispute(
    pool: &PgPool,
    match_record_id: Uuid,
    raised_by: Uuid,
    reason: &str,
) -> Result<Uuid, sqlx::Error> {
    let dispute_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO Match_Disputes (id, match_record_id, raised_by, reason, status)
        VALUES ($1, $2, $3, $4, 'open')
        "#,
    )
    .bind(dispute_id)
    .bind(match_record_id)
    .bind(raised_by)
    .bind(reason)
    .execute(pool)
    .await?;

    Ok(dispute_id)
}

// ─────────────────────────────────────────────────────────────────────────────
// Tournament Bracket
// ─────────────────────────────────────────────────────────────────────────────

/// A single T_Match row fetched from the database.
#[derive(FromRow)]
pub struct TMatchRow {
    pub id: Uuid,
    pub player_1_id: Option<Uuid>,
    pub player_2_id: Option<Uuid>,
    pub round_number: i32,
    pub status: String,
}

/// Fetches all T_Matches for a tournament, ordered by round number.
pub async fn get_tournament_bracket(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Vec<TMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TMatchRow>(
        r#"
        SELECT id, player_1_id, player_2_id, round_number, status
        FROM T_Matches
        WHERE tournament_id = $1
        ORDER BY round_number ASC, created_at ASC
        "#,
    )
    .bind(tournament_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

// ─────────────────────────────────────────────────────────────────────────────
// Squad Verification
// ─────────────────────────────────────────────────────────────────────────────

/// Inserts a squad verification record for a pre-match screenshot. Returns the record UUID.
pub async fn insert_squad_verification(
    pool: &PgPool,
    t_match_id: Uuid,
    player_id: Uuid,
    team_strength: i32,
    screenshot_url: &str,
    is_valid: bool,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO Squad_Verifications (id, t_match_id, player_id, team_strength, screenshot_url, is_valid)
        VALUES ($1, $2, $3, $4, $5, $6)
        "#,
    )
    .bind(id)
    .bind(t_match_id)
    .bind(player_id)
    .bind(team_strength)
    .bind(screenshot_url)
    .bind(is_valid)
    .execute(pool)
    .await?;

    Ok(id)
}

// ─────────────────────────────────────────────────────────────────────────────
// User Registration
// ─────────────────────────────────────────────────────────────────────────────

/// Inserts a new user + initial player profile in a single transaction. Returns the new user UUID.
pub async fn create_user(
    pool: &PgPool,
    user_id: Uuid,
    username: &str,
    password_hash: &str,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query(r#"INSERT INTO Users (id, username, password_hash) VALUES ($1, $2, $3)"#)
        .bind(user_id)
        .bind(username)
        .bind(password_hash)
        .execute(&mut *tx)
        .await?;

    sqlx::query(r#"INSERT INTO Player_Profiles (user_id) VALUES ($1)"#)
        .bind(user_id)
        .execute(&mut *tx)
        .await?;

    tx.commit().await?;
    Ok(user_id)
}

#[derive(FromRow)]
pub struct UserRecord {
    pub id: Uuid,
    pub username: String,
    pub password_hash: String,
}

/// Fetches a user by username
pub async fn get_user_by_username(
    pool: &sqlx::PgPool,
    username: &str,
) -> Result<Option<UserRecord>, sqlx::Error> {
    let user = sqlx::query_as::<_, UserRecord>(
        r#"SELECT id, username, password_hash FROM Users WHERE username = $1"#,
    )
    .bind(username)
    .fetch_optional(pool)
    .await?;

    Ok(user)
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Details & Members
// ─────────────────────────────────────────────────────────────────────────────

/// Club detail row from DB.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct ClubDetailRow {
    pub id: Uuid,
    pub name: String,
    pub invite_code: String,
    pub owner_id: Option<Uuid>,
    pub member_count: i64,
}

/// Fetches summary info for clubs a player belongs to.
pub async fn get_player_clubs(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Vec<ClubDetailRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubDetailRow>(
        r#"
        SELECT c.id, c.name, c.invite_code, c.owner_id,
               (SELECT COUNT(*) FROM Club_Memberships cm2 WHERE cm2.club_id = c.id) AS member_count
        FROM Clubs c
        JOIN Club_Memberships cm ON cm.club_id = c.id
        WHERE cm.player_id = $1 AND c.deleted_at IS NULL
        ORDER BY cm.joined_at DESC
        "#,
    )
    .bind(player_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Club member row including profile ratings.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct ClubMemberRow {
    pub user_id: Uuid,
    pub username: String,
    pub role: String,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
    pub matches_played: i64,
}

/// Fetches all members of a club with their profile data.
pub async fn get_club_members(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<ClubMemberRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubMemberRow>(
        r#"
        SELECT u.id AS user_id, u.username, cm.role,
               COALESCE(p.skill_rating, 1000) AS skill_rating,
               COALESCE(p.form_rating, 50.0)::FLOAT8 AS form_rating,
               p.play_style,
               (SELECT COUNT(*) FROM Match_Records mr WHERE mr.player_id = u.id) AS matches_played
        FROM Club_Memberships cm
        JOIN Users u ON cm.player_id = u.id
        LEFT JOIN Player_Profiles p ON u.id = p.user_id
        WHERE cm.club_id = $1
        ORDER BY COALESCE(p.skill_rating, 1000) DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Updates a club member's role (admin/organizer/player).
pub async fn update_member_role(
    pool: &PgPool,
    club_id: Uuid,
    player_id: Uuid,
    new_role: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"UPDATE Club_Memberships SET role = $1 WHERE club_id = $2 AND player_id = $3"#,
    )
    .bind(new_role)
    .bind(club_id)
    .bind(player_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Removes a member from a club.
pub async fn remove_club_member(
    pool: &PgPool,
    club_id: Uuid,
    player_id: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"DELETE FROM Club_Memberships WHERE club_id = $1 AND player_id = $2"#,
    )
    .bind(club_id)
    .bind(player_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Updates club name and/or invite code.
pub async fn update_club_details(
    pool: &PgPool,
    club_id: Uuid,
    name: &str,
    invite_code: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"UPDATE Clubs SET name = $1, invite_code = $2, updated_at = NOW() WHERE id = $3"#,
    )
    .bind(name)
    .bind(invite_code)
    .bind(club_id)
    .execute(pool)
    .await?;

    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Profile & Match History
// ─────────────────────────────────────────────────────────────────────────────

/// A single match history row.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct MatchHistoryRow {
    pub id: Uuid,
    pub opponent_id: Uuid,
    pub opponent_name: String,
    pub match_type: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub possession: f64,
    pub passes_completed: i32,
    pub passes_attempted: i32,
    pub shots_on_target: i32,
    pub shots_total: i32,
    pub interceptions: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches paginated match history for a player.
pub async fn get_player_match_history(
    pool: &PgPool,
    player_id: Uuid,
    limit: i64,
    offset: i64,
) -> Result<Vec<MatchHistoryRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, MatchHistoryRow>(
        r#"
        SELECT m.id, m.opponent_id,
               COALESCE(u.username, 'Unknown') AS opponent_name,
               m.match_type, m.goals_for, m.goals_against,
               m.possession::FLOAT8 AS possession,
               m.passes_completed, m.passes_attempted,
               m.shots_on_target, m.shots_total, m.interceptions,
               m.created_at
        FROM Match_Records m
        LEFT JOIN Users u ON m.opponent_id = u.id
        WHERE m.player_id = $1 AND m.deleted_at IS NULL
        ORDER BY m.created_at DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(player_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// An Elo history data point.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct EloHistoryRow {
    pub rating_before: i32,
    pub rating_after: i32,
    pub recorded_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches Elo rating progression for a player.
pub async fn get_elo_history(
    pool: &PgPool,
    player_id: Uuid,
    limit: i64,
) -> Result<Vec<EloHistoryRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, EloHistoryRow>(
        r#"
        SELECT rating_before, rating_after, recorded_at
        FROM Elo_History
        WHERE player_id = $1
        ORDER BY recorded_at ASC
        LIMIT $2
        "#,
    )
    .bind(player_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Badge row with earned_at timestamp.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct PlayerBadgeRow {
    pub badge_name: String,
    pub badge_description: Option<String>,
    pub icon_url: Option<String>,
    pub earned_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches badges earned by a player.
pub async fn get_player_badges(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Vec<PlayerBadgeRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, PlayerBadgeRow>(
        r#"
        SELECT b.name AS badge_name, b.description AS badge_description,
               b.icon_url, pb.earned_at
        FROM Player_Badges pb
        JOIN Badges b ON pb.badge_id = b.id
        WHERE pb.player_id = $1
        ORDER BY pb.earned_at DESC
        "#,
    )
    .bind(player_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

// ─────────────────────────────────────────────────────────────────────────────
// Tournament CRUD
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a tournament row in the database.
pub async fn create_tournament(
    pool: &PgPool,
    club_id: Uuid,
    name: &str,
    format_type: &str,
    rules_config: &serde_json::Value,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO Tournaments (id, club_id, name, format_type, status, rules_config)
        VALUES ($1, $2, $3, $4, 'draft', $5)
        "#,
    )
    .bind(id)
    .bind(club_id)
    .bind(name)
    .bind(format_type)
    .bind(rules_config)
    .execute(pool)
    .await?;

    Ok(id)
}

/// Tournament summary row.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct TournamentRow {
    pub id: Uuid,
    pub name: String,
    pub format_type: String,
    pub status: String,
    pub participant_count: i64,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches all tournaments for a club.
pub async fn get_club_tournaments(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<TournamentRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TournamentRow>(
        r#"
        SELECT t.id, t.name, t.format_type, t.status,
               (SELECT COUNT(*) FROM T_Matches tm WHERE tm.tournament_id = t.id) AS participant_count,
               t.created_at
        FROM Tournaments t
        WHERE t.club_id = $1 AND t.deleted_at IS NULL
        ORDER BY t.created_at DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Updates tournament status (draft → active → completed).
pub async fn update_tournament_status(
    pool: &PgPool,
    tournament_id: Uuid,
    status: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"UPDATE Tournaments SET status = $1, updated_at = NOW() WHERE id = $2"#,
    )
    .bind(status)
    .bind(tournament_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Inserts a T_Match fixture into the database.
pub async fn insert_tournament_match(
    pool: &PgPool,
    tournament_id: Uuid,
    player_1_id: Uuid,
    player_2_id: Option<Uuid>,
    round_number: i32,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, status)
        VALUES ($1, $2, $3, $4, $5, 'scheduled')
        "#,
    )
    .bind(id)
    .bind(tournament_id)
    .bind(player_1_id)
    .bind(player_2_id)
    .bind(round_number)
    .execute(pool)
    .await?;

    Ok(id)
}

// ─────────────────────────────────────────────────────────────────────────────
// League Standings
// ─────────────────────────────────────────────────────────────────────────────

/// League standing row with player name.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct LeagueStandingRow {
    pub player_id: Uuid,
    pub player_name: String,
    pub played: i32,
    pub won: i32,
    pub drawn: i32,
    pub lost: i32,
    pub goals_for: i32,
    pub goals_against: i32,
    pub goal_diff: i32,
    pub points: i32,
}

/// Fetches league standings for a tournament, sorted by points then GD.
pub async fn get_league_standings(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Vec<LeagueStandingRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, LeagueStandingRow>(
        r#"
        SELECT ls.player_id,
               COALESCE(u.username, 'Unknown') AS player_name,
               ls.played, ls.won, ls.drawn, ls.lost,
               ls.goals_for, ls.goals_against, ls.goal_diff, ls.points
        FROM League_Standings ls
        LEFT JOIN Users u ON ls.player_id = u.id
        WHERE ls.tournament_id = $1
        ORDER BY ls.points DESC, ls.goal_diff DESC, ls.goals_for DESC
        "#,
    )
    .bind(tournament_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Initializes league standings rows for all participants when a tournament starts.
pub async fn initialize_league_standings(
    pool: &PgPool,
    tournament_id: Uuid,
    player_ids: &[Uuid],
) -> Result<(), sqlx::Error> {
    for pid in player_ids {
        sqlx::query(
            r#"
            INSERT INTO League_Standings (tournament_id, player_id)
            VALUES ($1, $2)
            ON CONFLICT (tournament_id, player_id) DO NOTHING
            "#,
        )
        .bind(tournament_id)
        .bind(pid)
        .execute(pool)
        .await?;
    }

    Ok(())
}

/// Updates league standings after a match result.
pub async fn update_league_standing(
    pool: &PgPool,
    tournament_id: Uuid,
    player_id: Uuid,
    goals_for: i32,
    goals_against: i32,
) -> Result<(), sqlx::Error> {
    let (won, drawn, lost, points) = if goals_for > goals_against {
        (1, 0, 0, 3)
    } else if goals_for == goals_against {
        (0, 1, 0, 1)
    } else {
        (0, 0, 1, 0)
    };

    sqlx::query(
        r#"
        UPDATE League_Standings
        SET played = played + 1,
            won = won + $1,
            drawn = drawn + $2,
            lost = lost + $3,
            goals_for = goals_for + $4,
            goals_against = goals_against + $5,
            goal_diff = goal_diff + ($4 - $5),
            points = points + $6,
            updated_at = NOW()
        WHERE tournament_id = $7 AND player_id = $8
        "#,
    )
    .bind(won)
    .bind(drawn)
    .bind(lost)
    .bind(goals_for)
    .bind(goals_against)
    .bind(points)
    .bind(tournament_id)
    .bind(player_id)
    .execute(pool)
    .await?;

    Ok(())
}
