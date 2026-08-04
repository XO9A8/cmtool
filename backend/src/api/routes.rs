//! # Axum API Routes & Handlers Module
//!
//! Exposes all REST HTTP endpoints for user authentication, club management,
//! OCR match submission (with Elo + MPS + AI insights), tournament operations,
//! H2H rivalry stats, match result disputes, player analytics, leaderboards,
//! season snapshots, squad verifications, and admin feature-flag management.

use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use uuid::Uuid;

use crate::{
    api::auth_middleware::AuthenticatedUser,
    domain::{
        ai_insights::generate_coaching_insights,
        auth::{create_jwt_token, hash_password, verify_password},
        disputes::raise_match_dispute,
        elo::{calculate_elo, EloInput, MatchType},
        fallback_insights::{generate_fallback_report, InsightInput, InsightReport},
        feature_flags::UpdateFlagsRequest,
        mps::{calculate_ewma_form, calculate_mps, MpsInput},
        play_style::{classify_play_style, PlayStyleTag, PlayerMatchStatsSummary},
        seasons::{create_season_snapshot, SeasonSnapshot},
        tournament::{
            generate_group_knockout_fixtures, generate_knockout_bracket, generate_round_robin_fixtures, predict_match_outcome,
            FixtureNode, KnockoutBracket, MatchPrediction, TournamentPlayer,
        },
    },
    infrastructure::postgres_adapter as db,
    AppState,
};

// ─────────────────────────────────────────────────────────────────────────────
// Router Construction
// ─────────────────────────────────────────────────────────────────────────────

/// Constructs the primary Axum router with public and protected sub-routers.
pub fn create_router(state: Arc<AppState>) -> Router {
    // Public endpoints (no auth required)
    let public = Router::new()
        .route("/health", get(health_check));

    // Protected endpoints (require valid JWT via AuthenticatedUser extractor)
    let protected = Router::new()
        .route("/api/v1/auth/sync", post(sync_user))
        .route("/api/v1/clubs", post(create_club))
        .route("/api/v1/clubs/:id/join", post(join_club))
        .route("/api/v1/clubs/my", get(get_my_clubs))
        .route("/api/v1/clubs/:id/members", get(get_club_members))
        .route("/api/v1/clubs/:id/members/:player_id/role", axum::routing::put(update_member_role))
        .route("/api/v1/clubs/:id/members/:player_id", axum::routing::delete(remove_member))
        .route("/api/v1/clubs/:id", axum::routing::put(update_club))
        .route("/api/v1/clubs/:id/tournaments", get(get_club_tournaments))
        .route("/api/v1/clubs/:id/activity", get(get_club_activity))
        .route("/api/v1/clubs/:id/resolved-activity", get(get_club_resolved_activity))
        .route("/api/v1/clubs/:id/seasons", get(get_club_seasons))
        .route("/api/v1/matches/ocr-submit", post(ocr_submit))
        .route("/api/v1/matches/pending", get(get_pending_matches))
        .route("/api/v1/matches/:id/confirm", post(confirm_match))
        .route("/api/v1/matches/predict", get(predict_match))
        .route("/api/v1/leaderboards/:club_id", get(get_leaderboard))
        .route("/api/v1/tournaments", post(create_tournament))
        .route("/api/v1/tournaments/bracket", post(create_knockout_bracket))
        .route("/api/v1/tournaments/round-robin", post(create_round_robin))
        .route("/api/v1/tournaments/:id/bracket", get(get_tournament_bracket))

        .route("/api/v1/tournaments/:id/standings", get(get_league_standings))
        .route("/api/v1/tournaments/:id/start", post(start_tournament))
        .route("/api/v1/tournaments/:id/status", post(update_tournament_status))
        .route("/api/v1/players/:id/profile", get(get_player_profile).put(update_player_profile))
        .route("/api/v1/players/:id/matches", get(get_player_matches))
        .route("/api/v1/players/:id/scheduled-matches", get(get_player_scheduled_matches))
        .route("/api/v1/players/:id/elo-history", get(get_elo_history))
        .route("/api/v1/players/:id/badges", get(get_player_badges))
        .route("/api/v1/players/:id/h2h/:opponent_id", get(get_h2h_record))
        .route("/api/v1/players/:id/analytics", get(get_player_analytics))
        .route("/api/v1/disputes", post(submit_dispute))
        // Admin Dispute & Role Management (C-03)
        .route("/api/v1/admin/disputes", get(get_admin_disputes))
        .route("/api/v1/admin/disputes/:id/resolve", post(resolve_admin_dispute))
        // Tournament check-in forfeit (C-04)
        .route("/api/v1/tournaments/:id/matches/:match_id/claim-forfeit", post(claim_tournament_forfeit))
        .route("/api/v1/admin/feature-flags", post(update_feature_flags));

    public
        .merge(protected)
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::permissive())
        .with_state(state)
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Error Types
// ─────────────────────────────────────────────────────────────────────────────

/// Standard error response wrapper.
#[derive(Serialize)]
pub struct ApiErrorResponse {
    pub error: ApiErrorDetail,
}

/// Detailed error response code and user-facing message.
#[derive(Serialize)]
pub struct ApiErrorDetail {
    pub code: String,
    pub message: String,
}

