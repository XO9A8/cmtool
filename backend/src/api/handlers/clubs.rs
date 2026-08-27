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
        error::{bad_request, forbidden, internal_error, not_found, ApiErrorResponse},
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
            let role = c.user_role.clone().unwrap_or_else(|| "player".into());
            serde_json::json!({
                "id": c.id,
                "name": c.name,
                "invite_code": c.invite_code,
                "owner_id": c.owner_id,
                "member_count": c.member_count,
                "user_role": role,
                "role": role,
                "is_owner": c.owner_id == Some(auth.user_id),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({ "clubs": result })))
}

/// Returns full details for a single club.
pub async fn get_club_details(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let club = db::get_club_by_id(&state.pool, club_id)
        .await
        .map_err(internal_error)?
        .ok_or_else(|| not_found("NOT_FOUND", "Club not found"))?;

    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;

    let is_owner = club.owner_id == Some(auth.user_id);

    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM Club_Memberships WHERE club_id = $1 AND player_id = $2"
    )
    .bind(club_id)
    .bind(auth.user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(internal_error)?;

    Ok(Json(serde_json::json!({
        "id": club.id,
        "name": club.name,
        "invite_code": club.invite_code,
        "owner_id": club.owner_id,
        "member_count": club.member_count,
        "created_at": club.created_at.to_rfc3339(),
        "updated_at": club.updated_at.to_rfc3339(),
        "user_role": user_role.clone().unwrap_or_else(|| "player".into()),
        "role": user_role.unwrap_or_else(|| "player".into()),
        "is_official": is_official || is_owner,
        "is_owner": is_owner,
    })))
}

/// Returns all members of a club with their ratings and roles.
pub async fn get_club_members(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_info = db::get_club_by_id(&state.pool, club_id)
        .await
        .map_err(internal_error)?;

    let members = db::get_club_members(&state.pool, club_id)
        .await
        .map_err(internal_error)?;

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
                "avatar_graphic": m.avatar_graphic,
            })
        })
        .collect();

    let mut response_map = serde_json::Map::new();
    response_map.insert("members".to_string(), serde_json::Value::Array(result));

    if let Some(club) = club_info {
        response_map.insert("club".to_string(), serde_json::json!({
            "id": club.id,
            "name": club.name,
            "invite_code": club.invite_code,
            "owner_id": club.owner_id,
            "member_count": club.member_count,
            "created_at": club.created_at.to_rfc3339(),
            "updated_at": club.updated_at.to_rfc3339(),
        }));
        response_map.insert("invite_code".to_string(), serde_json::Value::String(club.invite_code));
        response_map.insert("name".to_string(), serde_json::Value::String(club.name));
    }

    Ok(Json(serde_json::Value::Object(response_map)))
}

#[derive(Deserialize)]
pub struct UpdateRoleRequest {
    pub role: String,
}

/// Updates a club member's role (admin, organizer, president, captain, vice-captain, player).
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

    let valid_roles = ["admin", "organizer", "president", "captain", "vice-captain", "player"];
    let role_lower = payload.role.to_lowercase();
    if !valid_roles.contains(&role_lower.as_str()) {
        return Err(bad_request("INVALID_ROLE", "Role must be admin, organizer, president, captain, vice-captain, or player"));
    }

    db::update_member_role(&state.pool, club_id, player_id, &role_lower)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "message": format!("Role updated to {}", role_lower),
        "player_id": player_id,
        "new_role": role_lower,
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
    pub invite_code: Option<String>,
}

/// Updates club details (name and optionally invite code).
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

    let trimmed_name = payload.name.trim();
    if trimmed_name.is_empty() {
        return Err(bad_request("INVALID_NAME", "Club name cannot be empty."));
    }

    let trimmed_code = payload.invite_code.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty());
    if let Some(code) = trimmed_code {
        let code_taken: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM Clubs WHERE invite_code = $1 AND id != $2 AND deleted_at IS NULL)"
        )
        .bind(code)
        .bind(club_id)
        .fetch_one(&state.pool)
        .await
        .map_err(internal_error)?;

        if code_taken {
            return Err(bad_request(
                "INVITE_CODE_TAKEN",
                "This invite code is already in use by another club. Please choose a different code.",
            ));
        }
    }

    db::update_club_details(&state.pool, club_id, trimmed_name, trimmed_code)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "message": "Club updated successfully",
        "club_id": club_id,
        "name": trimmed_name,
    })))
}

/// Regenerates a unique invite code for the club.
pub async fn regenerate_invite_code(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;
    
    if !is_official {
        return Err(forbidden("FORBIDDEN", "Only club officials can regenerate invite codes."));
    }

    let new_code = db::regenerate_club_invite_code(&state.pool, club_id)
        .await
        .map_err(internal_error)?;

    Ok(Json(serde_json::json!({
        "message": "Invite code regenerated successfully",
        "club_id": club_id,
        "invite_code": new_code,
    })))
}

#[derive(Deserialize)]
pub struct TransferOwnershipRequest {
    pub new_owner_id: Uuid,
}

/// Transfers club ownership to another member.
pub async fn transfer_ownership(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
    Json(payload): Json<TransferOwnershipRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_owner = db::is_club_owner(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;

    if !is_owner {
        return Err(forbidden("FORBIDDEN", "Only the current club owner can transfer ownership."));
    }

    if payload.new_owner_id == auth.user_id {
        return Err(bad_request("INVALID_TARGET", "You are already the owner."));
    }

    let is_member: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM Club_Memberships WHERE club_id = $1 AND player_id = $2)"
    )
    .bind(club_id)
    .bind(payload.new_owner_id)
    .fetch_one(&state.pool)
    .await
    .map_err(internal_error)?;

    if !is_member {
        return Err(bad_request("NOT_A_MEMBER", "The selected user is not a member of this club."));
    }

    db::transfer_club_ownership(&state.pool, club_id, payload.new_owner_id)
        .await
        .map_err(internal_error)?;

    Ok(Json(serde_json::json!({
        "message": "Club ownership transferred successfully",
        "club_id": club_id,
        "new_owner_id": payload.new_owner_id,
    })))
}

/// Allows a player to leave a club.
pub async fn leave_club(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_owner = db::is_club_owner(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;

    if is_owner {
        return Err(bad_request("OWNER_CANNOT_LEAVE", "Club owners cannot leave their club. Transfer ownership or delete the club instead."));
    }

    let is_member: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM Club_Memberships WHERE club_id = $1 AND player_id = $2)"
    )
    .bind(club_id)
    .bind(auth.user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(internal_error)?;

    if !is_member {
        return Err(bad_request("NOT_A_MEMBER", "You are not a member of this club."));
    }

    db::leave_club(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;

    Ok(Json(serde_json::json!({
        "message": "You have left the club.",
        "club_id": club_id,
    })))
}

/// Disbands / deletes a club.
pub async fn delete_club(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_owner = db::is_club_owner(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;

    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(internal_error)?;

    if !is_owner && !is_official {
        return Err(forbidden("FORBIDDEN", "Only club owners or officials can delete the club."));
    }

    db::delete_club(&state.pool, club_id)
        .await
        .map_err(internal_error)?;

    Ok(Json(serde_json::json!({
        "message": "Club deleted successfully",
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
