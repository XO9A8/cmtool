//! # PostgreSQL Infrastructure Adapter Module
//!
//! Provides transaction-safe database interactions with PostgreSQL using SQLx,
//! including match record insertion, player profile Elo rating updates, Elo history logging,
//! real-time club rankings queries, Head-to-Head stats queries, clubs management,
//! dispute persistence, tournament bracket fetching, and player analytics.

use serde::Serialize;
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
    /// Optional tournament fixture ID — links this match record to a T_Matches row.
    pub t_match_id: Option<Uuid>,
    pub match_type: String,
    pub goals_for: u32,
    pub goals_against: u32,
    pub possession: f64,
    pub passes_completed: u32,
    pub passes_attempted: u32,
    pub shots_on_target: u32,
    pub shots_total: u32,
    pub interceptions: u32,
    pub fouls: u32,
    pub offsides: u32,
    pub corners: u32,
    pub free_kicks: u32,
    pub crosses: u32,
    pub tackles: u32,
    pub saves: u32,
    pub screenshot_hash: String,
    pub elo_result: EloResult,
    pub mps_result: Option<MpsResult>,
    pub form_rating: f64,
    pub verification_status: String,
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

    // 1. Insert match record (including t_match_id tournament fixture link)
    sqlx::query(
        r#"
        INSERT INTO Match_Records (
            id, club_id, player_id, opponent_id, t_match_id, match_type, result, goals_for, goals_against,
            possession, passes_completed, passes_attempted, shots_on_target, shots_total,
            interceptions, fouls, offsides, corners, free_kicks, crosses, tackles, saves, screenshot_hash, verification_status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24)
        "#,
    )
    .bind(match_id)
    .bind(input.club_id)
    .bind(input.player_id)
    .bind(input.opponent_id)
    .bind(input.t_match_id)
    .bind(&input.match_type)
    .bind(if input.goals_for > input.goals_against { "win" } else if input.goals_for == input.goals_against { "draw" } else { "loss" })
    .bind(input.goals_for as i32)
    .bind(input.goals_against as i32)
    .bind(input.possession)
    .bind(input.passes_completed as i32)
    .bind(input.passes_attempted as i32)
    .bind(input.shots_on_target as i32)
    .bind(input.shots_total as i32)
    .bind(input.interceptions as i32)
    .bind(input.fouls as i32)
    .bind(input.offsides as i32)
    .bind(input.corners as i32)
    .bind(input.free_kicks as i32)
    .bind(input.crosses as i32)
    .bind(input.tackles as i32)
    .bind(input.saves as i32)
    .bind(&input.screenshot_hash)
    .bind(&input.verification_status)
    .execute(&mut *tx)
    .await?;

    // 1b. If this is a tournament fixture, back-link T_Matches.match_record_id → this match
    if let Some(tm_id) = input.t_match_id {
        sqlx::query(
            r#"UPDATE T_Matches SET match_record_id = $1 WHERE id = $2"#,
        )
        .bind(match_id)
        .bind(tm_id)
        .execute(&mut *tx)
        .await?;
    }

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

    // If club_id is present, update Club_Memberships
    if let Some(c_id) = input.club_id {
        sqlx::query(
            r#"
            INSERT INTO Club_Memberships (player_id, club_id, skill_rating, form_rating, play_style)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (player_id, club_id) DO UPDATE SET
                skill_rating = $3,
                form_rating  = $4,
                play_style   = $5
            "#,
        )
        .bind(input.player_id)
        .bind(c_id)
        .bind(input.elo_result.new_rating)
        .bind(input.form_rating)
        .bind(play_style.as_str())
        .execute(&mut *tx)
        .await?;
    }

    // Update Player_Profiles lifetime stats
    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id, lifetime_matches, lifetime_wins)
        VALUES ($1, 1, $2)
        ON CONFLICT (user_id) DO UPDATE SET
            lifetime_matches = Player_Profiles.lifetime_matches + 1,
            lifetime_wins    = Player_Profiles.lifetime_wins + $2,
            updated_at       = NOW()
        "#,
    )
    .bind(input.player_id)
    .bind(if input.goals_for > input.goals_against { 1 } else { 0 })
    .execute(&mut *tx)
    .await?;

    // 3. Log Elo History audit entry
    sqlx::query(
        r#"
        INSERT INTO Elo_History (club_id, player_id, match_record_id, rating_before, rating_after)
        VALUES ($1, $2, $3, $4, $5)
        "#,
    )
    .bind(input.club_id)
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
// Match Deduplication & Confirmation Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Checks if a match with the given screenshot hash already exists
pub async fn check_screenshot_exists(
    pool: &PgPool,
    hash: &str,
) -> Result<bool, sqlx::Error> {
    let exists: Option<(bool,)> = sqlx::query_as(
        r#"
        SELECT EXISTS(SELECT 1 FROM Match_Records WHERE screenshot_hash = $1)
        "#,
    )
    .bind(hash)
    .fetch_optional(pool)
    .await?;

    Ok(exists.map(|e| e.0).unwrap_or(false))
}

