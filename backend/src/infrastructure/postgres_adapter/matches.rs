//! # PostgreSQL Infrastructure Adapter Module
//!
//! Provides transaction-safe database interactions with PostgreSQL using SQLx,
//! including match record insertion, player profile Elo rating updates, Elo history logging,
//! real-time club rankings queries, Head-to-Head stats queries, clubs management,
//! dispute persistence, tournament bracket fetching, and player analytics.

use serde::Serialize;
use sqlx::{FromRow, PgPool, Postgres, Row, Transaction};
use uuid::Uuid;

use crate::domain::{
    elo::EloResult,
    mps::MpsResult,
    play_style::{classify_play_style, PlayerMatchStatsSummary},
};
use crate::infrastructure::postgres_adapter::clubs::apply_match_stats;

// ─────────────────────────────────────────────────────────────────────────────
// Match Submission Transaction
// ─────────────────────────────────────────────────────────────────────────────

/// Parameters required to execute a transaction-safe match record insertion and rating update.
pub struct SaveMatchTransactionInput {
    pub player_id: Uuid,
    pub opponent_id: Uuid,
    pub club_id: Uuid,
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
    // 2. Upsert player profile form rating + play style ONLY (Elo applied on confirmation)
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

    // Update Club_Memberships (form & play style only)
    sqlx::query(
        r#"
        INSERT INTO Club_Memberships (player_id, club_id, form_rating, play_style)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (player_id, club_id) DO UPDATE SET
            form_rating  = $3,
            play_style   = $4
        "#,
    )
    .bind(input.player_id)
    .bind(input.club_id)
    .bind(input.form_rating)
    .bind(play_style.as_str())
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
    club_id: Uuid,
    player_id: Uuid,
    opponent_id: Uuid,
    goals_for: u32,
    goals_against: u32,
) -> Result<Option<Uuid>, sqlx::Error> {
    let row: Option<(Uuid,)> = sqlx::query_as(
        r#"
        SELECT id FROM Match_Records
        WHERE club_id = $1 AND player_id = $2 AND opponent_id = $3
          AND goals_for = $4 AND goals_against = $5
          AND created_at >= NOW() - INTERVAL '2 hours'
          AND verification_status = 'pending'
        LIMIT 1
        "#,
    )
    .bind(club_id)
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
    apply_stats: bool,
) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE Match_Records SET verification_status = 'approved', verified_by_id = $2 WHERE id = $1")
        .bind(match_id)
        .bind(verifier_id)
        .execute(pool)
        .await?;

    if apply_stats {
        apply_match_stats(pool, match_id).await?;
    }

    Ok(())
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
              player_id != $2 -- Prevent self-confirm by official
              AND club_id IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM Club_Memberships cm
                WHERE cm.club_id = Match_Records.club_id
                  AND cm.player_id = $2
                  AND LOWER(cm.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
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

    apply_match_stats(pool, match_id).await?;

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
            COALESCE(NULLIF(u1.full_name, ''), u1.username, 'Player') AS player_name,
            m.opponent_id::TEXT AS opponent_id,
            COALESCE(NULLIF(u2.full_name, ''), u2.username, 'Opponent') AS opponent_name,
            m.match_type,
            m.goals_for::INT4 AS goals_for,
            m.goals_against::INT4 AS goals_against,
            m.possession::FLOAT AS possession,
            m.created_at::TEXT AS created_at,
            t.name AS tournament_name,
            tm.round_number::INT4 AS round_number,
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


