use axum::{http::StatusCode, Json};
use serde::Serialize;

/// Standard error response wrapper.
#[derive(Serialize, Clone, Debug)]
pub struct ApiErrorResponse {
    pub error: ApiErrorDetail,
}

/// Detailed error response code and user-facing message.
#[derive(Serialize, Clone, Debug)]
pub struct ApiErrorDetail {
    pub code: String,
    pub message: String,
}

pub fn internal_error(msg: impl ToString) -> (StatusCode, Json<ApiErrorResponse>) {
    let err_str = msg.to_string();
    tracing::error!("❌ [HTTP 500 Internal Error]: {}", err_str);
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(ApiErrorResponse {
            error: ApiErrorDetail {
                code: "INTERNAL_ERROR".into(),
                message: err_str,
            },
        }),
    )
}

pub fn bad_request(code: &str, msg: &str) -> (StatusCode, Json<ApiErrorResponse>) {
    tracing::warn!("⚠️ [HTTP 400 Bad Request] [{}]: {}", code, msg);
    (
        StatusCode::BAD_REQUEST,
        Json(ApiErrorResponse {
            error: ApiErrorDetail {
                code: code.to_string(),
                message: msg.to_string(),
            },
        }),
    )
}

pub fn forbidden(code: &str, msg: &str) -> (StatusCode, Json<ApiErrorResponse>) {
    tracing::warn!("⚠️ [HTTP 403 Forbidden] [{}]: {}", code, msg);
    (
        StatusCode::FORBIDDEN,
        Json(ApiErrorResponse {
            error: ApiErrorDetail {
                code: code.to_string(),
                message: msg.to_string(),
            },
        }),
    )
}

pub fn not_found(code: &str, msg: &str) -> (StatusCode, Json<ApiErrorResponse>) {
    tracing::warn!("⚠️ [HTTP 404 Not Found] [{}]: {}", code, msg);
    (
        StatusCode::NOT_FOUND,
        Json(ApiErrorResponse {
            error: ApiErrorDetail {
                code: code.to_string(),
                message: msg.to_string(),
            },
        }),
    )
}

