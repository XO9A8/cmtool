use std::sync::Arc;

use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use sqlx::{FromRow, Row};
use uuid::Uuid;

use crate::{
    api::{
        auth_middleware::AuthenticatedUser,
        error::{bad_request, forbidden, internal_error, ApiErrorResponse},
    },
    domain::feature_flags::UpdateFlagsRequest,
    infrastructure::postgres_adapter as db,
    AppState,
};

#[derive(Deserialize)]
pub struct SnapshotSeasonRequest {
    pub season_id: Uuid,
}

pub async fn snapshot_season(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Json(payload): Json<SnapshotSeasonRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let mut tx = state.pool.begin().await.map_err(|e| internal_error(e))?;

    // Mark season as inactive
    let rows_affected = sqlx::query(
        "UPDATE Seasons SET is_active = false, end_date = CURRENT_DATE WHERE id = $1 AND is_active = true",
    )
    .bind(payload.season_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| internal_error(e))?
    .rows_affected();

    if rows_affected == 0 {
        return Err(bad_request("INVALID_SEASON", "Season not found or already inactive."));
    }

    tx.commit().await.map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "status": "success",
        "message": "Season ended and snapshot archived."
    })))
}

/// Allows admins to toggle runtime feature flags without redeployment.
pub async fn update_feature_flags(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<UpdateFlagsRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    // Only allow club owners to update feature flags for now
    let is_owner: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM Clubs WHERE owner_id = $1)",
    )
    .bind(auth.user_id)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(false);

    if !is_owner {
        return Err(forbidden("FORBIDDEN", "Only club owners can update feature flags."));
    }

    let mut flags = state.flags.write().await;
    flags.apply_update(payload);

    Ok(Json(serde_json::json!({
        "enable_ai_insights": flags.enable_ai_insights,
        "enable_live_standings": flags.enable_live_standings,
        "message": "Feature flags updated successfully"
    })))
}

pub async fn get_admin_disputes(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let disputes = db::get_admin_disputes_db(&state.pool, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "disputes": disputes
    })))
}

#[derive(Deserialize)]
pub struct ResolveDisputeRequest {
    pub dismiss: bool,
    pub resolution_notes: Option<String>,
    pub void_match: Option<bool>,
}

pub async fn resolve_admin_dispute(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(dispute_id): Path<Uuid>,
    Json(payload): Json<ResolveDisputeRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_official_result = sqlx::query(
        r#"
        SELECT EXISTS (
            SELECT 1 FROM Match_Disputes md
            LEFT JOIN Match_Records mr ON md.match_record_id = mr.id
            WHERE md.id = $1
              AND (
                (mr.club_id IS NOT NULL AND EXISTS (
                    SELECT 1 FROM Club_Memberships cm
                    WHERE cm.club_id = mr.club_id AND cm.player_id = $2
                      AND LOWER(cm.role) IN ('admin', 'organizer')
                ))
                OR (mr.club_id IS NULL AND EXISTS (
                    SELECT 1 FROM Club_Memberships cm_official
                    WHERE cm_official.player_id = $2
                      AND LOWER(cm_official.role) IN ('admin', 'organizer')
                      AND EXISTS (
                          SELECT 1 FROM Club_Memberships cm_player
                          WHERE cm_player.player_id = mr.player_id AND cm_player.club_id = cm_official.club_id
                      )
                ))
              )
        ) AS is_official
        "#
    )
    .bind(dispute_id)
    .bind(auth.user_id)
    .fetch_one(&state.pool)
    .await;

    let is_official = is_official_result.map(|r| r.get::<Option<bool>, _>("is_official").unwrap_or(false)).unwrap_or(false);

    if !is_official {
        return Err(forbidden("FORBIDDEN", "Only club officials can resolve disputes."));
    }

    #[derive(FromRow)]
    struct DisputeInfoRow {
        id: Uuid,
        match_record_id: Uuid,
        raised_by: Uuid,
        reason: String,
        status: String,
        counter_screenshot_url: Option<String>,
        resolved_by: Option<Uuid>,
        resolution_notes: Option<String>,
    }

    let dispute_row = sqlx::query_as::<_, DisputeInfoRow>(
        "SELECT id, match_record_id, raised_by, reason, status, counter_screenshot_url, resolved_by, resolution_notes FROM Match_Disputes WHERE id = $1",
    )
    .bind(dispute_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    let dispute_data = match dispute_row {
        Some(row) => row,
        None => return Err(bad_request("NOT_FOUND", "Dispute not found.")),
    };

    let domain_dispute = crate::domain::disputes::MatchDispute {
        id: dispute_data.id,
        match_record_id: dispute_data.match_record_id,
        raised_by: dispute_data.raised_by,
        reason: dispute_data.reason,
        status: match dispute_data.status.as_str() {
            "resolved" => crate::domain::disputes::DisputeStatus::Resolved,
            "dismissed" => crate::domain::disputes::DisputeStatus::Dismissed,
            _ => crate::domain::disputes::DisputeStatus::Open,
        },
        counter_screenshot_url: dispute_data.counter_screenshot_url,
        resolved_by: dispute_data.resolved_by,
        resolution_notes: dispute_data.resolution_notes,
    };

    let resolved_dispute = crate::domain::disputes::resolve_dispute(
        domain_dispute,
        payload.dismiss,
        auth.user_id,
        payload.resolution_notes.clone(),
    );

    let status = resolved_dispute.status.as_str();

    // First, resolve the dispute ticket
    sqlx::query(
        r#"
        UPDATE Match_Disputes
        SET status = $1, resolved_by = $2, resolution_notes = $3, resolved_at = NOW()
        WHERE id = $4
        "#
    )
    .bind(status)
    .bind(resolved_dispute.resolved_by)
    .bind(&resolved_dispute.resolution_notes)
    .bind(resolved_dispute.id)
    .execute(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    // If void_match is requested, execute the voiding logic
    if payload.void_match.unwrap_or(false) && status == "resolved" {
        let dispute_row = sqlx::query("SELECT match_record_id FROM Match_Disputes WHERE id = $1")
            .bind(dispute_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|e| internal_error(e))?;
            
        if let Some(d) = dispute_row {
            let m_rec_id: Option<Uuid> = d.try_get("match_record_id").ok();
            if let Some(match_record_id) = m_rec_id {
                if let Err(e) = db::void_match(&state.pool, match_record_id).await {
                    println!("Error voiding match: {}", e);
                    return Err(internal_error("Failed to void match."));
                }
            }
        }
    } else {
        let dispute_row = sqlx::query("SELECT match_record_id FROM Match_Disputes WHERE id = $1")
            .bind(dispute_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|e| internal_error(e))?;
            
        if let Some(d) = dispute_row {
            let m_rec_id: Option<Uuid> = d.try_get("match_record_id").ok();
            if let Some(match_record_id) = m_rec_id {
                let _ = sqlx::query(
                    "UPDATE Match_Records SET verification_status = 'approved', updated_at = NOW() WHERE id = $1 AND verification_status = 'disputed'"
                )
                .bind(match_record_id)
                .execute(&state.pool)
                .await;

                if let Err(e) = db::apply_match_stats(&state.pool, match_record_id).await {
                    println!("[dispute] Error applying match stats: {}", e);
                }
                if let Err(e) = crate::domain::tournament::process_tournament_advancement(&state.pool, match_record_id).await {
                    println!("[dispute] Error processing tournament advancement: {}", e);
                }
            }
        }
    }

    Ok(Json(serde_json::json!({
        "status": "success",
        "dispute_id": dispute_id,
        "new_status": status,
        "voided": payload.void_match.unwrap_or(false)
    })))
}
