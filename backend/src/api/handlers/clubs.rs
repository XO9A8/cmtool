use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    api::{
        auth_middleware::AuthenticatedUser,
        error::{bad_request, forbidden, internal_error, ApiErrorResponse},
    },
    domain::play_style::PlayStyleTag,
    infrastructure::postgres_adapter as db,
    AppState,
};

#[derive(Deserialize)]
pub struct CreateClubRequest {
    pub name: String,
    pub invite_code: String,
}

#[derive(Serialize)]
pub struct CreateClubResponse {
    pub club_id: Uuid,
    pub name: String,
    pub invite_code: String,
}

/// Creates a new club and makes the authenticated user the owner/admin.
pub async fn create_club(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<CreateClubRequest>,
) -> Result<Json<CreateClubResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    if payload.name.trim().is_empty() || payload.invite_code.trim().is_empty() {
        return Err(bad_request("INVALID_CLUB", "Club name and invite code are required"));
    }

    let club_id = db::create_club(&state.pool, &payload.name, &payload.invite_code, auth.user_id)
        .await
        .map_err(|e| {
            let err_str = e.to_string();
            if err_str.contains("unique constraint") || err_str.contains("clubs_invite_code_key") {
                bad_request(
                    "INVITE_CODE_TAKEN",
                    "This invite code is already in use by another club. Please choose a different invite code.",
                )
            } else {
                internal_error(e)
            }
        })?;

    Ok(Json(CreateClubResponse {
        club_id,
        name: payload.name,
        invite_code: payload.invite_code,
    }))
}

#[derive(Deserialize)]
pub struct JoinClubRequest {
    pub invite_code: String,
}

#[derive(Serialize)]
pub struct JoinClubResponse {
    pub club_id: Uuid,
    pub message: String,
}

/// Allows the authenticated player to join a club using an invite code.
pub async fn join_club(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<JoinClubRequest>,
) -> Result<Json<JoinClubResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_id: Option<Uuid> = sqlx::query_scalar("SELECT id FROM Clubs WHERE invite_code = $1 AND deleted_at IS NULL")
        .bind(&payload.invite_code)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
        
    let club_id = match club_id {
        Some(c) => c,
        None => return Err(bad_request("INVALID_INVITE_CODE", "No club found with that invite code")),
    };
    
    let is_member: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM Club_Memberships WHERE club_id = $1 AND player_id = $2)")
        .bind(club_id)
        .bind(auth.user_id)
        .fetch_one(&state.pool)
        .await
        .unwrap_or(false);
        
    if is_member {
        return Err(bad_request("ALREADY_MEMBER", "You are already a member of this club."));
    }

    let joined_club_id = db::join_club_by_invite(&state.pool, auth.user_id, &auth.username, &payload.invite_code)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(JoinClubResponse {
        club_id: joined_club_id,
        message: "Successfully joined club".into(),
    }))
}

/// Returns all clubs the authenticated player belongs to.
pub async fn get_my_clubs(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let clubs = db::get_player_clubs(&state.pool, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;

    let result: Vec<serde_json::Value> = clubs
        .into_iter()
        .map(|c| {
            serde_json::json!({
                "id": c.id,
                "name": c.name,
                "invite_code": c.invite_code,
                "owner_id": c.owner_id,
                "member_count": c.member_count,
                "is_owner": c.owner_id == Some(auth.user_id),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({ "clubs": result })))
}

/// Returns all members of a club with their ratings and roles.
pub async fn get_club_members(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let members = db::get_club_members(&state.pool, club_id)
        .await
        .map_err(|e| internal_error(e))?;

    let result: Vec<serde_json::Value> = members
        .into_iter()
        .map(|m| {
            serde_json::json!({
                "user_id": m.user_id,
                "username": m.username,
                "role": m.role,
                "skill_rating": m.skill_rating,
                "form_rating": m.form_rating,
                "play_style": m.play_style.unwrap_or_else(|| "Unclassified".into()),
                "matches_played": m.matches_played,
            })
        })
        .collect();

    Ok(Json(serde_json::json!({ "members": result })))
}

#[derive(Deserialize)]
pub struct UpdateRoleRequest {
    pub role: String,
}

/// Updates a club member's role (admin, organizer, player).
pub async fn update_member_role(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((club_id, player_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<UpdateRoleRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    if !is_official {
        return Err(forbidden("FORBIDDEN", "Only club officials can update roles."));
    }

    if player_id == auth.user_id {
        return Err(bad_request("SELF_DEMOTION", "You cannot change your own role."));
    }

    let valid_roles = ["admin", "organizer", "player"];
    if !valid_roles.contains(&payload.role.as_str()) {
        return Err(bad_request("INVALID_ROLE", "Role must be admin, organizer, or player"));
    }

    db::update_member_role(&state.pool, club_id, player_id, &payload.role)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "message": format!("Role updated to {}", payload.role),
        "player_id": player_id,
        "new_role": payload.role,
    })))
}

/// Removes a member from a club.
pub async fn remove_member(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((club_id, player_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    
    if !is_official {
        return Err(forbidden("FORBIDDEN", "Only club officials can remove members."));
    }

    let is_owner = db::is_club_owner(&state.pool, club_id, player_id)
        .await
        .map_err(|e| internal_error(e))?;
        
    if is_owner {
        return Err(bad_request("FORBIDDEN", "Cannot remove the club owner."));
    }

    db::remove_club_member(&state.pool, club_id, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "message": "Member removed from club",
        "player_id": player_id,
    })))
}

