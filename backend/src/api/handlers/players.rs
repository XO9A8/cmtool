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
        error::{forbidden, internal_error, ApiErrorResponse},
    },
    domain::tournament::MatchPrediction,
    infrastructure::postgres_adapter as db,
    AppState,
};

#[derive(Deserialize, Debug, Default)]
pub struct H2hQuery {
    pub limit: Option<i64>,
    pub scope: Option<String>,
}

#[derive(Serialize)]
pub struct H2hRecordResponse {
    pub player_1_id: Uuid,
    pub player_1_name: String,
    pub player_1_avatar: Option<String>,
    pub player_1_elo: i32,
    pub player_1_stats: db::PlayerPerformanceStats,
    pub player_2_id: Uuid,
    pub player_2_name: String,
    pub player_2_avatar: Option<String>,
    pub player_2_elo: i32,
    pub player_2_stats: db::PlayerPerformanceStats,
    pub elo_delta: i32,
    pub total_matches: i64,
    pub player_1_wins: i64,
    pub draws: i64,
    pub player_2_wins: i64,
    pub player_1_goals: i64,
    pub player_2_goals: i64,
    pub avg_goal_diff: f64,
    pub recent_matches: Vec<db::H2hRecentMatch>,
    pub player_1_overall_matches: i64,
    pub player_1_overall_wins: i64,
    pub player_1_overall_draws: i64,
    pub player_1_overall_losses: i64,
    pub player_1_overall_goals: i64,
    pub player_2_overall_matches: i64,
    pub player_2_overall_wins: i64,
    pub player_2_overall_draws: i64,
    pub player_2_overall_losses: i64,
    pub player_2_overall_goals: i64,
    pub scope: String,
    pub match_limit: Option<i64>,
    pub prediction: MatchPrediction,
}

/// Returns live H2H stats from the database between two players.
pub async fn get_h2h_record(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((id, opponent_id)): Path<(Uuid, Uuid)>,
    Query(query): Query<H2hQuery>,
) -> Result<Json<H2hRecordResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    match db::get_h2h_record_db(&state.pool, id, opponent_id, query.limit, query.scope.as_deref()).await {
        Ok(res) => Ok(Json(H2hRecordResponse {
            player_1_id: res.player_1_id,
            player_1_name: res.player_1_name,
            player_1_avatar: res.player_1_avatar,
            player_1_elo: res.player_1_elo,
            player_1_stats: res.player_1_stats,
            player_2_id: res.player_2_id,
            player_2_name: res.player_2_name,
            player_2_avatar: res.player_2_avatar,
            player_2_elo: res.player_2_elo,
            player_2_stats: res.player_2_stats,
            elo_delta: res.elo_delta,
            total_matches: res.total_matches,
            player_1_wins: res.player_1_wins,
            draws: res.draws,
            player_2_wins: res.player_2_wins,
            player_1_goals: res.player_1_goals,
            player_2_goals: res.player_2_goals,
            avg_goal_diff: res.avg_goal_diff,
            recent_matches: res.recent_matches,
            player_1_overall_matches: res.player_1_overall_matches,
            player_1_overall_wins: res.player_1_overall_wins,
            player_1_overall_draws: res.player_1_overall_draws,
            player_1_overall_losses: res.player_1_overall_losses,
            player_1_overall_goals: res.player_1_overall_goals,
            player_2_overall_matches: res.player_2_overall_matches,
            player_2_overall_wins: res.player_2_overall_wins,
            player_2_overall_draws: res.player_2_overall_draws,
            player_2_overall_losses: res.player_2_overall_losses,
            player_2_overall_goals: res.player_2_overall_goals,
            scope: res.scope,
            match_limit: res.match_limit,
            prediction: res.prediction,
        })),
        Err(e) => Err(internal_error(e)),
    }
}

