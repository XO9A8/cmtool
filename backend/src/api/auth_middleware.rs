//! # Axum Authentication Bearer Middleware
//!
//! Provides an Axum request extractor (`AuthenticatedUser`) that validates incoming HTTP
//! `Authorization: Bearer <token>` JWT tokens and extracts authenticated user claims.

use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{header, request::Parts, StatusCode},
    Json,
};
use uuid::Uuid;

use crate::{
    api::routes::{ApiErrorDetail, ApiErrorResponse},
    domain::auth::verify_jwt_token,
};

#[allow(dead_code)]
const JWT_SECRET: &str = "default_cmtool_jwt_secret_key_2026";

/// Extracted user credentials attached to authenticated Axum HTTP requests.
#[allow(dead_code)]
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    /// Authenticated user ID.
    pub user_id: Uuid,
    /// Authenticated username.
    pub username: String,
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, Json<ApiErrorResponse>);

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|h| h.to_str().ok())
            .ok_or_else(|| {
                (
                    StatusCode::UNAUTHORIZED,
                    Json(ApiErrorResponse {
                        error: ApiErrorDetail {
                            code: "MISSING_AUTH_HEADER".into(),
                            message: "Missing Authorization header".into(),
                        },
                    }),
                )
            })?;

        if !auth_header.starts_with("Bearer ") {
            return Err((
                StatusCode::UNAUTHORIZED,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "INVALID_AUTH_FORMAT".into(),
                        message: "Authorization header format must be 'Bearer <token>'".into(),
                    },
                }),
            ));
        }

        let token = &auth_header[7..];

        let supabase_url = std::env::var("SUPABASE_URL")
            .unwrap_or_else(|_| "https://ypsrkdefgbghvluuyynm.supabase.co".to_string());

        let claims = crate::api::jwks::verify_supabase_token(token, &supabase_url).await.map_err(|e| {
            tracing::error!("JWT Validation Failed: {}", e);
            (
                StatusCode::UNAUTHORIZED,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "INVALID_TOKEN".into(),
                        message: format!("Invalid or expired JWT token: {}", e),
                    },
                }),
            )
        })?;

        let user_id = Uuid::parse_str(&claims.sub).map_err(|_| {
            (
                StatusCode::UNAUTHORIZED,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "INVALID_USER_ID".into(),
                        message: "JWT claim subject is not a valid UUID".into(),
                    },
                }),
            )
        })?;

        Ok(AuthenticatedUser {
            user_id,
            username: claims.username.unwrap_or_else(|| "Supabase User".to_string()),
        })
    }
}
