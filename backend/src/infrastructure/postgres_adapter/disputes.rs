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

// ─────────────────────────────────────────────────────────────────────────────
// Dispute Persistence
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all open disputes from `Match_Disputes`, enriched with raiser username.
pub async fn get_admin_disputes_db(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Vec<serde_json::Value>, sqlx::Error> {
    use sqlx::Row;

    let rows = sqlx::query(
        r#"
        SELECT
            md.id::TEXT AS id,
            md.match_record_id::TEXT AS match_record_id,
            md.raised_by::TEXT AS raised_by,
            COALESCE(NULLIF(u.full_name, ''), u.username, 'Unknown') AS raised_by_username,
            md.reason,
            md.status,
            md.created_at::TEXT AS created_at
        FROM Match_Disputes md
        LEFT JOIN Users u ON u.id = md.raised_by
        LEFT JOIN Match_Records mr ON md.match_record_id = mr.id
        WHERE md.status = 'open'
          AND (
            mr.club_id IS NOT NULL
            AND EXISTS (
              SELECT 1 FROM Club_Memberships cm
              WHERE cm.club_id = mr.club_id
                AND cm.player_id = $1
                AND LOWER(cm.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
            )
            OR mr.club_id IS NULL
            AND EXISTS (
              SELECT 1 FROM Club_Memberships cm_official
              WHERE cm_official.player_id = $1
                AND LOWER(cm_official.role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
                AND EXISTS (
                  SELECT 1 FROM Club_Memberships cm_player
                  WHERE cm_player.player_id = mr.player_id
                    AND cm_player.club_id = cm_official.club_id
                )
            )
          )
        ORDER BY md.created_at DESC
        LIMIT 50
        "#,
    )
    .bind(user_id)
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