#[derive(Serialize)]
pub struct PlayerAnalyticsResponse {
    pub player_id: Uuid,
    pub username: Option<String>,
    pub skill_rating: i32,
    pub peak_elo_rating: i32,
    pub form_rating: f64,
    pub play_style: String,
    pub matches_played: i64,
    pub wins: i64,
    pub draws: i64,
    pub losses: i64,
    pub win_rate: f64,
    pub goals_for: i64,
    pub goals_against: i64,
    pub goal_difference: i64,
    pub goals_per_match: f64,
    pub conceded_per_match: f64,
    pub clean_sheets: i64,
    pub clean_sheet_percentage: f64,
    pub passes_completed: i64,
    pub passes_attempted: i64,
    pub avg_pass_accuracy: f64,
    pub shots_on_target: i64,
    pub shots_total: i64,
    pub shot_efficiency: f64,
    pub shot_conversion: f64,
    pub avg_possession: f64,
    pub interceptions: i64,
    pub tackles: i64,
    pub fouls: i64,
    pub current_win_streak: i64,
    pub best_win_streak: i64,
    pub recent_form: Vec<String>,
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
pub async fn get_player_analytics(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<PlayerAnalyticsResponse>, (StatusCode, Json<ApiErrorResponse>)> {
    let row = db::get_player_analytics(&state.pool, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    let (recent_form, current_win_streak, best_win_streak) = db::get_player_streak_and_form(&state.pool, player_id)
        .await
        .unwrap_or_else(|_| (vec![], 0, 0));

    let win_rate = if row.matches_played > 0 {
        (row.wins as f64 / row.matches_played as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let goals_per_match = if row.matches_played > 0 {
        (row.goals_for as f64 / row.matches_played as f64 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let conceded_per_match = if row.matches_played > 0 {
        (row.goals_against as f64 / row.matches_played as f64 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let clean_sheet_percentage = if row.matches_played > 0 {
        (row.clean_sheets as f64 / row.matches_played as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let avg_pass_accuracy = if row.passes_attempted > 0 {
        (row.passes_completed as f64 / row.passes_attempted as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let shot_efficiency = if row.shots_total > 0 {
        (row.shots_on_target as f64 / row.shots_total as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let shot_conversion = if row.shots_total > 0 {
        (row.goals_for as f64 / row.shots_total as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    Ok(Json(PlayerAnalyticsResponse {
        player_id,
        username:          row.username,
        skill_rating:      row.skill_rating,
        peak_elo_rating:   row.peak_elo_rating,
        form_rating:       row.form_rating,
        play_style:        row.play_style.unwrap_or_else(|| "Unclassified".into()),
        matches_played:    row.matches_played,
        wins:              row.wins,
        draws:             row.draws,
        losses:            row.losses,
        win_rate,
        goals_for:         row.goals_for,
        goals_against:     row.goals_against,
        goal_difference:   row.goals_for - row.goals_against,
        goals_per_match,
        conceded_per_match,
        clean_sheets:      row.clean_sheets,
        clean_sheet_percentage,
        passes_completed:  row.passes_completed,
        passes_attempted:  row.passes_attempted,
        avg_pass_accuracy,
        shots_on_target:   row.shots_on_target,
        shots_total:       row.shots_total,
        shot_efficiency,
        shot_conversion,
        avg_possession:    (row.avg_possession * 10.0).round() / 10.0,
        interceptions:     row.interceptions,
        tackles:           row.tackles,
        fouls:             row.fouls,
        current_win_streak,
        best_win_streak,
        recent_form,
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

/// Returns full player profile including analytics, clubs, and career stats.
pub async fn get_player_profile(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let analytics = db::get_player_analytics(&state.pool, player_id)
        .await
        .map_err(|e| internal_error(e))?;

    let (recent_form, current_win_streak, best_win_streak) = db::get_player_streak_and_form(&state.pool, player_id)
        .await
        .unwrap_or_else(|_| (vec![], 0, 0));

    let clubs = db::get_player_clubs(&state.pool, player_id)
        .await
        .unwrap_or_default();

    let win_rate = if analytics.matches_played > 0 {
        (analytics.wins as f64 / analytics.matches_played as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let goals_per_match = if analytics.matches_played > 0 {
        (analytics.goals_for as f64 / analytics.matches_played as f64 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let conceded_per_match = if analytics.matches_played > 0 {
        (analytics.goals_against as f64 / analytics.matches_played as f64 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let clean_sheet_percentage = if analytics.matches_played > 0 {
        (analytics.clean_sheets as f64 / analytics.matches_played as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let avg_pass_accuracy = if analytics.passes_attempted > 0 {
        (analytics.passes_completed as f64 / analytics.passes_attempted as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let shot_efficiency = if analytics.shots_total > 0 {
        (analytics.shots_on_target as f64 / analytics.shots_total as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    let shot_conversion = if analytics.shots_total > 0 {
        (analytics.goals_for as f64 / analytics.shots_total as f64 * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    Ok(Json(serde_json::json!({
        "player_id": player_id,
        "username": analytics.username,
        "skill_rating": analytics.skill_rating,
        "peak_elo_rating": analytics.peak_elo_rating,
        "form_rating": analytics.form_rating,
        "play_style": analytics.play_style.unwrap_or_else(|| "Unclassified".into()),
        "matches_played": analytics.matches_played,
        "wins": analytics.wins,
        "draws": analytics.draws,
        "losses": analytics.losses,
        "win_rate": win_rate,
        "goals_for": analytics.goals_for,
        "goals_against": analytics.goals_against,
        "goal_difference": analytics.goals_for - analytics.goals_against,
        "goals_per_match": goals_per_match,
        "conceded_per_match": conceded_per_match,
        "clean_sheets": analytics.clean_sheets,
        "clean_sheet_percentage": clean_sheet_percentage,
        "passes_completed": analytics.passes_completed,
        "passes_attempted": analytics.passes_attempted,
        "avg_pass_accuracy": avg_pass_accuracy,
        "shots_on_target": analytics.shots_on_target,
        "shots_total": analytics.shots_total,
        "shot_efficiency": shot_efficiency,
        "shot_conversion": shot_conversion,
        "avg_possession": (analytics.avg_possession * 10.0).round() / 10.0,
        "interceptions": analytics.interceptions,
        "tackles": analytics.tackles,
        "fouls": analytics.fouls,
        "current_win_streak": current_win_streak,
        "best_win_streak": best_win_streak,
        "recent_form": recent_form,
        "efootball_game_id": analytics.efootball_game_id,
        "preferred_foot": analytics.preferred_foot,
        "jersey_number": analytics.jersey_number,
        "system_device": analytics.system_device,
        "facebook": analytics.facebook,
        "contact_info": {
            "blood_group": analytics.blood_group,
            "district": analytics.district,
            "date_of_birth": analytics.date_of_birth.map(|d| d.to_string()),
            "facebook_link": analytics.facebook_link,
            "email_node": analytics.email_node,
            "phone_line": analytics.phone_line
        },
        "compliance": {
            "registrar_joined": analytics.registrar_joined.map(|d| d.to_string()),
            "contract_start": analytics.contract_start.map(|d| d.to_string()),
            "contract_end": analytics.contract_end.map(|d| d.to_string()),
            "node_state": analytics.node_state,
            "auth_status": analytics.auth_status,
            "source_feed": analytics.source_feed
        },
        "clubs": clubs.iter().map(|c| serde_json::json!({
            "id": c.id, "name": c.name
        })).collect::<Vec<_>>()
    })))
}

/// Updates player profile fields.
pub async fn update_player_profile(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(player_id): Path<Uuid>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    if auth.user_id != player_id {
        return Err(forbidden("FORBIDDEN", "You can only update your own profile."));
    }
    
    db::update_player_profile(&state.pool, player_id, payload.clone())
        .await
        .map_err(|e| internal_error(e))?;

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
pub async fn get_player_matches(
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
            serde_json::json!({
                "id": m.id,
                "opponent_id": m.opponent_id,
                "opponent_name": m.opponent_name,
                "match_type": m.match_type,
                "goals_for": m.goals_for,
                "goals_against": m.goals_against,
                "result": m.result,
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

pub async fn get_player_scheduled_matches(
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
                "format_type": m.format_type,
                "player_1_id": m.player_1_id,
                "player_1_name": m.player_1_name,
                "player_1_avatar": m.player_1_avatar,
                "player_2_id": m.player_2_id,
                "player_2_name": m.player_2_name,
                "player_2_avatar": m.player_2_avatar,
                "round_number": m.round_number,
                "group_name": m.group_name,
                "status": m.status,
                "scheduled_at": m.scheduled_at.map(|t| t.to_rfc3339()),
                "original_scheduled_at": m.original_scheduled_at.map(|t| t.to_rfc3339()),
                "is_rescheduled": m.is_rescheduled.unwrap_or(false),
                "reschedule_reason": m.reschedule_reason,
                "matchday_number": m.matchday_number,
                "matchday_scheduled_date": m.matchday_scheduled_date.map(|d| d.to_string()),
                "start_date": m.start_date.map(|d| d.to_string()),
                "created_at": m.created_at.map(|t| t.to_rfc3339()),
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "matches": result,
    })))
}

/// Returns Elo rating history for a player (for chart rendering).
pub async fn get_elo_history(
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
