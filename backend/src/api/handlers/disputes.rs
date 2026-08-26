use std::sync::Arc;

use axum::{extract::State, http::StatusCode, Json};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::{
    api::{
        auth_middleware::AuthenticatedUser,
        error::{bad_request, internal_error, ApiErrorResponse},
    },
    infrastructure::postgres_adapter as db,
    AppState,
};

#[derive(Deserialize)]
pub struct SubmitDisputeRequest {
    pub match_record_id: Uuid,
    pub reason: String,
}

#[derive(Serialize)]
pub struct DisputeResponse {
    pub dispute_id: Uuid,
    pub match_record_id: Uuid,
    pub raised_by: Uuid,
    pub reason: String,
    pub status: String,
}

/// Persists a match result dispute into the database for admin review.
pub async fn submit_dispute(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<SubmitDisputeRequest>,
) -> Result<Json<DisputeResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    
    // Check if Match_Records row exists directly or via t_match_id
    let record_row = sqlx::query(
        "SELECT id, verification_status, player_id, opponent_id FROM Match_Records WHERE id = $1 OR t_match_id = $1"
    )
    .bind(payload.match_record_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| internal_error("Failed to fetch match record"))?;

    let t_match_row = if record_row.is_none() {
        sqlx::query(
            "SELECT id, tournament_id, player_1_id, player_2_id, player_1_score::INT4 AS player_1_score, player_2_score::INT4 AS player_2_score, status FROM T_Matches WHERE id = $1"
        )
        .bind(payload.match_record_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| internal_error("Failed to fetch tournament match"))?
    } else {
        None
    };

    let (match_record_id, verification_status, player_id, opponent_id) = if let Some(row) = record_row {
        let m_id: Uuid = row.get("id");
        let v_status: String = row.get::<Option<String>, _>("verification_status").unwrap_or_default();
        let p_id: Uuid = row.get("player_id");
        let o_id: Uuid = row.get("opponent_id");
        (m_id, v_status, p_id, o_id)
    } else if let Some(t_row) = t_match_row {
        let match_status: String = t_row.get("status");
        if match_status == "scheduled" {
            return Err(bad_request("UNPLAYED_MATCH", "Cannot dispute a scheduled match that has no result."));
        }

        let tm_id: Uuid = t_row.get("id");
        let tournament_id: Uuid = t_row.get("tournament_id");
        let p1_id: Option<Uuid> = t_row.try_get("player_1_id").ok().flatten();
        let p2_id: Option<Uuid> = t_row.try_get("player_2_id").ok().flatten();
        let p1_score: i32 = t_row.try_get::<Option<i32>, _>("player_1_score").ok().flatten().unwrap_or(0);
        let p2_score: i32 = t_row.try_get::<Option<i32>, _>("player_2_score").ok().flatten().unwrap_or(0);

        let club_id: Option<Uuid> = sqlx::query_scalar("SELECT club_id FROM Tournaments WHERE id = $1")
            .bind(tournament_id)
            .fetch_optional(&state.pool)
            .await
            .ok()
            .flatten();

        let club_id = match club_id {
            Some(cid) => cid,
            None => return Err(internal_error("Tournament club not found")),
        };

        // Ensure player_id is the dispute raiser if they are one of the participants
        let raiser_is_p2 = p2_id == Some(auth.user_id);
        let player_id = if raiser_is_p2 { p2_id.unwrap() } else { p1_id.unwrap_or(auth.user_id) };
        let opponent_id = if raiser_is_p2 { p1_id.unwrap_or(auth.user_id) } else { p2_id.unwrap_or(auth.user_id) };
        
        let (goals_for, goals_against) = if raiser_is_p2 {
            (p2_score, p1_score)
        } else {
            (p1_score, p2_score)
        };

        let new_m_id = Uuid::new_v4();
        let res_str = if goals_for > goals_against { "win" } else if goals_for < goals_against { "loss" } else { "draw" };
        let hash_str = format!("manual_dispute_{}", new_m_id);

        sqlx::query(
            r#"
            INSERT INTO Match_Records (
                id, club_id, t_match_id, player_id, opponent_id, goals_for, goals_against,
                result, possession, passes_completed, passes_attempted,
                shots_on_target, shots_total, interceptions, screenshot_hash,
                verification_status
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 50.0, 0, 0, 0, 0, 0, $9, 'disputed')
            "#
        )
        .bind(new_m_id)
        .bind(club_id)
        .bind(tm_id)
        .bind(player_id)
        .bind(opponent_id)
        .bind(goals_for)
        .bind(goals_against)
        .bind(res_str)
        .bind(hash_str)
        .execute(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;

        (new_m_id, "disputed".to_string(), player_id, opponent_id)
    } else {
        return Err(bad_request("NOT_FOUND", "Match record not found."));
    };

    let is_official_result = sqlx::query(
        r#"
        SELECT EXISTS (
            SELECT 1 
            FROM Club_Memberships cm_off
            JOIN Club_Memberships cm_player ON cm_off.club_id = cm_player.club_id
            WHERE cm_off.player_id = $1
              AND LOWER(cm_off.role) IN ('admin', 'organizer')
              AND (cm_player.player_id = $2 OR cm_player.player_id = $3)
        ) AS is_official
        "#
    )
    .bind(auth.user_id)
    .bind(player_id)
    .bind(opponent_id)
    .fetch_one(&state.pool)
    .await;

    let is_official = is_official_result.map(|r| r.get::<Option<bool>, _>("is_official").unwrap_or(false)).unwrap_or(false);

    if auth.user_id != player_id && auth.user_id != opponent_id && !is_official {
        return Err(bad_request("UNAUTHORIZED", "Only participants or club officials can dispute a match."));
    }

    if verification_status == "approved" && !is_official {
        return Err(bad_request("UNAUTHORIZED", "Only officials can dispute a verified match."));
    }

    let dispute = crate::domain::disputes::raise_match_dispute(match_record_id, auth.user_id, payload.reason.clone(), None);

    let dispute_id = db::save_dispute(
        &state.pool,
        dispute.match_record_id,
        dispute.raised_by,
        &dispute.reason,
    )
    .await
    .unwrap_or(dispute.id);

    // Update Match_Records verification_status to 'disputed'
    let _ = sqlx::query(
        "UPDATE Match_Records SET verification_status = 'disputed', updated_at = NOW() WHERE id = $1"
    )
    .bind(match_record_id)
    .execute(&state.pool)
    .await;

    Ok(Json(DisputeResponse {
        dispute_id,
        match_record_id,
        raised_by:       auth.user_id,
        reason:          payload.reason,
        status:          "open".into(),
    }))
}