#[derive(Deserialize)]
pub struct UpdateClubRequest {
    pub name: String,
    pub invite_code: String,
}

/// Updates club details (name and invite code).
pub async fn update_club(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
    Json(payload): Json<UpdateClubRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    
    if !is_official {
        return Err(forbidden("FORBIDDEN", "Only club officials can update club details."));
    }

    db::update_club_details(&state.pool, club_id, &payload.name, &payload.invite_code)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "message": "Club updated successfully",
        "club_id": club_id,
    })))
}

/// Lists all tournaments for a club.
pub async fn get_club_tournaments(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let tournaments = db::get_club_tournaments(&state.pool, club_id)
        .await
        .map_err(|e| internal_error(e))?;

    let result: Vec<serde_json::Value> = tournaments
        .into_iter()
        .map(|t| {
            serde_json::json!({
                "id": t.id,
                "name": t.name,
                "format_type": t.format_type,
                "status": t.status,
                "participant_count": t.participant_count,
                "club_id": t.club_id,
                "created_at": t.created_at.to_rfc3339(),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({ "tournaments": result })))
}

#[derive(Serialize)]
pub struct LeaderboardEntry {
    pub rank: usize,
    pub player_id: Uuid,
    pub player_name: String,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: String,
}

/// Returns club player rankings. Live DB query when `enable_live_standings` is true.
pub async fn get_leaderboard(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Json<Vec<LeaderboardEntry>> {
    let use_live = state.flags.read().await.enable_live_standings;

    if use_live {
        if let Ok(rows) = db::get_club_leaderboard_db(&state.pool, club_id).await {
            let entries = rows
                .into_iter()
                .enumerate()
                .map(|(i, row)| LeaderboardEntry {
                    rank: i + 1,
                    player_id: row.user_id,
                    player_name: row.username,
                    skill_rating: row.skill_rating,
                    form_rating: row.form_rating,
                    play_style: row.play_style.unwrap_or_else(|| "Unclassified".into()),
                })
                .collect();
            return Json(entries);
        }
    }

    // Fallback: static snapshot
    Json(vec![
        LeaderboardEntry {
            rank: 1,
            player_id: Uuid::nil(),
            player_name: "ApexStriker".into(),
            skill_rating: 1420,
            form_rating: 84.5,
            play_style: PlayStyleTag::PossessionMaster.as_str().into(),
        },
        LeaderboardEntry {
            rank: 2,
            player_id: Uuid::nil(),
            player_name: "TikiTakaKing".into(),
            skill_rating: 1350,
            form_rating: 72.0,
            play_style: PlayStyleTag::CounterAttacker.as_str().into(),
        },
    ])
}

#[derive(Deserialize)]
pub struct ActivityQuery {
    pub limit: Option<i64>,
}

pub async fn get_club_activity(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
    Query(query): Query<ActivityQuery>,
) -> Result<Json<Vec<crate::infrastructure::postgres_adapter::ClubActivityRow>>, (StatusCode, Json<ApiErrorResponse>)> {
    let limit = query.limit.unwrap_or(20);
    let rows = crate::infrastructure::postgres_adapter::get_club_activity(&state.pool, club_id, limit)
        .await
        .map_err(|e| internal_error(e))?;
    Ok(Json(rows))
}

pub async fn get_club_resolved_activity(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
    Query(query): Query<ActivityQuery>,
) -> Result<Json<Vec<crate::infrastructure::postgres_adapter::ClubResolvedMatchRow>>, (StatusCode, Json<ApiErrorResponse>)> {
    let limit = query.limit.unwrap_or(20);
    let rows = crate::infrastructure::postgres_adapter::get_club_resolved_matches(&state.pool, club_id, limit)
        .await
        .map_err(|e| internal_error(e))?;
    Ok(Json(rows))
}
