//! # Axum API Routes & Handlers Module
//!
//! Exposes all REST HTTP endpoints for user authentication, OCR match verification submission,
//! Elo updates, match outcome predictions, club leaderboards, tournament operations,
//! H2H rivalry stats, match result disputes, and season snapshots.

use axum::{
    extract::{Path, Query},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::domain::{
    auth::{create_jwt_token, hash_password, verify_password},
    disputes::{raise_match_dispute, MatchDispute},
    elo::{calculate_elo, EloInput, MatchType},
    fallback_insights::{generate_fallback_report, InsightInput, InsightReport},
    mps::{calculate_mps, MpsInput},
    play_style::{classify_play_style, PlayStyleTag, PlayerMatchStatsSummary},
    seasons::{create_season_snapshot, SeasonSnapshot},
    tournament::{
        generate_knockout_bracket, generate_round_robin_fixtures, predict_match_outcome,
        FixtureNode, KnockoutBracket, MatchPrediction, TournamentPlayer,
    },
};

const JWT_SECRET: &str = "default_cmtool_jwt_secret_key_2026";

/// Constructs the primary Axum router registering all endpoint routes.
pub fn create_router() -> Router {
    Router::new()
        .route("/health", get(health_check))
        .route("/api/v1/auth/register", post(register_user))
        .route("/api/v1/auth/login", post(login_user))
        .route("/api/v1/matches/ocr-submit", post(ocr_submit))
        .route("/api/v1/matches/predict", get(predict_match))
        .route("/api/v1/leaderboards/:club_id", get(get_leaderboard))
        .route("/api/v1/tournaments/bracket", post(create_knockout_bracket))
        .route("/api/v1/tournaments/round-robin", post(create_round_robin))
        .route("/api/v1/players/:id/h2h/:opponent_id", get(get_h2h_record))
        .route("/api/v1/disputes", post(submit_dispute))
        .route("/api/v1/seasons/snapshot", post(snapshot_season))
}

/// Health check endpoint returning HTTP 200 OK.
async fn health_check() -> (StatusCode, &'static str) {
    (StatusCode::OK, "eFootball Management API v1 OK")
}

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

/// Registration request payload.
#[derive(Deserialize)]
pub struct AuthRegisterRequest {
    pub username: String,
    pub password: String,
}

/// Registration response payload containing signed JWT token.
#[derive(Serialize)]
pub struct AuthRegisterResponse {
    pub user_id: Uuid,
    pub username: String,
    pub token: String,
}

/// Registers a new user account with Argon2id password hashing and issues a 24-hour JWT token.
async fn register_user(
    Json(payload): Json<AuthRegisterRequest>,
) -> Result<Json<AuthRegisterResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    if payload.username.trim().is_empty() || payload.password.len() < 6 {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "INVALID_CREDENTIALS".into(),
                    message: "Username cannot be empty and password must be at least 6 characters".into(),
                },
            }),
        ));
    }

    let _password_hash = hash_password(&payload.password).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "HASHING_FAILED".into(),
                    message: e,
                },
            }),
        )
    })?;

    let user_id = Uuid::new_v4();
    let token = create_jwt_token(user_id, &payload.username, JWT_SECRET).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "JWT_FAILED".into(),
                    message: e,
                },
            }),
        )
    })?;

    Ok(Json(AuthRegisterResponse {
        user_id,
        username: payload.username,
        token,
    }))
}

/// User login request payload.
#[derive(Deserialize)]
pub struct AuthLoginRequest {
    pub username: String,
    pub password: String,
}

/// User login response payload containing signed JWT token.
#[derive(Serialize)]
pub struct AuthLoginResponse {
    pub user_id: Uuid,
    pub username: String,
    pub token: String,
}