/// Finds a pending match submitted by the opponent within the last 2 hours
/// with perfectly symmetric goals
pub async fn find_pending_opponent_match(
    pool: &PgPool,
    player_id: Uuid,
    opponent_id: Uuid,
    goals_for: u32,
    goals_against: u32,
) -> Result<Option<Uuid>, sqlx::Error> {
    let row: Option<(Uuid,)> = sqlx::query_as(
        r#"
        SELECT id FROM Match_Records
        WHERE player_id = $1 AND opponent_id = $2
          AND goals_for = $3 AND goals_against = $4
          AND created_at >= NOW() - INTERVAL '2 hours'
        LIMIT 1
        "#,
    )
    .bind(opponent_id) // The opponent submitted it
    .bind(player_id) // Against the current player
    .bind(goals_against as i32) // Opponent's goals_for must equal my goals_against
    .bind(goals_for as i32) // Opponent's goals_against must equal my goals_for
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|r| r.0))
}

/// Marks a match as approved
pub async fn approve_match(
    pool: &PgPool,
    match_id: Uuid,
    verifier_id: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE Match_Records SET verification_status = 'approved', verified_by_id = $2 WHERE id = $1")
        .bind(match_id)
        .bind(verifier_id)
        .execute(pool)
        .await?;
    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Analytics & MPS History
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the last N MPS values for a player (oldest first), used for EWMA form calculation.
/// Fetches the current form rating for a player (either from Club_Memberships or default).
pub async fn get_player_current_form(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<f64, sqlx::Error> {
    let row: Option<(f64,)> = sqlx::query_as(
        r#"
        SELECT form_rating::float8
        FROM Club_Memberships
        WHERE player_id = $1
        LIMIT 1
        "#,
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|r| r.0).unwrap_or(50.0))
}

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
    pub username: Option<String>,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
    pub matches_played: i64,
    pub wins: i64,
    pub draws: i64,
    pub losses: i64,
    pub efootball_game_id: Option<String>,
    pub preferred_foot: Option<String>,
    pub jersey_number: Option<i32>,
    pub system_device: Option<String>,
    pub facebook: Option<String>,
    pub blood_group: Option<String>,
    pub district: Option<String>,
    pub date_of_birth: Option<chrono::NaiveDate>,
    pub registrar_joined: Option<chrono::NaiveDate>,
    pub contract_start: Option<chrono::NaiveDate>,
    pub contract_end: Option<chrono::NaiveDate>,
    pub facebook_link: Option<String>,
    pub email_node: Option<String>,
    pub phone_line: Option<String>,
    pub node_state: Option<String>,
    pub auth_status: Option<String>,
    pub source_feed: Option<String>,
}