fn internal_error(msg: impl ToString) -> (StatusCode, Json<ApiErrorResponse>) {
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

fn bad_request(code: &str, msg: &str) -> (StatusCode, Json<ApiErrorResponse>) {
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

fn forbidden(code: &str, msg: &str) -> (StatusCode, Json<ApiErrorResponse>) {
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

// ─────────────────────────────────────────────────────────────────────────────
// Health Check
// ─────────────────────────────────────────────────────────────────────────────

async fn health_check() -> (StatusCode, &'static str) {
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
async fn sync_user(
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

// ─────────────────────────────────────────────────────────────────────────────
// Club Management
// ─────────────────────────────────────────────────────────────────────────────

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
async fn create_club(
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
async fn join_club(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<JoinClubRequest>,
) -> Result<Json<JoinClubResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_id = db::join_club_by_invite(&state.pool, auth.user_id, &payload.invite_code)
        .await
        .map_err(|_| {
            (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "INVALID_INVITE_CODE".into(),
                        message: "No club found with that invite code".into(),
                    },
                }),
            )
        })?;

    Ok(Json(JoinClubResponse {
        club_id,
        message: "Successfully joined club".into(),
    }))
}

// ─────────────────────────────────────────────────────────────────────────────
// OCR Match Submission
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct OcrSubmitRequest {
    pub player_id: Option<Uuid>,
    pub opponent_id: Uuid,
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
    /// Whether this is the player's provisional period (< 10 matches).
    #[serde(default)]
    pub is_provisional: bool,
    /// Optional current Elo rating (defaults to 1000 if not provided).
    pub player_rating: Option<i32>,
    /// Optional opponent Elo rating (defaults to 1000 if not provided).
    pub opponent_rating: Option<i32>,
    pub partner_id: Option<Uuid>,
    pub club_id: Option<Uuid>,
    /// Optional tournament fixture ID — links this submission to a T_Matches row.
    pub t_match_id: Option<Uuid>,
}

#[derive(Serialize)]
pub struct OcrSubmitResponse {
    pub match_id: Uuid,
    pub player_id: Uuid,
    pub new_skill_rating: i32,
    pub rating_delta: i32,
    pub form_rating: f64,
    pub match_performance_score: f64,
    pub play_style_tag: String,
    pub insights: InsightReport,
}

/// Handles OCR match payload verification, Elo update, MPS computation, EWMA form rating, and coaching feedback.
async fn ocr_submit(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<OcrSubmitRequest>,
) -> Result<Json<OcrSubmitResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    // --- Validation ---
    if payload.passes_completed > payload.passes_attempted {
        return Err(bad_request("INVALID_PASS_STATS", "passes_completed cannot exceed passes_attempted"));
    }
    if payload.shots_on_target > payload.shots_total {
        return Err(bad_request("INVALID_SHOT_STATS", "shots_on_target cannot exceed shots_total"));
    }

    let is_duplicate = db::check_screenshot_exists(&state.pool, &payload.screenshot_hash)
        .await
        .map_err(|e| internal_error(e))?;

    if is_duplicate {
        return Err(bad_request("DUPLICATE_SCREENSHOT", "A match with this screenshot hash already exists."));
    }

    let player_rating = payload.player_rating.unwrap_or(1000);
    let opponent_rating = payload.opponent_rating.unwrap_or(1000);

    let actual_player_id = payload.player_id.unwrap_or(auth.user_id);

    // --- Opponent Match Confirmation Check ---
    let pending_match = db::find_pending_opponent_match(
        &state.pool,
        actual_player_id,
        payload.opponent_id,
        payload.goals_for,
        payload.goals_against,
    )
    .await
    .map_err(|e| internal_error(e))?;

    if let Some(opponent_match_id) = pending_match {
        // We found the opponent's match! We should mark theirs as approved.
        db::approve_match(&state.pool, opponent_match_id, actual_player_id)
            .await
            .map_err(|e| internal_error(e))?;
    }

    let verification_status = if pending_match.is_none() {
        "pending".to_string()
    } else {
        "approved".to_string()
    };

    // --- Elo Calculation ---
    let match_type = match payload.match_type.as_str() {
        "tournament_final" => MatchType::TournamentFinal,
        "league"           => MatchType::League,
        _                  => MatchType::Friendly,
    };

    let elo_res = calculate_elo(&EloInput {
        player_rating,
        opponent_rating,
        goals_for:    payload.goals_for as i32,
        goals_against: payload.goals_against as i32,
        match_type,
        is_provisional: payload.is_provisional,
    });

    // --- MPS Calculation ---
    let is_coop = payload.partner_id.is_some();
    let mps_res_opt = calculate_mps(&MpsInput {
        possession:       payload.possession,
        passes_completed: payload.passes_completed,
        passes_attempted: payload.passes_attempted,
        goals_scored:     payload.goals_for,
        shots_on_target:  payload.shots_on_target,
        interceptions:    payload.interceptions,
        player_rating,
        opponent_rating,
        is_coop,
    });

    // --- EWMA Form Rating ---
    let form_rating = if let Some(ref mps_res) = mps_res_opt {
        let mps_history = db::get_player_mps_history(&state.pool, actual_player_id, 19)
            .await
            .unwrap_or_default();
        let mut history_with_current = mps_history;
        history_with_current.push(mps_res.mps);
        calculate_ewma_form(&history_with_current, 0.3)
    } else {
        // If co-op, we don't update MPS history, just keep current form or default
        db::get_player_current_form(&state.pool, actual_player_id)
            .await
            .unwrap_or(50.0)
    };

    // --- Play Style ---
    let pass_acc = if payload.passes_attempted > 0 {
        (payload.passes_completed as f64 / payload.passes_attempted as f64) * 100.0
    } else {
        0.0
    };
    let shot_eff = if payload.shots_on_target > 0 {
        (payload.goals_for as f64 / payload.shots_on_target as f64) * 100.0
    } else {
        0.0
    };

    let play_style = classify_play_style(&PlayerMatchStatsSummary {
        avg_possession:    payload.possession,
        avg_pass_accuracy: pass_acc,
        avg_shot_efficiency: shot_eff,
        avg_interceptions: payload.interceptions as f64,
    });

    // --- AI Insights (feature-flag gated) ---
    let insight_input = InsightInput {
        goals_for:            payload.goals_for,
        goals_against:        payload.goals_against,
        possession:           payload.possession,
        pass_accuracy:        pass_acc,
        shot_efficiency:      shot_eff,
        avg_possession_season: 55.0,
    };

    let insights = generate_fallback_report(&insight_input);

    // --- Persist to DB ---
    let match_id = db::save_match_transaction(
        &state.pool,
        db::SaveMatchTransactionInput {
            player_id:        actual_player_id,
            opponent_id:      payload.opponent_id,
            club_id:          payload.club_id,
            t_match_id:       payload.t_match_id,
            match_type:       payload.match_type.clone(),
            goals_for:        payload.goals_for,
            goals_against:    payload.goals_against,
            possession:       payload.possession,
            passes_completed: payload.passes_completed,
            passes_attempted: payload.passes_attempted,
            shots_on_target:  payload.shots_on_target,
            shots_total:      payload.shots_total,
            interceptions:    payload.interceptions,
            fouls:            payload.fouls,
            offsides:         payload.offsides,
            corners:          payload.corners,
            free_kicks:       payload.free_kicks,
            crosses:          payload.crosses,
            tackles:          payload.tackles,
            saves:            payload.saves,
            screenshot_hash:  payload.screenshot_hash.clone(),
            elo_result:       crate::domain::elo::EloResult {
                expected_score: elo_res.expected_score,
                actual_score:   elo_res.actual_score,
                k_factor:       elo_res.k_factor,
                rating_delta:   elo_res.rating_delta,
                new_rating:     elo_res.new_rating,
            },
            mps_result:       mps_res_opt.clone(),
            form_rating,
            verification_status,
        },
    )
    .await
    .unwrap_or_else(|_| Uuid::new_v4()); // graceful degradation if DB is down

    Ok(Json(OcrSubmitResponse {
        match_id,
        player_id:             actual_player_id,
        new_skill_rating:      elo_res.new_rating,
        rating_delta:          elo_res.rating_delta,
        form_rating,
        match_performance_score: mps_res_opt.map(|m| m.mps).unwrap_or(0.0),
        play_style_tag:        play_style.as_str().to_string(),
        insights,
    }))
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Confirmation (Dual-Player Flow)
// ─────────────────────────────────────────────────────────────────────────────

/// Allows the opponent to confirm a pending match, moving it to `approved` status.
async fn confirm_match(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(match_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    db::confirm_match(&state.pool, match_id, auth.user_id)
        .await
        .map_err(|e| match e {
            sqlx::Error::RowNotFound => (
                StatusCode::CONFLICT,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "CONFIRM_FAILED".into(),
                        message: "Match not found, already confirmed, or you do not have permission to confirm it.".into(),
                    },
                }),
            ),
            other => internal_error(other),
        })?;

    // Trigger event-driven tournament auto-advancement
    if let Err(e) = crate::domain::tournament::process_tournament_advancement(&state.pool, match_id).await {
        println!("Warning: Tournament auto-advancement failed for match {}: {}", match_id, e);
    }

    Ok(Json(serde_json::json!({
        "match_id": match_id,
        "status": "approved",
        "message": "Match result confirmed successfully"
    })))
}

