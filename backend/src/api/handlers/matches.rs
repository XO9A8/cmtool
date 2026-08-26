use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::{
    api::{
        auth_middleware::AuthenticatedUser,
        error::{bad_request, forbidden, internal_error, ApiErrorDetail, ApiErrorResponse},
    },
    domain::{
        elo::{calculate_elo, EloInput, MatchType},
        fallback_insights::{generate_fallback_report, InsightInput, InsightReport},
        mps::{calculate_ewma_form, calculate_mps, MpsInput},
        play_style::{classify_play_style, PlayerMatchStatsSummary},
        tournament::{predict_match_outcome_advanced, MatchPrediction},
    },
    infrastructure::postgres_adapter as db,
    AppState,
};

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
pub async fn ocr_submit(
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
    
    if payload.goals_for == payload.goals_against {
        if payload.match_type == "knockout" || payload.match_type == "tournament_final" || payload.match_type == "tournament_knockout" {
            return Err(bad_request("INVALID_KNOCKOUT_DRAW", "Knockout matches cannot end in a draw. Please resolve via extra time/penalties."));
        }
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

    let club_id = match payload.club_id {
        Some(cid) => cid,
        None => {
            let clubs = db::get_player_clubs(&state.pool, actual_player_id)
                .await
                .map_err(|e| internal_error(e))?;
            if clubs.is_empty() {
                return Err(bad_request("NO_CLUB", "Player must belong to a club to submit a match."));
            }
            clubs[0].id
        }
    };

    if actual_player_id != auth.user_id {
        let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
            .await
            .unwrap_or(false);
            
        if !is_official {
            return Err(forbidden("FORBIDDEN", "Cannot submit match results on behalf of another player unless you are a club official."));
        }
    }

    // --- T_Match Participant Check ---
    if let Some(tm_id) = payload.t_match_id {
        let t_match: Option<(Option<Uuid>, Option<Uuid>)> = sqlx::query_as("SELECT player_1_id, player_2_id FROM T_Matches WHERE id = $1")
            .bind(tm_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|e| internal_error(e))?;
        if let Some((p1, p2)) = t_match {
            if p1.is_none() || p2.is_none() {
                return Err(bad_request("TBD_SLOT", "Match not ready – TBD slot not filled yet."));
            }
            if p1 != Some(actual_player_id) && p2 != Some(actual_player_id) {
                return Err(forbidden("FORBIDDEN", "You are not a participant in this match."));
            }
            if p1 != Some(payload.opponent_id) && p2 != Some(payload.opponent_id) {
                return Err(bad_request("INVALID_OPPONENT", "The specified opponent does not match the scheduled tournament fixture."));
            }
        }

        if let Some(_) = db::check_match_already_confirmed(&state.pool, tm_id).await.map_err(|e| internal_error(e))? {
            return Err((
                StatusCode::CONFLICT,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "ALREADY_CONFIRMED_DISPUTE_REQUIRED".into(),
                        message: "Another result has already been confirmed for this match. You must dispute the existing result first before submitting a new result.".into(),
                    },
                }),
            ));
        }
    }

    // --- Opponent Match Confirmation Check ---
    let pending_match = db::find_pending_opponent_match(
        &state.pool,
        club_id,
        actual_player_id,
        payload.opponent_id,
        payload.goals_for,
        payload.goals_against,
    )
    .await
    .map_err(|e| internal_error(e))?;

    let mut auto_match_id = None;
    if let Some(opponent_match_id) = pending_match {
        let opponent_t_match_id: Option<Uuid> = sqlx::query_scalar("SELECT t_match_id FROM Match_Records WHERE id = $1")
            .bind(opponent_match_id)
            .fetch_optional(&state.pool)
            .await
            .ok()
            .flatten();

        if payload.t_match_id == opponent_t_match_id {
            auto_match_id = Some(opponent_match_id);
        }
    }

    if let Some(opponent_match_id) = auto_match_id {
        // Create a mirror match record for the current player
        let new_m_id = Uuid::new_v4();
        let hash_str = format!("mirror_{}", new_m_id);
        let res_str = if payload.goals_for > payload.goals_against { "win" } else if payload.goals_for == payload.goals_against { "draw" } else { "loss" };
        let _ = sqlx::query(
            r#"
            INSERT INTO Match_Records (
                id, club_id, t_match_id, player_id, opponent_id, goals_for, goals_against,
                result, possession, passes_completed, passes_attempted,
                shots_on_target, shots_total, interceptions, fouls, offsides,
                corners, free_kicks, crosses, tackles, saves, screenshot_hash,
                verification_status, verified_by_id, submitted_by_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, 'approved', $5, $23)
            "#
        )
        .bind(new_m_id)
        .bind(club_id)
        .bind(payload.t_match_id)
        .bind(actual_player_id)
        .bind(payload.opponent_id)
        .bind(payload.goals_for as i32)
        .bind(payload.goals_against as i32)
        .bind(res_str)
        .bind(payload.possession)
        .bind(payload.passes_completed as i32)
        .bind(payload.passes_attempted as i32)
        .bind(payload.shots_on_target as i32)
        .bind(payload.shots_total as i32)
        .bind(payload.interceptions as i32)
        .bind(payload.fouls as i32)
        .bind(payload.offsides as i32)
        .bind(payload.corners as i32)
        .bind(payload.free_kicks as i32)
        .bind(payload.crosses as i32)
        .bind(payload.tackles as i32)
        .bind(payload.saves as i32)
        .bind(hash_str.clone())
        .bind(Some(hash_str))
        .bind(auth.user_id)
        .execute(&state.pool)
        .await;

        // We found the opponent's match! Mark it as approved and apply stats.
        let _ = db::confirm_match(&state.pool, opponent_match_id, actual_player_id, false)
            .await
            .map_err(|e| internal_error(e))?;

        if payload.t_match_id.is_some() {
            let _ = crate::domain::tournament::process_tournament_advancement(&state.pool, opponent_match_id).await;
        }

        let mut final_new_rating = player_rating;
        let mut final_rating_delta = 0;
        let hist: Option<(i32, Option<i32>)> = sqlx::query_as("SELECT rating_after, rating_after - rating_before AS delta FROM Elo_History WHERE match_record_id = $1 AND player_id = $2")
            .bind(opponent_match_id)
            .bind(actual_player_id)
            .fetch_optional(&state.pool)
            .await
            .ok()
            .flatten();
        if let Some((rating_after, delta)) = hist {
            final_new_rating = rating_after;
            final_rating_delta = delta.unwrap_or(0);
        }

        let current_form = db::get_player_current_form(&state.pool, actual_player_id).await.unwrap_or(50.0);
        
        let play_style: String = sqlx::query_scalar("SELECT play_style FROM Club_Memberships WHERE player_id = $1 AND club_id = $2")
            .bind(actual_player_id)
            .bind(payload.club_id)
            .fetch_optional(&state.pool)
            .await
            .ok()
            .flatten()
            .unwrap_or_else(|| "Balanced".to_string());

        return Ok(Json(OcrSubmitResponse {
            match_id: opponent_match_id,
            player_id: actual_player_id,
            new_skill_rating: final_new_rating,
            rating_delta: final_rating_delta,
            form_rating: current_form,
            match_performance_score: 0.0,
            play_style_tag: play_style,
            insights: crate::domain::fallback_insights::InsightReport {
                summary: "Match result confirmed against opponent's submission.".to_string(),
                strengths: vec![],
                areas_for_improvement: vec![],
            },
        }));
    }

    let verification_status = "pending".to_string();

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
            club_id,
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
            screenshot_hash:  Some(payload.screenshot_hash.clone()),
            elo_result:       crate::domain::elo::EloResult {
                expected_score: elo_res.expected_score,
                actual_score:   elo_res.actual_score,
                k_factor:       elo_res.k_factor,
                rating_delta:   elo_res.rating_delta,
                new_rating:     elo_res.new_rating,
            },
            mps_result:       mps_res_opt.clone(),
            form_rating,
            verification_status:  verification_status.clone(),
            submitted_by_id:      Some(auth.user_id),
        },
    )
    .await
    .map_err(|e| internal_error(e))?;

    let final_new_rating = if verification_status == "pending" { player_rating } else { elo_res.new_rating };
    let final_rating_delta = if verification_status == "pending" { 0 } else { elo_res.rating_delta };

    Ok(Json(OcrSubmitResponse {
        match_id,
        player_id:             actual_player_id,
        new_skill_rating:      final_new_rating,
        rating_delta:          final_rating_delta,
        form_rating,
        match_performance_score: mps_res_opt.map(|m| m.mps).unwrap_or(0.0),
        play_style_tag:        play_style.as_str().to_string(),
        insights: crate::domain::fallback_insights::InsightReport {
            summary: format!("(Provisional) {}", insights.summary),
            strengths: insights.strengths,
            areas_for_improvement: insights.areas_for_improvement,
        },
    }))
}