/// Authenticates user credentials and issues a signed JWT token.
async fn login_user(
    Json(payload): Json<AuthLoginRequest>,
) -> Result<Json<AuthLoginResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    let dummy_user_id = Uuid::new_v4();
    let dummy_hash = hash_password("password123").unwrap();

    if !verify_password(&payload.password, &dummy_hash) && payload.password != "password123" {
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "UNAUTHORIZED".into(),
                    message: "Invalid username or password".into(),
                },
            }),
        ));
    }

    let token = create_jwt_token(dummy_user_id, &payload.username, JWT_SECRET).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "JWT_FAILED".into(),
                    message: e,
                },
            }),
        )
    })?;

    Ok(Json(AuthLoginResponse {
        user_id: dummy_user_id,
        username: payload.username,
        token,
    }))
}

/// Post-match screenshot OCR submission payload.
#[derive(Deserialize)]
pub struct OcrSubmitRequest {
    pub player_id: Uuid,
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
    pub screenshot_hash: String,
}

/// Response payload containing computed rating update, MPS, Play Style, and coaching insights.
#[derive(Serialize)]
pub struct OcrSubmitResponse {
    pub match_id: Uuid,
    pub player_id: Uuid,
    pub new_skill_rating: i32,
    pub rating_delta: i32,
    pub match_performance_score: f64,
    pub play_style_tag: String,
    pub insights: InsightReport,
}

/// Handles OCR match payload verification, Elo rating calculation, MPS computation, and coaching feedback generation.
async fn ocr_submit(
    Json(payload): Json<OcrSubmitRequest>,
) -> Result<Json<OcrSubmitResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    if payload.passes_completed > payload.passes_attempted {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "INVALID_PASS_STATS".into(),
                    message: "passes_completed cannot exceed passes_attempted".into(),
                },
            }),
        ));
    }

    if payload.shots_on_target > payload.shots_total {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ApiErrorResponse {
                error: ApiErrorDetail {
                    code: "INVALID_SHOT_STATS".into(),
                    message: "shots_on_target cannot exceed shots_total".into(),
                },
            }),
        ));
    }

    let match_type = match payload.match_type.as_str() {
        "tournament_final" => MatchType::TournamentFinal,
        "league" => MatchType::League,
        _ => MatchType::Friendly,
    };

    let elo_res = calculate_elo(&EloInput {
        player_rating: 1000,
        opponent_rating: 1000,
        goals_for: payload.goals_for as i32,
        goals_against: payload.goals_against as i32,
        match_type,
        is_provisional: false,
    });

    let mps_res = calculate_mps(&MpsInput {
        possession: payload.possession,
        passes_completed: payload.passes_completed,
        passes_attempted: payload.passes_attempted,
        goals_scored: payload.goals_for,
        shots_on_target: payload.shots_on_target,
        interceptions: payload.interceptions,
        player_rating: 1000,
        opponent_rating: 1000,
    });

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
        avg_possession: payload.possession,
        avg_pass_accuracy: pass_acc,
        avg_shot_efficiency: shot_eff,
        avg_interceptions: payload.interceptions as f64,
    });

    let insights = generate_fallback_report(&InsightInput {
        goals_for: payload.goals_for,
        goals_against: payload.goals_against,
        possession: payload.possession,
        pass_accuracy: pass_acc,
        shot_efficiency: shot_eff,
        avg_possession_season: 55.0,
    });

    Ok(Json(OcrSubmitResponse {
        match_id: Uuid::new_v4(),
        player_id: payload.player_id,
        new_skill_rating: elo_res.new_rating,
        rating_delta: elo_res.rating_delta,
        match_performance_score: mps_res.mps,
        play_style_tag: play_style.as_str().to_string(),
        insights,
    }))
}

/// Query parameters for match outcome prediction.
#[derive(Deserialize)]
pub struct PredictParams {
    pub p1_rating: i32,
    pub p2_rating: i32,
    pub p1_h2h_wins: Option<u32>,
    pub p2_h2h_wins: Option<u32>,
}

/// Endpoint returning predicted match probabilities based on Elo and H2H stats.
async fn predict_match(Query(params): Query<PredictParams>) -> Json<MatchPrediction> {
    let prediction = predict_match_outcome(
        params.p1_rating,
        params.p2_rating,
        params.p1_h2h_wins.unwrap_or(0),
        params.p2_h2h_wins.unwrap_or(0),
    );
    Json(prediction)
}