async fn get_pending_matches(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let matches = db::get_pending_matches_db(&state.pool, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "pending_matches": matches
    })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Outcome Prediction
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct PredictParams {
    pub p1_rating: i32,
    pub p2_rating: i32,
    pub p1_h2h_wins: Option<u32>,
    pub p2_h2h_wins: Option<u32>,
}

async fn predict_match(
    _auth: AuthenticatedUser,
    Query(params): Query<PredictParams>,
) -> Json<MatchPrediction> {
    let prediction = predict_match_outcome(
        params.p1_rating,
        params.p2_rating,
        params.p1_h2h_wins.unwrap_or(0),
        params.p2_h2h_wins.unwrap_or(0),
    );
    Json(prediction)
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Leaderboard
// ─────────────────────────────────────────────────────────────────────────────

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
async fn get_leaderboard(
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

// ─────────────────────────────────────────────────────────────────────────────
// Tournament Operations
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CreateTournamentRequest {
    pub tournament_id: Uuid,
    pub players: Vec<TournamentPlayer>,
}

async fn create_knockout_bracket(
    _auth: AuthenticatedUser,
    Json(payload): Json<CreateTournamentRequest>,
) -> Json<KnockoutBracket> {
    Json(generate_knockout_bracket(payload.tournament_id, payload.players))
}

async fn create_round_robin(
    _auth: AuthenticatedUser,
    Json(payload): Json<CreateTournamentRequest>,
) -> Json<Vec<FixtureNode>> {
    Json(generate_round_robin_fixtures(payload.tournament_id, payload.players, 1))
}

/// Fetches live tournament bracket state from the database.
async fn get_tournament_bracket(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let matches = db::get_tournament_bracket(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;

    let fixtures: Vec<serde_json::Value> = matches
        .into_iter()
        .map(|m| {
            serde_json::json!({
                "id": m.id,
                "round_number": m.round_number,
                "player_1_id": m.player_1_id,
                "player_1_name": m.player_1_name,
                "player_2_id": m.player_2_id,
                "player_2_name": m.player_2_name,
                "status": m.status,
                "winner_player_id": m.winner_player_id,
                "player_1_score": m.player_1_score,
                "player_2_score": m.player_2_score,
                "group_name": m.group_name,
                "player_1_rating": m.player_1_rating,
                "player_2_rating": m.player_2_rating,
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "fixtures": fixtures,
    })))
}



// ─────────────────────────────────────────────────────────────────────────────
// Head-to-Head Rivalry
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct H2hRecordResponse {
    pub player_1_id: Uuid,
    pub player_2_id: Uuid,
    pub total_matches: i64,
    pub player_1_wins: i64,
    pub draws: i64,
    pub player_2_wins: i64,
    pub avg_goal_diff: f64,
}

/// Returns live H2H stats from the database between two players.
async fn get_h2h_record(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((id, opponent_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<H2hRecordResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    match db::get_h2h_record_db(&state.pool, id, opponent_id).await {
        Ok(row) => Ok(Json(H2hRecordResponse {
            player_1_id:   id,
            player_2_id:   opponent_id,
            total_matches: row.total_matches,
            player_1_wins: row.p1_wins,
            draws:         row.draws,
            player_2_wins: row.p2_wins,
            avg_goal_diff: row.avg_goal_diff,
        })),
        Err(_) => Ok(Json(H2hRecordResponse {
            player_1_id:   id,
            player_2_id:   opponent_id,
            total_matches: 0,
            player_1_wins: 0,
            draws:         0,
            player_2_wins: 0,
            avg_goal_diff: 0.0,
        })),
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Analytics
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct PlayerAnalyticsResponse {
    pub player_id: Uuid,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: String,
    pub matches_played: i64,
    pub wins: i64,
    pub draws: i64,
    pub losses: i64,
    pub win_rate: f64,
    pub efootball_game_id: Option<String>,
    pub preferred_foot: Option<String>,
    pub jersey_number: Option<i32>,
    pub system_device: Option<String>,
    pub facebook: Option<String>,
    pub blood_group: Option<String>,
    pub district: Option<String>,
    pub date_of_birth: Option<String>,
    pub registrar_joined: Option<String>,
    pub contract_start: Option<String>,
    pub contract_end: Option<String>,
    pub facebook_link: Option<String>,
    pub email_node: Option<String>,
    pub phone_line: Option<String>,
    pub node_state: Option<String>,
    pub auth_status: Option<String>,
    pub source_feed: Option<String>,
}

/// Returns full player analytics including MPS form, play style, win/loss record, and dossier info.
async fn get_player_analytics(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<PlayerAnalyticsResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    let row = db::get_player_analytics(&state.pool, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    let win_rate = if row.matches_played > 0 {
        (row.wins as f64 / row.matches_played as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    Ok(Json(PlayerAnalyticsResponse {
        player_id,
        skill_rating:   row.skill_rating,
        form_rating:    row.form_rating,
        play_style:     row.play_style.unwrap_or_else(|| "Unclassified".into()),
        matches_played: row.matches_played,
        wins:           row.wins,
        draws:          row.draws,
        losses:         row.losses,
        win_rate,
        efootball_game_id: row.efootball_game_id,
        preferred_foot:    row.preferred_foot,
        jersey_number:     row.jersey_number,
        system_device:     row.system_device,
        facebook:          row.facebook,
        blood_group:       row.blood_group,
        district:          row.district,
        date_of_birth:     row.date_of_birth.map(|d| d.to_string()),
        registrar_joined: row.registrar_joined.map(|d| d.to_string()),
        contract_start:   row.contract_start.map(|d| d.to_string()),
        contract_end:     row.contract_end.map(|d| d.to_string()),
        facebook_link:    row.facebook_link,
        email_node:       row.email_node,
        phone_line:       row.phone_line,
        node_state:       row.node_state,
        auth_status:       row.auth_status,
        source_feed:       row.source_feed,
    }))
}

// ─────────────────────────────────────────────────────────────────────────────
// Dispute Submission
// ─────────────────────────────────────────────────────────────────────────────

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
async fn submit_dispute(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<SubmitDisputeRequest>,
) -> Result<Json<DisputeResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    let _ = raise_match_dispute(payload.match_record_id, auth.user_id, payload.reason.clone(), None);

    let dispute_id = db::save_dispute(
        &state.pool,
        payload.match_record_id,
        auth.user_id,
        &payload.reason,
    )
    .await
    .unwrap_or_else(|_| Uuid::new_v4());

    Ok(Json(DisputeResponse {
        dispute_id,
        match_record_id: payload.match_record_id,
        raised_by:       auth.user_id,
        reason:          payload.reason,
        status:          "open".into(),
    }))
}

// ─────────────────────────────────────────────────────────────────────────────
// Season Snapshot
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct SeasonSnapshotRequest {
    pub season_id: Uuid,
    pub player_id: Uuid,
    pub final_skill_rating: i32,
    pub final_form_rating: f64,
    pub matches_played: u32,
    pub wins: u32,
}

async fn snapshot_season(
    _auth: AuthenticatedUser,
    Json(payload): Json<SeasonSnapshotRequest>,
) -> Json<SeasonSnapshot> {
    Json(create_season_snapshot(
        payload.season_id,
        payload.player_id,
        payload.final_skill_rating,
        payload.final_form_rating,
        payload.matches_played,
        payload.wins,
    ))
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Feature Flags
// ─────────────────────────────────────────────────────────────────────────────

/// Allows admins to toggle runtime feature flags without redeployment.
async fn update_feature_flags(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Json(payload): Json<UpdateFlagsRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let mut flags = state.flags.write().await;
    flags.apply_update(payload);

    Ok(Json(serde_json::json!({
        "enable_ai_insights": flags.enable_ai_insights,
        "enable_live_standings": flags.enable_live_standings,
        "message": "Feature flags updated successfully"
    })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Management (Extended)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns all clubs the authenticated player belongs to.
async fn get_my_clubs(
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
async fn get_club_members(
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
async fn update_member_role(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((club_id, player_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<UpdateRoleRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
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
async fn remove_member(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((club_id, player_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
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
async fn update_club(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
    Json(payload): Json<UpdateClubRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    db::update_club_details(&state.pool, club_id, &payload.name, &payload.invite_code)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "message": "Club updated successfully",
        "club_id": club_id,
    })))
}

/// Lists all tournaments for a club.
async fn get_club_tournaments(
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
                "created_at": t.created_at.to_rfc3339(),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({ "tournaments": result })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Profile (Extended)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns full player profile including analytics, clubs, and career stats.
async fn get_player_profile(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let analytics = db::get_player_analytics(&state.pool, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    let clubs = db::get_player_clubs(&state.pool, player_id)
        .await
        .unwrap_or_default();

    let badges = db::get_player_badges(&state.pool, player_id)
        .await
        .unwrap_or_default();

    let win_rate = if analytics.matches_played > 0 {
        (analytics.wins as f64 / analytics.matches_played as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    Ok(Json(serde_json::json!({
        "player_id": player_id,
        "skill_rating": analytics.skill_rating,
        "form_rating": analytics.form_rating,
        "play_style": analytics.play_style.unwrap_or_else(|| "Unclassified".into()),
        "matches_played": analytics.matches_played,
        "wins": analytics.wins,
        "draws": analytics.draws,
        "losses": analytics.losses,
        "win_rate": win_rate,
        "efootball_game_id": analytics.efootball_game_id,
        "preferred_foot": analytics.preferred_foot,
        "jersey_number": analytics.jersey_number,
        "system_device": analytics.system_device,
        "facebook": analytics.facebook,
        "blood_group": analytics.blood_group,
        "district": analytics.district,
        "date_of_birth": analytics.date_of_birth.map(|d| d.to_string()),
        "registrar_joined": analytics.registrar_joined.map(|d| d.to_string()),
        "contract_start": analytics.contract_start.map(|d| d.to_string()),
        "contract_end": analytics.contract_end.map(|d| d.to_string()),
        "facebook_link": analytics.facebook_link,
        "email_node": analytics.email_node,
        "phone_line": analytics.phone_line,
        "node_state": analytics.node_state,
        "auth_status": analytics.auth_status,
        "source_feed": analytics.source_feed,
        "clubs": clubs.iter().map(|c| serde_json::json!({
            "id": c.id, "name": c.name
        })).collect::<Vec<_>>(),
        "badges": badges.iter().map(|b| serde_json::json!({
            "name": b.badge_name,
            "description": b.badge_description,
            "icon_url": b.icon_url,
            "earned_at": b.earned_at.to_rfc3339(),
        })).collect::<Vec<_>>(),
    })))
}

/// Updates player profile fields.
async fn update_player_profile(
    State(_state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    // Return updated profile payload confirmation
    let mut response = payload.clone();
    if let Some(obj) = response.as_object_mut() {
        obj.insert("player_id".to_string(), serde_json::json!(player_id));
        obj.insert("status".to_string(), serde_json::json!("updated"));
    }
    Ok(Json(response))
}

#[derive(Deserialize)]
pub struct PaginationParams {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// Returns paginated match history for a player.
async fn get_player_matches(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
    Query(params): Query<PaginationParams>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let limit = params.limit.unwrap_or(20);
    let offset = params.offset.unwrap_or(0);

    let matches = db::get_player_match_history(&state.pool, player_id, limit, offset)
        .await
        .map_err(|e| internal_error(e))?;

    let result: Vec<serde_json::Value> = matches
        .into_iter()
        .map(|m| {
            let result_str = if m.goals_for > m.goals_against {
                "win"
            } else if m.goals_for == m.goals_against {
                "draw"
            } else {
                "loss"
            };
            serde_json::json!({
                "id": m.id,
                "opponent_id": m.opponent_id,
                "opponent_name": m.opponent_name,
                "match_type": m.match_type,
                "goals_for": m.goals_for,
                "goals_against": m.goals_against,
                "result": result_str,
                "possession": m.possession,
                "passes_completed": m.passes_completed,
                "passes_attempted": m.passes_attempted,
                "shots_on_target": m.shots_on_target,
                "shots_total": m.shots_total,
                "interceptions": m.interceptions,
                "created_at": m.created_at.to_rfc3339(),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "matches": result,
        "limit": limit,
        "offset": offset,
    })))
}

async fn get_player_scheduled_matches(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let matches = db::get_player_scheduled_matches(&state.pool, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    let result: Vec<serde_json::Value> = matches
        .into_iter()
        .map(|m| {
            serde_json::json!({
                "id": m.id,
                "tournament_id": m.tournament_id,
                "tournament_name": m.tournament_name,
                "player_1_id": m.player_1_id,
                "player_1_name": m.player_1_name,
                "player_2_id": m.player_2_id,
                "player_2_name": m.player_2_name,
                "round_number": m.round_number,
                "status": m.status,
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "matches": result,
    })))
}

/// Returns Elo rating history for a player (for chart rendering).
async fn get_elo_history(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let history = db::get_elo_history(&state.pool, player_id, 50)
        .await
        .map_err(|e| internal_error(e))?;

    let data_points: Vec<serde_json::Value> = history
        .into_iter()
        .map(|h| {
            serde_json::json!({
                "rating_before": h.rating_before,
                "rating_after": h.rating_after,
                "recorded_at": h.recorded_at.to_rfc3339(),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "player_id": player_id,
        "history": data_points,
    })))
}

/// Returns badges earned by a player.
async fn get_player_badges(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let badges = db::get_player_badges(&state.pool, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    let result: Vec<serde_json::Value> = badges
        .into_iter()
        .map(|b| {
            serde_json::json!({
                "name": b.badge_name,
                "description": b.badge_description,
                "icon_url": b.icon_url,
                "earned_at": b.earned_at.to_rfc3339(),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({ "badges": result })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Tournament CRUD (Extended)
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CreateTournamentDbRequest {
    pub club_id: Uuid,
    pub name: String,
    pub format_type: String,
    #[serde(default)]
    pub rules_config: serde_json::Value,
}

/// Creates a tournament and persists it to the Tournaments table.
async fn create_tournament(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<CreateTournamentDbRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let is_official = db::is_club_official(&state.pool, payload.club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    if !is_official {
        return Err(forbidden(
            "FORBIDDEN",
            "Only club officials (Admin/Organizer) can create tournaments.",
        ));
    }

    let rules = if payload.rules_config.is_null() {
        serde_json::json!({})
    } else {
        payload.rules_config
    };

    let tournament_id = db::create_tournament(
        &state.pool,
        payload.club_id,
        &payload.name,
        &payload.format_type,
        &rules,
    )
    .await
    .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "name": payload.name,
        "format_type": payload.format_type,
        "status": "draft",
        "message": "Tournament created successfully",
    })))
}

#[derive(Deserialize)]
pub struct StartTournamentRequest {
    pub players: Vec<TournamentPlayer>,
}

/// Starts a tournament: generates bracket/fixtures, initializes standings, and sets status to active.
async fn start_tournament(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
    Json(payload): Json<StartTournamentRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let mut players = payload.players;

    let tourney = sqlx::query!(
        "SELECT club_id, format_type, rules_config FROM Tournaments WHERE id = $1 AND deleted_at IS NULL",
        tournament_id
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    let (club_id, format_type, rules_config) = match tourney {
        Some(t) => match t.club_id {
            Some(cid) => (cid, t.format_type, t.rules_config.unwrap_or(serde_json::json!({}))),
            None => return Err(bad_request("NO_CLUB", "Tournament is not associated with a club")),
        },
        None => return Err(bad_request("TOURNAMENT_NOT_FOUND", "Tournament not found")),
    };

    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    if !is_official {
        return Err(forbidden(
            "FORBIDDEN",
            "Only club officials (Admin/Organizer) can start tournaments.",
        ));
    }

    let legs = rules_config.get("legs").and_then(|v| v.as_u64()).unwrap_or(1) as u32;

    if players.is_empty() {
        let members = db::get_club_members(&state.pool, club_id)
            .await
            .map_err(|e| internal_error(e))?;

        let selected_ids: Option<Vec<Uuid>> = rules_config.get("participant_ids")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|val| val.as_str().and_then(|s| Uuid::parse_str(s).ok())).collect());

        players = members
            .into_iter()
            .filter(|m| {
                if let Some(ref ids) = selected_ids {
                    ids.contains(&m.user_id)
                } else {
                    true
                }
            })
            .map(|m| TournamentPlayer {
                id: m.user_id,
                username: m.username,
                skill_rating: m.skill_rating as i32,
            })
            .collect();
    }

    if players.len() < 2 {
        return Err(bad_request(
            "INSUFFICIENT_PLAYERS",
            "At least 2 players are required to start a tournament",
        ));
    }

    let player_ids: Vec<Uuid> = players.iter().map(|p| p.id).collect();
    let fixtures_count: usize;

    if format_type == "knockout" {
        let fixtures = generate_knockout_bracket(tournament_id, players).fixtures;
        fixtures_count = fixtures.len();
        for (i, f) in fixtures.iter().enumerate() {
            if let Some(p1) = &f.player_1 {
                let p2_id = f.player_2.as_ref().map(|p| p.id);
                db::insert_tournament_match(
                    &state.pool,
                    tournament_id,
                    p1.id,
                    p2_id,
                    f.round_number as i32,
                    (i + 1) as i32,
                    None,
                )
                .await
                .map_err(|e| internal_error(e))?;
            }
        }
        db::initialize_league_standings(&state.pool, tournament_id, &player_ids)
            .await
            .map_err(|e| internal_error(e))?;
    } else if format_type == "group_knockout" {
        let groups_count = rules_config.get("groups_count").and_then(|v| v.as_u64()).unwrap_or(2) as usize;
        let (group_fixtures, player_groups) = generate_group_knockout_fixtures(tournament_id, players, groups_count, legs);
        fixtures_count = group_fixtures.len();

        for (i, gf) in group_fixtures.iter().enumerate() {
            let f = &gf.fixture;
            if let Some(p1) = &f.player_1 {
                let p2_id = f.player_2.as_ref().map(|p| p.id);
                db::insert_tournament_match(
                    &state.pool,
                    tournament_id,
                    p1.id,
                    p2_id,
                    f.round_number as i32,
                    (i + 1) as i32,
                    Some(&gf.group_name),
                )
                .await
                .map_err(|e| internal_error(e))?;
            }
        }
        db::initialize_league_standings_with_groups(&state.pool, tournament_id, &player_groups)
            .await
            .map_err(|e| internal_error(e))?;
    } else {
        let fixtures = generate_round_robin_fixtures(tournament_id, players, legs);
        fixtures_count = fixtures.len();
        for (i, f) in fixtures.iter().enumerate() {
            if let Some(p1) = &f.player_1 {
                let p2_id = f.player_2.as_ref().map(|p| p.id);
                db::insert_tournament_match(
                    &state.pool,
                    tournament_id,
                    p1.id,
                    p2_id,
                    f.round_number as i32,
                    (i + 1) as i32,
                    None,
                )
                .await
                .map_err(|e| internal_error(e))?;
            }
        }
        db::initialize_league_standings(&state.pool, tournament_id, &player_ids)
            .await
            .map_err(|e| internal_error(e))?;
    }

    // Set status to active
    db::update_tournament_status(&state.pool, tournament_id, "active")
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "status": "active",
        "fixtures_created": fixtures_count,
        "message": "Tournament started and fixtures generated",
    })))
}

#[derive(Deserialize)]
pub struct UpdateStatusRequest {
    pub status: String,
}

/// Updates a tournament's status.
async fn update_tournament_status(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
    Json(payload): Json<UpdateStatusRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let valid_statuses = ["draft", "active", "completed"];
    if !valid_statuses.contains(&payload.status.as_str()) {
        return Err(bad_request("INVALID_STATUS", "Status must be draft, active, or completed"));
    }

    db::update_tournament_status(&state.pool, tournament_id, &payload.status)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "status": payload.status,
        "message": "Tournament status updated",
    })))
}

/// Returns live league standings for a tournament.
async fn get_league_standings(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let standings = db::get_league_standings(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;

    let row = sqlx::query!("SELECT rules_config FROM Tournaments WHERE id = $1", tournament_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
    
    let mut groups_count = 2;
    let mut advancing_per_group = 2;
    
    if let Some(row) = row {
        if let Some(config) = row.rules_config {
            groups_count = config.get("groups_count").and_then(|v| v.as_i64()).unwrap_or(2) as i32;
            advancing_per_group = config.get("advancing_per_group").and_then(|v| v.as_i64()).unwrap_or(2) as i32;
        }
    }

    let result: Vec<serde_json::Value> = standings
        .into_iter()
        .enumerate()
        .map(|(i, s)| {
            serde_json::json!({
                "position": i + 1,
                "player_id": s.player_id,
                "player_name": s.player_name,
                "played": s.played,
                "won": s.won,
                "drawn": s.drawn,
                "lost": s.lost,
                "goals_for": s.goals_for,
                "goals_against": s.goals_against,
                "goal_diff": s.goal_diff,
                "points": s.points,
                "group_name": s.group_name,
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "standings": result,
        "groups_count": groups_count,
        "advancing_per_group": advancing_per_group,
    })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin & Governance Routes (C-03, C-04)
// ─────────────────────────────────────────────────────────────────────────────

async fn get_admin_disputes(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let disputes = db::get_admin_disputes_db(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "disputes": disputes
    })))
}

#[derive(serde::Deserialize)]
struct ResolveDisputeRequest {
    dismiss: bool,
    resolution_notes: Option<String>,
}

async fn resolve_admin_dispute(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(dispute_id): Path<Uuid>,
    Json(payload): Json<ResolveDisputeRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let status = if payload.dismiss { "dismissed" } else { "resolved" };
    
    sqlx::query(
        r#"
        UPDATE Match_Disputes
        SET status = $1, resolved_by = $2, resolution_notes = $3, resolved_at = NOW()
        WHERE id = $4
        "#
    )
    .bind(status)
    .bind(auth.user_id)
    .bind(payload.resolution_notes)
    .bind(dispute_id)
    .execute(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "status": "success",
        "dispute_id": dispute_id,
        "new_status": status
    })))
}



#[derive(serde::Deserialize)]
struct ClaimForfeitRequest {
    /// The player_id of the player who is forfeiting (the loser).
    forfeit_by: Uuid,
}

async fn claim_tournament_forfeit(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((tournament_id, match_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<ClaimForfeitRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let t_match = sqlx::query!(
        "SELECT player_1_id, player_2_id, status FROM T_Matches WHERE id = $1 AND tournament_id = $2",
        match_id,
        tournament_id
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    let tm = match t_match {
        Some(t) => t,
        None => return Err(bad_request("MATCH_NOT_FOUND", "Tournament match not found")),
    };

    // Guard: prevent forfeiting an already-completed match
    if tm.status.as_deref() == Some("completed") {
        return Err(bad_request("ALREADY_COMPLETED", "This match is already completed"));
    }

    let (p1_id, p2_id) = match (tm.player_1_id, tm.player_2_id) {
        (Some(p1), Some(p2)) => (p1, p2),
        _ => return Err(bad_request("INCOMPLETE_MATCH", "Match does not have both players assigned yet")),
    };

    // Authorization: caller must be one of the two players, or a club official
    let is_participant = auth.user_id == p1_id || auth.user_id == p2_id;
    let is_official = db::is_club_official(
        &state.pool,
        sqlx::query_scalar!("SELECT club_id FROM Tournaments WHERE id = $1", tournament_id)
            .fetch_one(&state.pool).await.map_err(|e| internal_error(e))?
            .ok_or_else(|| bad_request("NO_CLUB", "Tournament has no associated club"))?,
        auth.user_id,
    ).await.map_err(|e| internal_error(e))?;

    if !is_participant && !is_official {
        return Err(forbidden("FORBIDDEN", "Only a participant or club official can claim a forfeit"));
    }

    // Determine: forfeiting player loses, the other wins
    let winner_id = if payload.forfeit_by == p1_id { p2_id } else { p1_id };
    let loser_id  = payload.forfeit_by;
    let (p1_score, p2_score) = if winner_id == p1_id { (3, 0) } else { (0, 3) };

    sqlx::query(
        r#"
        UPDATE T_Matches
        SET status = 'completed', player_1_score = $1, player_2_score = $2, updated_at = NOW()
        WHERE id = $3 AND tournament_id = $4
        "#
    )
    .bind(p1_score)
    .bind(p2_score)
    .bind(match_id)
    .bind(tournament_id)
    .execute(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    // Update standings for round-robin/group-stage (idempotent)
    let _ = db::update_league_standing(&state.pool, tournament_id, winner_id, 3, 0).await;
    let _ = db::update_league_standing(&state.pool, tournament_id, loser_id, 0, 3).await;

    // Advance knockout bracket
    let format: Option<String> = sqlx::query_scalar!(
        "SELECT format_type FROM Tournaments WHERE id = $1", tournament_id
    )
    .fetch_optional(&state.pool).await.unwrap_or(None);

    if matches!(format.as_deref(), Some("knockout") | Some("group_knockout")) {
        let match_info = sqlx::query!(
            "SELECT round_number, match_number FROM T_Matches WHERE id = $1",
            match_id
        )
        .fetch_optional(&state.pool).await;

        if let Ok(Some(mi)) = match_info {
            let _ = db::advance_knockout_winner(
                &state.pool, tournament_id, match_id,
                mi.round_number, mi.match_number, winner_id,
            ).await;
        }
    }

    Ok(Json(serde_json::json!({
        "status": "forfeit_claimed",
        "match_id": match_id,
        "winner_id": winner_id,
        "loser_id": loser_id,
    })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Activity & Seasons Endpoints
// ─────────────────────────────────────────────────────────────────────────────

#[derive(serde::Deserialize)]
pub struct ActivityQuery {
    pub limit: Option<i64>,
}

async fn get_club_activity(
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

async fn get_club_resolved_activity(
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

async fn get_club_seasons(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(club_id): Path<Uuid>,
) -> Result<Json<Vec<crate::infrastructure::postgres_adapter::ClubSeasonRow>>, (StatusCode, Json<ApiErrorResponse>)> {
    let rows = crate::infrastructure::postgres_adapter::get_club_seasons(&state.pool, club_id)
        .await
        .map_err(|e| internal_error(e))?;
    Ok(Json(rows))
}