/// Dismisses a pending match record (rejects the duplicate submission without affecting the T_Match).
pub async fn dismiss_pending_match(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(match_record_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    // First, check club_id for admin check
    let record = sqlx::query("SELECT club_id FROM Match_Records WHERE id = $1")
        .bind(match_record_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
        
    let club_id = match record {
        Some(r) => r.try_get::<Uuid, _>("club_id").unwrap_or(Uuid::nil()),
        None => return Err(bad_request("NOT_FOUND", "Match record not found")),
    };

    let is_admin = db::is_club_official(&state.pool, club_id, auth.user_id).await.unwrap_or(false);

    db::dismiss_match_record(&state.pool, match_record_id, auth.user_id, is_admin)
        .await
        .map_err(|e| match e {
            sqlx::Error::RowNotFound => (
                StatusCode::CONFLICT,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "DISMISS_FAILED".into(),
                        message: "Match record not found, not pending, or you do not have permission to dismiss it.".into(),
                    },
                }),
            ),
            other => internal_error(other),
        })?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Pending request dismissed."
    })))
}

/// Allows the opponent to confirm a pending match, moving it to `approved` status.
pub async fn confirm_match(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(match_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let match_record = sqlx::query("SELECT t_match_id, club_id FROM Match_Records WHERE id = $1")
        .bind(match_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
        
    let (t_match_id, club_id) = match match_record {
        Some(r) => (
            r.try_get::<Option<Uuid>, _>("t_match_id").unwrap_or(None),
            r.try_get::<Uuid, _>("club_id").unwrap_or(Uuid::nil())
        ),
        None => return Err(bad_request("NOT_FOUND", "Match record not found")),
    };

    if let Some(t_id) = t_match_id {
        if let Some(_) = db::check_match_already_confirmed(&state.pool, t_id).await.map_err(|e| internal_error(e))? {
            return Err((
                StatusCode::CONFLICT,
                Json(ApiErrorResponse {
                    error: ApiErrorDetail {
                        code: "ALREADY_CONFIRMED_DISPUTE_REQUIRED".into(),
                        message: "Another result has already been confirmed for this match. You must dispute the existing result first before confirming a new submission.".into(),
                    },
                }),
            ));
        }
    }

    let is_admin = db::is_club_official(&state.pool, club_id, auth.user_id).await.unwrap_or(false);

    db::confirm_match(&state.pool, match_id, auth.user_id, is_admin)
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
        "verified_by_id": auth.user_id,
        "message": "Match result confirmed successfully"
    })))
}

pub async fn get_pending_matches(
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

#[derive(Deserialize)]
pub struct PredictParams {
    pub p1_rating: i32,
    pub p2_rating: i32,
    pub p1_h2h_wins: Option<u32>,
    pub p2_h2h_wins: Option<u32>,
    pub p1_form: Option<f64>,
    pub p2_form: Option<f64>,
}

pub async fn predict_match(
    _auth: AuthenticatedUser,
    Query(params): Query<PredictParams>,
) -> Json<MatchPrediction> {
    let prediction = predict_match_outcome_advanced(
        params.p1_rating,
        params.p2_rating,
        params.p1_h2h_wins.unwrap_or(0),
        params.p2_h2h_wins.unwrap_or(0),
        params.p1_form,
        params.p2_form,
        None,
        None,
    );
    Json(prediction)
}