/// Retrieves aggregated player analytics from the database.
/// Uses DISTINCT ON to pick only the most recently-joined club membership,
/// preventing duplicate rows for players who belong to multiple clubs.
pub async fn get_player_analytics(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<PlayerAnalyticsRow, sqlx::Error> {
    let row = sqlx::query_as::<_, PlayerAnalyticsRow>(
        r#"
        SELECT
            p.user_id,
            u.username,
            COALESCE(cm.skill_rating, 1000)                          AS skill_rating,
            COALESCE(cm.form_rating, 50.0)::FLOAT8                   AS form_rating,
            cm.play_style,
            COUNT(m.id)                                              AS matches_played,
            COUNT(*) FILTER (WHERE m.goals_for > m.goals_against)    AS wins,
            COUNT(*) FILTER (WHERE m.goals_for = m.goals_against)    AS draws,
            COUNT(*) FILTER (WHERE m.goals_for < m.goals_against)    AS losses,
            p.efootball_game_id,
            p.preferred_foot,
            p.jersey_number,
            p.system_device,
            p.facebook,
            p.blood_group,
            p.district,
            p.date_of_birth,
            p.registrar_joined,
            p.contract_start,
            p.contract_end,
            p.facebook_link,
            p.email_node,
            p.phone_line,
            p.node_state,
            p.auth_status,
            p.source_feed
        FROM Player_Profiles p
        LEFT JOIN Users u ON u.id = p.user_id
        -- DISTINCT ON ensures only one membership row per player (most recently joined club)
        LEFT JOIN (
            SELECT DISTINCT ON (player_id)
                player_id, club_id, skill_rating, form_rating, play_style
            FROM Club_Memberships
            ORDER BY player_id, joined_at DESC NULLS LAST
        ) cm ON cm.player_id = p.user_id
        LEFT JOIN Match_Records m ON m.player_id = p.user_id
        WHERE p.user_id = $1
        GROUP BY p.user_id, u.username, cm.skill_rating, cm.form_rating, cm.play_style,
                 p.efootball_game_id, p.preferred_foot, p.jersey_number, p.system_device,
                 p.facebook, p.blood_group, p.district, p.date_of_birth, p.registrar_joined,
                 p.contract_start, p.contract_end, p.facebook_link, p.email_node,
                 p.phone_line, p.node_state, p.auth_status, p.source_feed
        LIMIT 1
        "#,
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await?;

    Ok(row.unwrap_or(PlayerAnalyticsRow {
        user_id: player_id,
        username: None,
        skill_rating: 1000,
        form_rating: 50.0,
        play_style: Some("Unclassified".into()),
        matches_played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        efootball_game_id: None,
        preferred_foot: None,
        jersey_number: None,
        system_device: None,
        facebook: None,
        blood_group: None,
        district: None,
        date_of_birth: None,
        registrar_joined: None,
        contract_start: None,
        contract_end: None,
        facebook_link: None,
        email_node: None,
        phone_line: None,
        node_state: None,
        auth_status: None,
        source_feed: None,
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
        SELECT u.id as user_id, u.username, COALESCE(cm.skill_rating, 1000) as skill_rating, 
               COALESCE(cm.form_rating, 50.0)::FLOAT8 as form_rating, cm.play_style
        FROM Club_Memberships cm
        JOIN Users u ON cm.player_id = u.id
        WHERE cm.club_id = $1
        ORDER BY COALESCE(cm.skill_rating, 1000) DESC
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

/// Confirms a pending match record as the opponent or a club official. Flips verification_status → approved.
/// Returns an error if no rows were updated (match not found, wrong user, already confirmed).
pub async fn confirm_match(
    pool: &PgPool,
    match_id: Uuid,
    user_id: Uuid,
) -> Result<(), sqlx::Error> {
    let result = sqlx::query(
        r#"
        UPDATE Match_Records
        SET verification_status = 'approved', updated_at = NOW(), verified_by_id = $2
        WHERE id = $1 AND verification_status = 'pending'
          AND (
            -- Direct opponent can always confirm
            (player_id != $2 AND opponent_id = $2)
            -- Club official: if club_id is set on the match, check that club
            OR (
              club_id IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM Club_Memberships cm
                WHERE cm.club_id = Match_Records.club_id
                  AND cm.player_id = $2
                  AND LOWER(cm.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
              )
            )
            -- Club official: if club_id is NULL, look up shared club with the submitter
            OR (
              club_id IS NULL
              AND EXISTS (
                SELECT 1 FROM Club_Memberships cm_official
                WHERE cm_official.player_id = $2
                  AND LOWER(cm_official.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
                  AND EXISTS (
                    SELECT 1 FROM Club_Memberships cm_player
                    WHERE cm_player.player_id = Match_Records.player_id
                      AND cm_player.club_id = cm_official.club_id
                  )
              )
            )
          )
        "#,
    )
    .bind(match_id)
    .bind(user_id)
    .execute(pool)
    .await?;

    if result.rows_affected() == 0 {
        return Err(sqlx::Error::RowNotFound);
    }

    Ok(())
}

/// Fetches all pending matches requiring approval by the user (as opponent) or as a club official.
pub async fn get_pending_matches_db(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Vec<serde_json::Value>, sqlx::Error> {
    use sqlx::Row;

    let rows = sqlx::query(
        r#"
        SELECT
            m.id::TEXT AS id,
            m.player_id::TEXT AS player_id,
            COALESCE(u1.username, 'Player') AS player_name,
            m.opponent_id::TEXT AS opponent_id,
            COALESCE(u2.username, 'Opponent') AS opponent_name,
            m.match_type,
            m.goals_for,
            m.goals_against,
            m.possession::FLOAT AS possession,
            m.created_at::TEXT AS created_at,
            t.name AS tournament_name,
            tm.round_number,
            tm.group_name
        FROM Match_Records m
        LEFT JOIN Users u1 ON m.player_id = u1.id
        LEFT JOIN Users u2 ON m.opponent_id = u2.id
        LEFT JOIN T_Matches tm ON m.t_match_id = tm.id
        LEFT JOIN Tournaments t ON tm.tournament_id = t.id
        WHERE m.verification_status = 'pending'
          AND m.deleted_at IS NULL
          AND (
            -- Direct opponent can always confirm
            (m.player_id != $1 AND m.opponent_id = $1)
            -- Club official: if club_id is stored on the match, check that club
            OR (
              m.club_id IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM Club_Memberships cm
                WHERE cm.club_id = m.club_id
                  AND cm.player_id = $1
                  AND LOWER(cm.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
              )
            )
            -- Club official: if club_id is NULL, look up the submitter's club membership
            OR (
              m.club_id IS NULL
              AND EXISTS (
                SELECT 1 FROM Club_Memberships cm_official
                WHERE cm_official.player_id = $1
                  AND LOWER(cm_official.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
                  AND EXISTS (
                    SELECT 1 FROM Club_Memberships cm_player
                    WHERE cm_player.player_id = m.player_id
                      AND cm_player.club_id = cm_official.club_id
                  )
              )
            )
          )
        ORDER BY m.created_at DESC
        LIMIT 50
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    let matches = rows
        .into_iter()
        .map(|r| {
            let id: Option<String> = r.try_get("id").ok();
            let player_id: Option<String> = r.try_get("player_id").ok();
            let player_name: Option<String> = r.try_get("player_name").ok();
            let opponent_id: Option<String> = r.try_get("opponent_id").ok();
            let opponent_name: Option<String> = r.try_get("opponent_name").ok();
            let match_type: Option<String> = r.try_get("match_type").ok();
            let goals_for: Option<i32> = r.try_get("goals_for").ok();
            let goals_against: Option<i32> = r.try_get("goals_against").ok();
            let possession: Option<f64> = r.try_get("possession").ok();
            let created_at: Option<String> = r.try_get("created_at").ok();
            let tournament_name: Option<String> = r.try_get("tournament_name").ok();
            let round_number: Option<i32> = r.try_get("round_number").ok();
            let group_name: Option<String> = r.try_get("group_name").ok();

            serde_json::json!({
                "id": id,
                "player_id": player_id,
                "player_name": player_name,
                "opponent_id": opponent_id,
                "opponent_name": opponent_name,
                "match_type": match_type,
                "goals_for": goals_for,
                "goals_against": goals_against,
                "possession": possession,
                "created_at": created_at,
                "tournament_name": tournament_name,
                "round_number": round_number,
                "group_name": group_name,
            })
        })
        .collect();

    Ok(matches)
}


// ─────────────────────────────────────────────────────────────────────────────
// Dispute Persistence
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all open disputes from `Match_Disputes`, enriched with raiser username.
pub async fn get_admin_disputes_db(
    pool: &PgPool,
) -> Result<Vec<serde_json::Value>, sqlx::Error> {
    use sqlx::Row;

    let rows = sqlx::query(
        r#"
        SELECT
            md.id::TEXT AS id,
            md.match_record_id::TEXT AS match_record_id,
            md.raised_by::TEXT AS raised_by,
            COALESCE(u.username, 'Unknown') AS raised_by_username,
            md.reason,
            md.status,
            md.created_at::TEXT AS created_at
        FROM Match_Disputes md
        LEFT JOIN Users u ON u.id = md.raised_by
        WHERE md.status = 'open'
        ORDER BY md.created_at DESC
        LIMIT 50
        "#,
    )
    .fetch_all(pool)
    .await?;

    let disputes = rows
        .into_iter()
        .map(|r| {
            let id: Option<String> = r.try_get("id").ok();
            let match_record_id: Option<String> = r.try_get("match_record_id").ok();
            let raised_by: Option<String> = r.try_get("raised_by").ok();
            let raised_by_username: Option<String> = r.try_get("raised_by_username").ok();
            let reason: Option<String> = r.try_get("reason").ok();
            let status: Option<String> = r.try_get("status").ok();
            let created_at: Option<String> = r.try_get("created_at").ok();

            serde_json::json!({
                "id": id,
                "match_record_id": match_record_id,
                "raised_by": raised_by,
                "raised_by_username": raised_by_username,
                "reason": reason,
                "status": status,
                "created_at": created_at,
            })
        })
        .collect();

    Ok(disputes)
}

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
#[derive(FromRow, Serialize)]
pub struct TMatchRow {
    pub id: Uuid,
    pub player_1_id: Option<Uuid>,
    pub player_1_name: Option<String>,
    pub player_2_id: Option<Uuid>,
    pub player_2_name: Option<String>,
    pub round_number: i32,
    pub status: String,
    /// The winning player's UUID (NULL when match is not yet completed).
    pub winner_player_id: Option<Uuid>,
    pub player_1_score: Option<i32>,
    pub player_2_score: Option<i32>,
    pub group_name: Option<String>,
    pub player_1_rating: Option<i32>,
    pub player_2_rating: Option<i32>,
}

/// Fetches all T_Matches for a tournament, ordered by round number.
pub async fn get_tournament_bracket(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Vec<TMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TMatchRow>(
        r#"
        SELECT
            m.id,
            m.player_1_id,
            u1.username AS player_1_name,
            m.player_2_id,
            u2.username AS player_2_name,
            m.round_number,
            m.status,
            CASE
                WHEN COALESCE(m.player_1_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_against ELSE NULL END) >
                     COALESCE(m.player_2_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_against ELSE NULL END)
                     THEN m.player_1_id
                WHEN COALESCE(m.player_2_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_against ELSE NULL END) >
                     COALESCE(m.player_1_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_against ELSE NULL END)
                     THEN m.player_2_id
                WHEN mr.result = 'win'  THEN mr.player_id
                WHEN mr.result = 'loss' THEN mr.opponent_id
                ELSE NULL
            END AS winner_player_id,
            COALESCE(m.player_1_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_against ELSE NULL END) AS player_1_score,
            COALESCE(m.player_2_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_against ELSE NULL END) AS player_2_score,
            COALESCE(m.group_name, ls1.group_name, ls2.group_name) AS group_name,
            cm1.skill_rating AS player_1_rating,
            cm2.skill_rating AS player_2_rating
        FROM T_Matches m
        LEFT JOIN Users u1 ON m.player_1_id = u1.id
        LEFT JOIN Users u2 ON m.player_2_id = u2.id
        LEFT JOIN Match_Records mr ON mr.id = m.match_record_id
        LEFT JOIN League_Standings ls1 ON ls1.tournament_id = m.tournament_id AND ls1.player_id = m.player_1_id
        LEFT JOIN League_Standings ls2 ON ls2.tournament_id = m.tournament_id AND ls2.player_id = m.player_2_id
        LEFT JOIN Tournaments t ON m.tournament_id = t.id
        LEFT JOIN Club_Memberships cm1 ON cm1.player_id = m.player_1_id AND cm1.club_id = t.club_id
        LEFT JOIN Club_Memberships cm2 ON cm2.player_id = m.player_2_id AND cm2.club_id = t.club_id
        WHERE m.tournament_id = $1
        ORDER BY m.round_number ASC, m.created_at ASC
        "#,
    )
    .bind(tournament_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}



// ─────────────────────────────────────────────────────────────────────────────
// User Registration
// ─────────────────────────────────────────────────────────────────────────────

/// Upserts a user and their player profile from Supabase.
pub async fn upsert_supabase_user(
    pool: &PgPool,
    user_id: Uuid,
    username: &str,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query(r#"
        INSERT INTO Users (id, username, password_hash)
        VALUES ($1, $2, 'supabase_managed')
        ON CONFLICT (id) DO NOTHING
    "#)
    .bind(user_id)
    .bind(username)
    .execute(&mut *tx)
    .await?;

    sqlx::query(r#"
        INSERT INTO Player_Profiles (user_id)
        VALUES ($1)
        ON CONFLICT (user_id) DO NOTHING
    "#)
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
               COALESCE(cm.skill_rating, 1000) AS skill_rating,
               COALESCE(cm.form_rating, 50.0)::FLOAT8 AS form_rating,
               cm.play_style,
               (SELECT COUNT(*) FROM Match_Records mr WHERE mr.player_id = u.id) AS matches_played
        FROM Club_Memberships cm
        JOIN Users u ON cm.player_id = u.id
        WHERE cm.club_id = $1
        ORDER BY COALESCE(cm.skill_rating, 1000) DESC
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
/// participant_count is the number of distinct registered players (from League_Standings),
/// not the raw match count (which was incorrect previously).
pub async fn get_club_tournaments(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<TournamentRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TournamentRow>(
        r#"
        SELECT t.id, t.name, t.format_type, t.status,
               COALESCE(
                   (SELECT COUNT(DISTINCT ls.player_id) FROM League_Standings ls WHERE ls.tournament_id = t.id),
                   (SELECT COUNT(DISTINCT tm_p.player_id)
                    FROM (
                        SELECT player_1_id AS player_id FROM T_Matches WHERE tournament_id = t.id
                        UNION
                        SELECT player_2_id AS player_id FROM T_Matches WHERE tournament_id = t.id
                    ) tm_p WHERE tm_p.player_id IS NOT NULL)
               ) AS participant_count,
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
/// match_number identifies the fixture's slot within its round for knockout advancement.
pub async fn insert_tournament_match(
    pool: &PgPool,
    tournament_id: Uuid,
    player_1_id: Uuid,
    player_2_id: Option<Uuid>,
    round_number: i32,
    match_number: i32,
    group_name: Option<&str>,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, match_number, status, group_name)
        VALUES ($1, $2, $3, $4, $5, $6, 'scheduled', $7)
        "#,
    )
    .bind(id)
    .bind(tournament_id)
    .bind(player_1_id)
    .bind(player_2_id)
    .bind(round_number)
    .bind(match_number)
    .bind(group_name)
    .execute(pool)
    .await?;

    Ok(id)
}

/// Batch inserts a list of FixtureNodes into T_Matches.
pub async fn save_tournament_fixtures(
    pool: &PgPool,
    tournament_id: Uuid,
    fixtures: Vec<crate::domain::tournament::FixtureNode>,
) -> Result<(), sqlx::Error> {
    for fixture in fixtures {
        insert_tournament_match(
            pool,
            tournament_id,
            fixture.player_1.map(|p| p.id).unwrap_or_default(),
            fixture.player_2.map(|p| p.id),
            fixture.round_number as i32,
            fixture.match_number as i32,
            None,
        ).await?;
    }
    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// League Standings
// ─────────────────────────────────────────────────────────────────────────────

/// League standing row with player name.
#[allow(dead_code)]
#[derive(FromRow, Serialize)]
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
    pub group_name: Option<String>,
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
               ls.goals_for, ls.goals_against, ls.goal_diff, ls.points,
               ls.group_name
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

/// Initializes league standings with explicit group assignments for group_knockout tournaments.
pub async fn initialize_league_standings_with_groups(
    pool: &PgPool,
    tournament_id: Uuid,
    player_groups: &[(Uuid, String)],
) -> Result<(), sqlx::Error> {
    for (pid, gname) in player_groups {
        sqlx::query(
            r#"
            INSERT INTO League_Standings (tournament_id, player_id, group_name)
            VALUES ($1, $2, $3)
            ON CONFLICT (tournament_id, player_id) DO UPDATE SET group_name = EXCLUDED.group_name
            "#,
        )
        .bind(tournament_id)
        .bind(pid)
        .bind(gname)
        .execute(pool)
        .await?;
    }

    Ok(())
}

/// Updates league standings after a match result.
/// Legacy version — use `update_league_standing_guarded` when calling from `process_tournament_advancement`.
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

/// Idempotent version of `update_league_standing`.
/// Updates a player's standing only if `last_processed_match_id` is NOT already the given t_match_id.
/// After updating, stamps `last_processed_match_id = t_match_id` to prevent double-counting
/// on any subsequent confirmation attempt for the same match.
pub async fn update_league_standing_guarded(
    pool: &PgPool,
    tournament_id: Uuid,
    t_match_id: Uuid,
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
        SET played        = played + 1,
            won           = won + $1,
            drawn         = drawn + $2,
            lost          = lost + $3,
            goals_for     = goals_for + $4,
            goals_against = goals_against + $5,
            goal_diff     = goal_diff + ($4 - $5),
            points        = points + $6,
            last_processed_match_id = $7,
            updated_at    = NOW()
        WHERE tournament_id = $8
          AND player_id     = $9
          AND (last_processed_match_id IS NULL OR last_processed_match_id != $7)
        "#,
    )
    .bind(won)
    .bind(drawn)
    .bind(lost)
    .bind(goals_for)
    .bind(goals_against)
    .bind(points)
    .bind(t_match_id)
    .bind(tournament_id)
    .bind(player_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Advances the winner of a knockout match to the correct slot in the next round.
///
/// Algorithm:
///   next_round  = current_round + 1
///   next_slot   = ceil(current_match_number / 2)  (integer: (match_number + 1) / 2)
///
/// If a T_Match row already exists for (tournament_id, next_round, next_slot) with one player slot empty,
/// fills that slot with `winner_id`.
/// If no row exists, creates a new T_Match with `player_1_id = winner_id` (player_2 arrives when sibling completes).
pub async fn advance_knockout_winner(
    pool: &PgPool,
    tournament_id: Uuid,
    _completed_match_id: Uuid,
    current_round: i32,
    current_match_number: i32,
    winner_id: Uuid,
) -> Result<(), sqlx::Error> {
    // 1. Calculate total rounds to prevent advancing past the final
    let r1_max: Option<i32> = sqlx::query_scalar(
        "SELECT MAX(match_number) FROM T_Matches WHERE tournament_id = $1 AND round_number = 1"
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    let r1_matches = r1_max.unwrap_or(1);
    
    let mut bracket_size = 1;
    let mut total_rounds = 0;
    while bracket_size < (r1_matches * 2) {
        bracket_size *= 2;
        total_rounds += 1;
    }

    if current_round >= total_rounds {
        // Tournament is complete! Mark it as completed.
        sqlx::query("UPDATE Tournaments SET status = 'completed', updated_at = NOW() WHERE id = $1")
            .bind(tournament_id)
            .execute(pool)
            .await?;
        return Ok(());
    }

    let next_round = current_round + 1;
    let next_slot  = (current_match_number + 1) / 2;

    // Check if a TBD row exists for this next slot
    let existing: Option<(Uuid, Option<Uuid>, Option<Uuid>)> = sqlx::query_as(
        r#"
        SELECT id, player_1_id, player_2_id
        FROM T_Matches
        WHERE tournament_id = $1 AND round_number = $2 AND match_number = $3
        LIMIT 1
        "#,
    )
    .bind(tournament_id)
    .bind(next_round)
    .bind(next_slot)
    .fetch_optional(pool)
    .await?;

    if let Some((row_id, p1, p2)) = existing {
        // Fill the empty slot
        if p1.is_none() {
            sqlx::query(
                "UPDATE T_Matches SET player_1_id = $1, updated_at = NOW() WHERE id = $2"
            )
            .bind(winner_id)
            .bind(row_id)
            .execute(pool)
            .await?;
        } else if p2.is_none() {
            sqlx::query(
                "UPDATE T_Matches SET player_2_id = $1, updated_at = NOW() WHERE id = $2"
            )
            .bind(winner_id)
            .bind(row_id)
            .execute(pool)
            .await?;
        }
        // Both slots filled means the match is ready to play (no action needed)
    } else {
        // No TBD row yet — create one with winner as player_1; sibling will fill player_2
        let new_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, match_number, status)
            VALUES ($1, $2, $3, NULL, $4, $5, 'scheduled')
            "#,
        )
        .bind(new_id)
        .bind(tournament_id)
        .bind(winner_id)
        .bind(next_round)
        .bind(next_slot)
        .execute(pool)
        .await?;
    }

    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Activity & Seasons
// ─────────────────────────────────────────────────────────────────────────────

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ClubActivityRow {
    pub id: Uuid,
    pub player_id: Uuid,
    pub player_name: String,
    pub opponent_id: Uuid,
    pub opponent_name: String,
    pub match_type: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn get_club_activity(
    pool: &sqlx::PgPool,
    club_id: Uuid,
    limit: i64,
) -> Result<Vec<ClubActivityRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubActivityRow>(
        r#"
        SELECT m.id,
               m.player_id,
               COALESCE(u1.username, 'Unknown') AS player_name,
               m.opponent_id,
               COALESCE(u2.username, 'Unknown') AS opponent_name,
               m.match_type, m.goals_for, m.goals_against,
               m.created_at
        FROM Match_Records m
        LEFT JOIN Users u1 ON m.player_id = u1.id
        LEFT JOIN Users u2 ON m.opponent_id = u2.id
        WHERE m.club_id = $1 AND m.deleted_at IS NULL
        ORDER BY m.created_at DESC
        LIMIT $2
        "#,
    )
    .bind(club_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ClubResolvedMatchRow {
    pub id: Uuid,
    pub player_id: Uuid,
    pub player_name: String,
    pub opponent_id: Uuid,
    pub opponent_name: String,
    pub match_type: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub verified_by_id: Option<Uuid>,
    pub verifier_username: Option<String>,
}

pub async fn get_club_resolved_matches(
    pool: &sqlx::PgPool,
    club_id: Uuid,
    limit: i64,
) -> Result<Vec<ClubResolvedMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubResolvedMatchRow>(
        r#"
        SELECT m.id,
               m.player_id,
               COALESCE(u1.username, 'Unknown') AS player_name,
               m.opponent_id,
               COALESCE(u2.username, 'Unknown') AS opponent_name,
               m.match_type, m.goals_for, m.goals_against,
               m.created_at,
               m.verified_by_id,
               uv.username AS verifier_username
        FROM Match_Records m
        LEFT JOIN Users u1 ON m.player_id = u1.id
        LEFT JOIN Users u2 ON m.opponent_id = u2.id
        LEFT JOIN Users uv ON m.verified_by_id = uv.id
        WHERE m.club_id = $1 AND m.deleted_at IS NULL AND m.verification_status = 'approved'
        ORDER BY m.updated_at DESC
        LIMIT $2
        "#,
    )
    .bind(club_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ClubSeasonRow {
    pub id: Uuid,
    pub name: String,
    pub start_date: chrono::NaiveDate,
    pub end_date: Option<chrono::NaiveDate>,
    pub is_active: bool,
}

pub async fn get_club_seasons(
    pool: &sqlx::PgPool,
    club_id: Uuid,
) -> Result<Vec<ClubSeasonRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubSeasonRow>(
        r#"
        SELECT id, name, start_date, end_date, is_active
        FROM Seasons
        WHERE club_id = $1
        ORDER BY start_date DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ScheduledMatchRow {
    pub id: Uuid,
    pub tournament_id: Uuid,
    pub tournament_name: String,
    pub player_1_id: Option<Uuid>,
    pub player_1_name: Option<String>,
    pub player_2_id: Option<Uuid>,
    pub player_2_name: Option<String>,
    pub round_number: i32,
    pub status: String,
}

pub async fn get_player_scheduled_matches(
    pool: &sqlx::PgPool,
    player_id: Uuid,
) -> Result<Vec<ScheduledMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ScheduledMatchRow>(
        r#"
        SELECT 
            m.id,
            m.tournament_id,
            t.name AS tournament_name,
            m.player_1_id,
            u1.username AS player_1_name,
            m.player_2_id,
            u2.username AS player_2_name,
            m.round_number,
            m.status
        FROM T_Matches m
        INNER JOIN Tournaments t ON m.tournament_id = t.id
        LEFT JOIN Users u1 ON m.player_1_id = u1.id
        LEFT JOIN Users u2 ON m.player_2_id = u2.id
        WHERE (m.player_1_id = $1 OR m.player_2_id = $1)
          AND m.status = 'scheduled'
        ORDER BY m.round_number ASC, m.created_at ASC
        "#,
    )
    .bind(player_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Checks if a user is a club official (admin, organizer, president, captain, vice-captain).
pub async fn is_club_official(
    pool: &PgPool,
    club_id: Uuid,
    user_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let row = sqlx::query!(
        r#"
        SELECT EXISTS (
            SELECT 1 FROM Club_Memberships
            WHERE club_id = $1 AND player_id = $2
              AND LOWER(role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
        ) AS is_official
        "#,
        club_id,
        user_id
    )
    .fetch_one(pool)
    .await?;

    Ok(row.is_official.unwrap_or(false))
}

/// Checks if all group stage matches (with a group_name) for a tournament are completed.
pub async fn check_group_stage_completed(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM T_Matches
        WHERE tournament_id = $1
          AND group_name IS NOT NULL
          AND status != 'completed'
        "#,
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    Ok(count == 0)
}

/// Checks if any knockout matches (no group_name) have already been generated for this tournament.
pub async fn check_knockout_stage_generated(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM T_Matches
            WHERE tournament_id = $1
              AND group_name IS NULL
        )
        "#,
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    Ok(exists)
}

/// Fetches advancing_per_group from tournament format_config / rules_config.
pub async fn get_tournament_advancing_count(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<usize, sqlx::Error> {
    let row = sqlx::query!(
        "SELECT rules_config FROM Tournaments WHERE id = $1",
        tournament_id
    )
    .fetch_optional(pool)
    .await?;

    if let Some(row) = row {
        if let Some(config) = row.rules_config {
            let advancing = config.get("advancing_per_group").and_then(|v| v.as_u64()).unwrap_or(2);
            return Ok(advancing as usize);
        }
    }
    Ok(2)
}
