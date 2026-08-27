//! # Axum API Routes & Router Composition Module
//!
//! Composes the public and protected API sub-routers by mounting modular domain handlers.

use std::sync::Arc;

use axum::{
    routing::{delete, get, patch, post, put},
    Router,
};
use tower_http::{cors::CorsLayer, trace::TraceLayer};

pub use crate::api::error::{bad_request, forbidden, internal_error, ApiErrorDetail, ApiErrorResponse};
use crate::{api::handlers, AppState};

/// Constructs the primary Axum router with public and protected sub-routers.
pub fn create_router(state: Arc<AppState>) -> Router {
    // Public endpoints (no auth required)
    let public = Router::new()
        .route("/health", get(handlers::system::health_check))
        .route("/version", get(handlers::system::get_version));

    // Protected endpoints (require valid JWT via AuthenticatedUser extractor)
    let protected = Router::new()
        // Auth & Identity
        .route("/api/v1/auth/sync", post(handlers::system::sync_user))
        
        // Club Management
        .route("/api/v1/clubs", post(handlers::clubs::create_club))
        .route("/api/v1/clubs/join", post(handlers::clubs::join_club))
        .route("/api/v1/clubs/my", get(handlers::clubs::get_my_clubs))
        .route("/api/v1/clubs/:id", get(handlers::clubs::get_club_details).put(handlers::clubs::update_club).delete(handlers::clubs::delete_club))
        .route("/api/v1/clubs/:id/regenerate-invite", post(handlers::clubs::regenerate_invite_code))
        .route("/api/v1/clubs/:id/transfer-ownership", post(handlers::clubs::transfer_ownership))
        .route("/api/v1/clubs/:id/leave", post(handlers::clubs::leave_club))
        .route("/api/v1/clubs/:id/members", get(handlers::clubs::get_club_members))
        .route("/api/v1/clubs/:id/members/:player_id/role", put(handlers::clubs::update_member_role))
        .route("/api/v1/clubs/:id/members/:player_id", delete(handlers::clubs::remove_member))
        .route("/api/v1/clubs/:id/tournaments", get(handlers::clubs::get_club_tournaments))
        .route("/api/v1/clubs/:id/activity", get(handlers::clubs::get_club_activity))
        .route("/api/v1/clubs/:id/resolved-activity", get(handlers::clubs::get_club_resolved_activity))
        .route("/api/v1/leaderboards/:club_id", get(handlers::clubs::get_leaderboard))
        
        // Match Operations & OCR
        .route("/api/v1/matches/ocr-submit", post(handlers::matches::ocr_submit))
        .route("/api/v1/matches/pending", get(handlers::matches::get_pending_matches))
        .route("/api/v1/matches/records/:id/dismiss", post(handlers::matches::dismiss_pending_match))
        .route("/api/v1/matches/:id/confirm", post(handlers::matches::confirm_match))
        .route("/api/v1/matches/predict", get(handlers::matches::predict_match))
        
        // Tournament Operations & Lifecycle
        .route("/api/v1/tournaments", post(handlers::tournaments::create_tournament))
        .route("/api/v1/tournaments/:id/bracket", get(handlers::tournaments::get_tournament_bracket))
        .route("/api/v1/tournaments/:id", delete(handlers::tournaments::delete_tournament))
        .route("/api/v1/tournaments/:id/standings", get(handlers::tournaments::get_league_standings))
        .route("/api/v1/tournaments/:id/player-stats", get(handlers::tournaments::get_tournament_player_stats))
        .route("/api/v1/tournaments/:id/start", post(handlers::tournaments::start_tournament))
        .route("/api/v1/tournaments/:id/settings", patch(handlers::tournaments::update_tournament_settings))
        .route("/api/v1/tournaments/:id/status", post(handlers::tournaments::update_tournament_status))
        .route("/api/v1/tournaments/:id/matchdays", get(handlers::tournaments::get_matchdays))
        .route("/api/v1/tournaments/:id/matchdays/:md_id/matches", get(handlers::tournaments::get_matchday_matches))
        .route("/api/v1/tournaments/:id/matchdays/:md_id/schedule", put(handlers::tournaments::update_matchday_schedule))
        .route("/api/v1/tournaments/:id/matches/:match_id/reschedule", put(handlers::tournaments::reschedule_match))
        .route("/api/v1/tournaments/:id/matchdays/:md_id/export/fixtures", get(handlers::tournaments::export_matchday_fixtures))
        .route("/api/v1/tournaments/:id/matchdays/:md_id/export/results", get(handlers::tournaments::export_matchday_results))
        .route("/api/v1/tournaments/:id/matchdays/:md_id/export/pdf", get(handlers::tournaments::export_matchday_pdf))
        .route("/api/v1/tournaments/:id/progress", get(handlers::tournaments::get_tournament_progress))
        .route("/api/v1/tournaments/:id/matches/:match_id/claim-forfeit", post(handlers::tournaments::claim_tournament_forfeit))
        
        // Player Dossier, Analytics & Rivalries
        .route("/api/v1/players/:id/profile", get(handlers::players::get_player_profile).put(handlers::players::update_player_profile))
        .route("/api/v1/players/:id/matches", get(handlers::players::get_player_matches))
        .route("/api/v1/players/:id/scheduled-matches", get(handlers::players::get_player_scheduled_matches))
        .route("/api/v1/players/:id/elo-history", get(handlers::players::get_elo_history))
        .route("/api/v1/players/:id/h2h/:opponent_id", get(handlers::players::get_h2h_record))
        .route("/api/v1/players/:id/analytics", get(handlers::players::get_player_analytics))
        
        // Disputes & Admin Governance
        .route("/api/v1/disputes", post(handlers::disputes::submit_dispute))
        .route("/api/v1/admin/disputes", get(handlers::admin::get_admin_disputes))
        .route("/api/v1/admin/disputes/:id/resolve", post(handlers::admin::resolve_admin_dispute))
        .route("/api/v1/seasons/snapshot", post(handlers::admin::snapshot_season))
        .route("/api/v1/admin/feature-flags", post(handlers::admin::update_feature_flags));

    public
        .merge(protected)
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::permissive())
        .with_state(state)
}
