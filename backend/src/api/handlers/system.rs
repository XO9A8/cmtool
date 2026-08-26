use std::sync::Arc;

use axum::{extract::State, http::StatusCode, Json};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    api::{
        auth_middleware::AuthenticatedUser,
        error::{internal_error, ApiErrorResponse},
    },
    infrastructure::postgres_adapter as db,
    AppState,
};

pub async fn health_check() -> (StatusCode, &'static str) {
    (StatusCode::OK, "eFootball Management API v1 OK")
}

#[derive(Deserialize)]
pub struct SyncUserRequest {
    pub username: String,
}

#[derive(Serialize)]
pub struct SyncUserResponse {
    pub user_id: Uuid,
    pub username: String,
}

/// Syncs a Supabase authenticated user to the local database, ensuring they have a Player Profile.
pub async fn sync_user(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<SyncUserRequest>,
) -> Result<Json<SyncUserResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    db::upsert_supabase_user(&state.pool, auth.user_id, &payload.username)
        .await
        .map_err(|e| internal_error(e.to_string()))?;

    Ok(Json(SyncUserResponse {
        user_id: auth.user_id,
        username: payload.username,
    }))
}

#[derive(Serialize)]
pub struct AppVersionInfo {
    pub version: String,
    pub build_number: u32,
    pub download_url: String,
    pub release_notes: String,
    pub force_update: bool,
}

pub async fn get_version() -> (StatusCode, Json<AppVersionInfo>) {
    let version = std::env::var("APP_LATEST_VERSION").unwrap_or_else(|_| "0.1.0".to_string());
    let build_number = std::env::var("APP_LATEST_BUILD")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);
    let download_url = std::env::var("APP_DOWNLOAD_URL").unwrap_or_else(|_| "https://drive.google.com/drive/folders/1wRlIh9fDp0S2uN46zcmbIoNWktXl4Un5".to_string());
    let release_notes = std::env::var("APP_RELEASE_NOTES").unwrap_or_else(|_| "Performance improvements and bug fixes.".to_string());
    let force_update = std::env::var("APP_FORCE_UPDATE")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(false);

    (
        StatusCode::OK,
        Json(AppVersionInfo {
            version,
            build_number,
            download_url,
            release_notes,
            force_update,
        }),
    )
}