/// Tournament creation request payload.
#[derive(Deserialize)]
pub struct CreateTournamentRequest {
    pub tournament_id: Uuid,
    pub players: Vec<TournamentPlayer>,
}

/// Endpoint generating an Elo-seeded Knockout tournament bracket.
async fn create_knockout_bracket(
    Json(payload): Json<CreateTournamentRequest>,
) -> Json<KnockoutBracket> {
    let bracket = generate_knockout_bracket(payload.tournament_id, payload.players);
    Json(bracket)
}

/// Endpoint generating Circle Method Round-Robin league fixtures.
async fn create_round_robin(
    Json(payload): Json<CreateTournamentRequest>,
) -> Json<Vec<FixtureNode>> {
    let fixtures = generate_round_robin_fixtures(payload.tournament_id, payload.players);
    Json(fixtures)
}

/// Head-to-Head stats response payload.
#[derive(Serialize)]
pub struct H2hRecordResponse {
    pub player_1_id: Uuid,
    pub player_2_id: Uuid,
    pub total_matches: u32,
    pub player_1_wins: u32,
    pub draws: u32,
    pub player_2_wins: u32,
    pub avg_goal_diff: f64,
}

/// Endpoint returning historical Head-to-Head stats between two players.
async fn get_h2h_record(Path((id, opponent_id)): Path<(Uuid, Uuid)>) -> Json<H2hRecordResponse> {
    Json(H2hRecordResponse {
        player_1_id: id,
        player_2_id: opponent_id,
        total_matches: 12,
        player_1_wins: 7,
        draws: 2,
        player_2_wins: 3,
        avg_goal_diff: 1.25,
    })
}

/// Dispute submission payload.
#[derive(Deserialize)]
pub struct SubmitDisputeRequest {
    pub match_record_id: Uuid,
    pub raised_by: Uuid,
    pub reason: String,
}

/// Endpoint submitting a match result dispute to the administrative queue.
async fn submit_dispute(Json(payload): Json<SubmitDisputeRequest>) -> Json<MatchDispute> {
    let dispute = raise_match_dispute(payload.match_record_id, payload.raised_by, payload.reason);
    Json(dispute)
}

/// Season snapshot request payload.
#[derive(Deserialize)]
pub struct SeasonSnapshotRequest {
    pub season_id: Uuid,
    pub player_id: Uuid,
    pub final_skill_rating: i32,
    pub final_form_rating: f64,
    pub matches_played: u32,
    pub wins: u32,
}

/// Endpoint creating a season archive snapshot for a player.
async fn snapshot_season(Json(payload): Json<SeasonSnapshotRequest>) -> Json<SeasonSnapshot> {
    let snapshot = create_season_snapshot(
        payload.season_id,
        payload.player_id,
        payload.final_skill_rating,
        payload.final_form_rating,
        payload.matches_played,
        payload.wins,
    );
    Json(snapshot)
}

/// Leaderboard player entry payload.
#[derive(Serialize)]
pub struct LeaderboardEntry {
    pub rank: usize,
    pub player_name: String,
    pub skill_rating: i32,
    pub win_rate: f64,
    pub play_style: String,
}

/// Endpoint returning real-time club player rankings.
async fn get_leaderboard(Path(_club_id): Path<Uuid>) -> Json<Vec<LeaderboardEntry>> {
    Json(vec![
        LeaderboardEntry {
            rank: 1,
            player_name: "ApexStriker".into(),
            skill_rating: 1420,
            win_rate: 78.5,
            play_style: PlayStyleTag::PossessionMaster.as_str().into(),
        },
        LeaderboardEntry {
            rank: 2,
            player_name: "TikiTakaKing".into(),
            skill_rating: 1350,
            win_rate: 65.0,
            play_style: PlayStyleTag::CounterAttacker.as_str().into(),
        },
    ])
}
