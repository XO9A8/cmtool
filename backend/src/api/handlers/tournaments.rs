use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::{header, StatusCode},
    response::IntoResponse,
    Json,
};
use serde::Deserialize;
use sqlx::{FromRow, Row};
use uuid::Uuid;

use crate::{
    api::{
        auth_middleware::AuthenticatedUser,
        error::{bad_request, forbidden, internal_error, ApiErrorResponse},
    },
    domain::tournament::{
        generate_group_knockout_fixtures, generate_knockout_bracket, generate_round_robin_fixtures,
        TournamentPlayer,
    },
    infrastructure::postgres_adapter as db,
    AppState,
};

/// Fetches live tournament bracket state from the database.
pub async fn get_tournament_bracket(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let matches = db::get_tournament_bracket(&state.pool, tournament_id, None)
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
                "player_1_avatar": m.player_1_avatar,
                "player_2_avatar": m.player_2_avatar,
                "matchday_id": m.matchday_id,
                "matchday_number": m.matchday_number,
                "matchday_scheduled_date": m.matchday_scheduled_date,
                "scheduled_at": m.scheduled_at,
                "original_scheduled_at": m.original_scheduled_at,
                "is_rescheduled": m.is_rescheduled,
                "reschedule_reason": m.reschedule_reason,
                "reschedule_count": m.reschedule_count,
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "fixtures": fixtures,
    })))
}

#[derive(Deserialize)]
pub struct CreateTournamentDbRequest {
    pub club_id: Uuid,
    pub name: String,
    pub format_type: String,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub matchday_gap_days: Option<i16>,
    pub allow_multi_match_per_matchday: Option<bool>,
    #[serde(default)]
    pub rules_config: serde_json::Value,
}

/// Creates a tournament and persists it to the Tournaments table.
pub async fn create_tournament(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Json(payload): Json<CreateTournamentDbRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let valid_formats = ["knockout", "round_robin", "group_knockout", "league"];
    if !valid_formats.contains(&payload.format_type.as_str()) {
        return Err(bad_request("INVALID_FORMAT", "format_type must be knockout, round_robin, or group_knockout"));
    }

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

    let start_date = payload.start_date.and_then(|d| chrono::NaiveDate::parse_from_str(&d, "%Y-%m-%d").ok());
    let end_date = payload.end_date.and_then(|d| chrono::NaiveDate::parse_from_str(&d, "%Y-%m-%d").ok());

    let tournament_id = db::create_tournament(
        &state.pool,
        payload.club_id,
        &payload.name,
        &payload.format_type,
        &rules,
        start_date,
        end_date,
        payload.matchday_gap_days,
        payload.allow_multi_match_per_matchday,
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

/// Deletes a tournament (club owners only).
pub async fn delete_tournament(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_id = db::get_tournament_club_id(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?
        .ok_or_else(|| bad_request("NOT_FOUND", "Tournament not found"))?;

    let is_owner = db::is_club_owner(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    
    if !is_owner {
        return Err(forbidden(
            "FORBIDDEN",
            "Only the club owner can delete a tournament.",
        ));
    }

    db::delete_tournament(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Tournament deleted successfully"
    })))
}

#[derive(Deserialize)]
pub struct UpdateTournamentSettingsRequest {
    pub matchday_gap_days: Option<i16>,
    pub end_date: Option<String>, // "YYYY-MM-DD" or "null" to clear
    pub allow_multi_match_per_matchday: Option<bool>,
}

/// Updates tournament settings post-creation.
pub async fn update_tournament_settings(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
    Json(payload): Json<UpdateTournamentSettingsRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_id = db::get_tournament_club_id(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?
        .ok_or_else(|| bad_request("NOT_FOUND", "Tournament not found"))?;

    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    if !is_official {
        return Err(forbidden(
            "FORBIDDEN",
            "Only club officials can update tournament settings.",
        ));
    }

    let end_date = payload.end_date.map(|d| {
        if d.is_empty() || d == "null" {
            None
        } else {
            chrono::NaiveDate::parse_from_str(&d, "%Y-%m-%d").ok()
        }
    });

    db::update_tournament_settings(
        &state.pool,
        tournament_id,
        payload.matchday_gap_days,
        end_date,
        payload.allow_multi_match_per_matchday,
    )
    .await
    .map_err(|e| internal_error(e))?;

    // If dates/gap or multi_match setting changed, rebuild remaining matchdays
    if payload.matchday_gap_days.is_some() || end_date.is_some() || payload.allow_multi_match_per_matchday.is_some() {
        let settings = db::get_tournament_settings(&state.pool, tournament_id)
            .await
            .map_err(|e| internal_error(e))?;
            
        if let Some((_, end_d, gap, allow_multi_match)) = settings {
            db::rebuild_remaining_matchdays(
                &state.pool,
                tournament_id,
                end_d,
                gap,
                allow_multi_match,
            )
            .await
            .map_err(|e| internal_error(e))?;
        }
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Tournament settings updated"
    })))
}

#[derive(Deserialize)]
pub struct StartTournamentRequest {
    pub players: Vec<TournamentPlayer>,
}

/// Starts a tournament: generates bracket/fixtures, initializes standings, and sets status to active.
pub async fn start_tournament(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
    Json(payload): Json<StartTournamentRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let mut players = payload.players;

    let tourney = sqlx::query(
        "SELECT club_id, format_type, rules_config, status, start_date, end_date, matchday_gap_days, allow_multi_match_per_matchday FROM Tournaments WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(tournament_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    let (club_id, format_type, rules_config, status, start_date, end_date, gap_days, allow_multi_match) = match tourney {
        Some(t) => (
            t.try_get::<Uuid, _>("club_id").unwrap(),
            t.try_get::<String, _>("format_type").unwrap(),
            t.try_get::<serde_json::Value, _>("rules_config").unwrap(),
            t.try_get::<String, _>("status").unwrap(),
            t.try_get::<Option<chrono::NaiveDate>, _>("start_date").unwrap_or(None),
            t.try_get::<Option<chrono::NaiveDate>, _>("end_date").unwrap_or(None),
            t.try_get::<i16, _>("matchday_gap_days").unwrap_or(7),
            t.try_get::<bool, _>("allow_multi_match_per_matchday").unwrap_or(false)
        ),
        None => return Err(bad_request("TOURNAMENT_NOT_FOUND", "Tournament not found")),
    };

    let calculate_matchdays_and_mapping = |max_round: usize| -> (usize, Vec<usize>) {
        if allow_multi_match {
            let num_mds = match (start_date, end_date) {
                (Some(s), Some(e)) => {
                    let total_days = (e - s).num_days();
                    if total_days >= 0 {
                        (total_days / (gap_days as i64) + 1) as usize
                    } else {
                        1
                    }
                }
                _ => max_round,
            };
            let num_matchdays = std::cmp::max(1, std::cmp::min(num_mds, max_round));
            let packing = crate::domain::tournament::pack_rounds_into_matchdays(max_round, num_matchdays);
            let mut mapping = vec![0; max_round + 1];
            for (md_idx, rounds) in packing.into_iter().enumerate() {
                for r in rounds {
                    if (r as usize) < mapping.len() {
                        mapping[r as usize] = md_idx;
                    }
                }
            }
            (num_matchdays, mapping)
        } else {
            let mut mapping = vec![0; max_round + 1];
            for i in 1..=max_round {
                mapping[i] = i - 1;
            }
            (max_round, mapping)
        }
    };

    if status.as_str() != "draft" {
        return Err(bad_request("INVALID_STATUS", "Only draft tournaments can be started."));
    }

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

    // Clean up any partially generated fixtures/participants from a previous failed start attempt
    let mut tx = state.pool.begin().await.map_err(|e| internal_error(e))?;

    sqlx::query("DELETE FROM T_Matches WHERE tournament_id = $1")
        .bind(tournament_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| internal_error(e))?;
    
    sqlx::query("DELETE FROM Matchdays WHERE tournament_id = $1")
        .bind(tournament_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| internal_error(e))?;
    
    sqlx::query("DELETE FROM League_Standings WHERE tournament_id = $1")
        .bind(tournament_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| internal_error(e))?;

    sqlx::query("DELETE FROM Tournament_Participants WHERE tournament_id = $1")
        .bind(tournament_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| internal_error(e))?;

    tx.commit().await.map_err(|e| internal_error(e))?;

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
        let bracket = generate_knockout_bracket(tournament_id, players);
        let fixtures = bracket.fixtures;
        fixtures_count = fixtures.len();
        
        let max_round = bracket.total_rounds;
        let (num_matchdays, round_mapping) = calculate_matchdays_and_mapping(max_round as usize);
        let matchday_dates = crate::domain::tournament::distribute_matchday_dates(start_date, end_date, num_matchdays, Some(gap_days as i64));
        let matchdays_data: Vec<(i32, Option<chrono::NaiveDate>)> = (1..=num_matchdays as i32).zip(matchday_dates).collect();
        let matchday_ids = db::create_matchdays_batch(&state.pool, tournament_id, &matchdays_data).await.map_err(|e| internal_error(e))?;
        
        let matchdays_data: Vec<(i32, Option<chrono::NaiveDate>, Uuid)> = matchdays_data.into_iter().zip(matchday_ids.clone()).map(|((num, d), id)| (num, d, id)).collect();

        let mut inserted_matches = Vec::new();
        for f in fixtures.iter() {
            let p1_id = f.player_1.as_ref().map(|p| p.id);
            let p2_id = f.player_2.as_ref().map(|p| p.id);
            let md_idx = round_mapping.get(f.round_number as usize).copied().unwrap_or(0);
            let md_id = matchday_ids.get(md_idx).copied();
            let scheduled_at = md_id
                .and_then(|id| matchdays_data.iter().find(|(_, _, mdid)| Some(*mdid) == Some(id)))
                .and_then(|(_, d, _)| *d)
                .map(|d| d.and_hms_opt(12, 0, 0).unwrap().and_utc());
            
            let inserted_match_id = db::insert_tournament_match(
                &state.pool,
                tournament_id,
                p1_id,
                p2_id,
                f.round_number as i32,
                f.match_number as i32,
                None,
                md_id,
                scheduled_at,
            )
            .await
            .map_err(|e| internal_error(e))?;

            inserted_matches.push((inserted_match_id, f));
        }

        // Advance byes only AFTER all round 1 matches are in the database
        for (inserted_match_id, f) in inserted_matches {
            if let Some(winner_id) = f.winner_id {
                sqlx::query("UPDATE T_Matches SET status = 'completed', player_1_score = 0, player_2_score = 0 WHERE id = $1")
                    .bind(inserted_match_id)
                    .execute(&state.pool)
                    .await
                    .map_err(|e| internal_error(e))?;
                
                db::advance_knockout_winner(
                    &state.pool,
                    tournament_id,
                    inserted_match_id,
                    f.round_number as i32,
                    f.match_number as i32,
                    winner_id,
                )
                .await
                .map_err(|e| internal_error(e))?;
            }
        }

    } else if format_type == "group_knockout" {
        let groups_count = rules_config.get("groups_count").and_then(|v| v.as_u64()).unwrap_or(2) as usize;
        let (group_fixtures, player_groups) = generate_group_knockout_fixtures(tournament_id, players, groups_count, legs);
        fixtures_count = group_fixtures.len();

        let max_round = group_fixtures.iter().map(|gf| gf.fixture.round_number).max().unwrap_or(0);
        let (num_matchdays, round_mapping) = calculate_matchdays_and_mapping(max_round as usize);
        let matchday_dates = crate::domain::tournament::distribute_matchday_dates(start_date, end_date, num_matchdays, Some(gap_days as i64));
        let matchdays_data: Vec<(i32, Option<chrono::NaiveDate>)> = (1..=num_matchdays as i32).zip(matchday_dates).collect();
        let matchday_ids = db::create_matchdays_batch(&state.pool, tournament_id, &matchdays_data).await.map_err(|e| internal_error(e))?;
        
        let matchdays_data: Vec<(i32, Option<chrono::NaiveDate>, Uuid)> = matchdays_data.into_iter().zip(matchday_ids.clone()).map(|((num, d), id)| (num, d, id)).collect();

        for gf in group_fixtures.iter() {
            let f = &gf.fixture;
            let p1_id = f.player_1.as_ref().map(|p| p.id);
            let p2_id = f.player_2.as_ref().map(|p| p.id);
            let md_idx = round_mapping.get(f.round_number as usize).copied().unwrap_or(0);
            let md_id = matchday_ids.get(md_idx).copied();
            let scheduled_at = md_id
                .and_then(|id| matchdays_data.iter().find(|(_, _, mdid)| Some(*mdid) == Some(id)))
                .and_then(|(_, d, _)| *d)
                .map(|d| d.and_hms_opt(12, 0, 0).unwrap().and_utc());
                
            db::insert_tournament_match(
                &state.pool,
                tournament_id,
                p1_id,
                p2_id,
                f.round_number as i32,
                f.match_number as i32,
                Some(&gf.group_name),
                md_id,
                scheduled_at,
            )
            .await
            .map_err(|e| internal_error(e))?;
        }
        db::initialize_league_standings_with_groups(&state.pool, tournament_id, &player_groups)
            .await
            .map_err(|e| internal_error(e))?;
    } else if format_type == "round_robin" || format_type == "league" {
        tracing::info!("Generating round robin fixtures for {} players with {} legs", players.len(), legs);
        let fixtures = generate_round_robin_fixtures(tournament_id, players, legs);
        fixtures_count = fixtures.len();
        tracing::info!("Generated {} fixtures in memory", fixtures_count);
        
        let max_round = fixtures.iter().map(|f| f.round_number).max().unwrap_or(0);
        tracing::info!("Max round is {}", max_round);
        let (num_matchdays, round_mapping) = calculate_matchdays_and_mapping(max_round as usize);
        let matchday_dates = crate::domain::tournament::distribute_matchday_dates(start_date, end_date, num_matchdays, Some(gap_days as i64));
        let matchdays_data: Vec<(i32, Option<chrono::NaiveDate>)> = (1..=num_matchdays as i32).zip(matchday_dates).collect();
        tracing::info!("Creating {} matchdays", matchdays_data.len());
        let matchday_ids = db::create_matchdays_batch(&state.pool, tournament_id, &matchdays_data).await.map_err(|e| {
            tracing::error!("Failed to create matchdays: {:?}", e);
            internal_error(e)
        })?;
        
        let matchdays_data: Vec<(i32, Option<chrono::NaiveDate>, Uuid)> = matchdays_data.into_iter().zip(matchday_ids.clone()).map(|((num, d), id)| (num, d, id)).collect();

        tracing::info!("Starting to insert {} matches into DB (BULK INSERT)...", fixtures.len());
        
        let batch_matches: Vec<_> = fixtures.iter().map(|f| {
            let p1_id = f.player_1.as_ref().map(|p| p.id);
            let p2_id = f.player_2.as_ref().map(|p| p.id);
            let md_idx = round_mapping.get(f.round_number as usize).copied().unwrap_or(0);
            let md_id = matchday_ids.get(md_idx).copied();
            
            let scheduled_at = md_id
                .and_then(|id| matchdays_data.iter().find(|(_, _, mdid)| Some(*mdid) == Some(id)))
                .and_then(|(_, d, _)| *d)
                .map(|d| d.and_hms_opt(12, 0, 0).unwrap().and_utc());
                
            (p1_id, p2_id, f.round_number as i32, f.match_number as i32, None, md_id, scheduled_at)
        }).collect();

        db::insert_tournament_matches_batch(&state.pool, tournament_id, &batch_matches)
            .await
            .map_err(|e| {
                tracing::error!("Failed to bulk insert matches: {:?}", e);
                internal_error(e)
            })?;
            
        tracing::info!("Successfully inserted {} matches", fixtures.len());
        db::initialize_league_standings(&state.pool, tournament_id, &player_ids)
            .await
            .map_err(|e| {
                tracing::error!("Failed to initialize league standings: {:?}", e);
                internal_error(e)
            })?;
        tracing::info!("Initialized league standings");
    } else {
        return Err(bad_request("INVALID_FORMAT", "Unsupported tournament format."));
    }

    db::insert_tournament_participants(&state.pool, tournament_id, &player_ids)
        .await
        .map_err(|e| {
            tracing::error!("Failed to insert participants: {:?}", e);
            internal_error(e)
        })?;

    // Set status to active
    db::update_tournament_status(&state.pool, tournament_id, "active")
        .await
        .map_err(|e| internal_error(e))?;

    tracing::info!("Tournament generation complete!");
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
pub async fn update_tournament_status(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
    Json(payload): Json<UpdateStatusRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let valid_statuses = ["draft", "active", "completed"];
    if !valid_statuses.contains(&payload.status.as_str()) {
        return Err(bad_request("INVALID_STATUS", "Status must be draft, active, or completed"));
    }

    let club_id = db::get_tournament_club_id(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?
        .ok_or_else(|| bad_request("NOT_FOUND", "Tournament not found"))?;

    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id)
        .await
        .map_err(|e| internal_error(e))?;
    
    if !is_official {
        return Err(forbidden("FORBIDDEN", "Only club officials can update tournament status."));
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
pub async fn get_league_standings(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let standings = db::get_league_standings(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;

    let row: Option<serde_json::Value> = sqlx::query_scalar("SELECT rules_config FROM Tournaments WHERE id = $1")
        .bind(tournament_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
    
    let mut groups_count = 2;
    let mut advancing_per_group = 2;
    
    if let Some(config) = row {
        groups_count = config.get("groups_count").and_then(|v| v.as_i64()).unwrap_or(2) as i32;
        advancing_per_group = config.get("advancing_per_group").and_then(|v| v.as_i64()).unwrap_or(2) as i32;
    }

    let mut group_positions: std::collections::HashMap<String, usize> = std::collections::HashMap::new();

    let result: Vec<serde_json::Value> = standings
        .into_iter()
        .map(|s| {
            let group_key = s.group_name.clone().unwrap_or_else(|| "".to_string());
            let pos = group_positions.entry(group_key).or_insert(1);
            let current_pos = *pos;
            *pos += 1;

            serde_json::json!({
                "position": current_pos,
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

/// Returns aggregated player statistics and top leaders for a tournament.
pub async fn get_tournament_player_stats(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let player_stats = db::get_tournament_player_stats(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({
        "tournament_id": tournament_id,
        "player_stats": player_stats,
    })))
}

#[derive(Deserialize)]
pub struct ClaimForfeitRequest {
    /// The player_id of the player who is forfeiting (the loser).
    pub forfeit_by: Uuid,
}

pub async fn claim_tournament_forfeit(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((tournament_id, match_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<ClaimForfeitRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    #[derive(FromRow)]
    struct TMatchForfeitRow {
        player_1_id: Option<Uuid>,
        player_2_id: Option<Uuid>,
        status: String,
    }

    let t_match = sqlx::query_as::<_, TMatchForfeitRow>(
        "SELECT player_1_id, player_2_id, status FROM T_Matches WHERE id = $1 AND tournament_id = $2",
    )
    .bind(match_id)
    .bind(tournament_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    let tm = match t_match {
        Some(t) => t,
        None => return Err(bad_request("MATCH_NOT_FOUND", "Tournament match not found")),
    };

    // Guard: prevent forfeiting an already-completed match
    if tm.status == "completed" {
        return Err(bad_request("ALREADY_COMPLETED", "This match is already completed"));
    }

    let (p1_id, p2_id) = match (tm.player_1_id, tm.player_2_id) {
        (Some(p1), Some(p2)) => (p1, p2),
        _ => return Err(bad_request("INCOMPLETE_MATCH", "Match does not have both players assigned yet")),
    };

    // Authorization: caller must be one of the two players, or a club official
    let is_participant = auth.user_id == p1_id || auth.user_id == p2_id;
    let club_id: Uuid = sqlx::query_scalar("SELECT club_id FROM Tournaments WHERE id = $1")
        .bind(tournament_id)
        .fetch_one(&state.pool).await.map_err(|e| internal_error(e))?;
    let is_official = db::is_club_official(
        &state.pool,
        club_id,
        auth.user_id,
    ).await.map_err(|e| internal_error(e))?;

    if !is_participant && !is_official {
        return Err(forbidden("FORBIDDEN", "Only a participant or club official can claim a forfeit"));
    }

    if payload.forfeit_by != p1_id && payload.forfeit_by != p2_id {
        return Err(bad_request("INVALID_FORFEIT", "forfeit_by must be one of the match participants"));
    }

    // Determine: forfeiting player loses, the other wins
    let winner_id = if payload.forfeit_by == p1_id { p2_id } else { p1_id };
    let loser_id  = payload.forfeit_by;

    let new_m_id = Uuid::new_v4();
    let hash_str = format!("forfeit_{}", new_m_id);

    sqlx::query(
        r#"
        INSERT INTO Match_Records (
            id, club_id, t_match_id, player_id, opponent_id, goals_for, goals_against,
            result, possession, passes_completed, passes_attempted,
            shots_on_target, shots_total, interceptions, screenshot_hash,
            verification_status, verified_by_id
        )
        VALUES ($1, $2, $3, $4, $5, 3, 0, 'win', 50.0, 0, 0, 0, 0, 0, $6, 'approved', $7)
        "#
    )
    .bind(new_m_id)
    .bind(club_id)
    .bind(match_id)
    .bind(winner_id)
    .bind(loser_id)
    .bind(hash_str)
    .bind(auth.user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| internal_error(e))?;

    // Apply match stats (Elo updates)
    if let Err(e) = db::apply_match_stats(&state.pool, new_m_id).await {
        println!("[forfeit] Error applying match stats: {}", e);
    }

    // This handles updating T_Matches status/scores, League Standings, and Knockout Advancements
    if let Err(e) = crate::domain::tournament::process_tournament_advancement(&state.pool, new_m_id).await {
        println!("[forfeit] Error processing tournament advancement: {}", e);
    }

    Ok(Json(serde_json::json!({
        "status": "forfeit_claimed",
        "match_id": match_id,
        "winner_id": winner_id,
        "loser_id": loser_id,
    })))
}

pub async fn get_matchdays(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let matchdays = db::get_matchdays(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;
    Ok(Json(serde_json::json!({ "matchdays": matchdays })))
}

pub async fn get_matchday_matches(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((tournament_id, matchday_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let matchday_matches = db::get_tournament_bracket(&state.pool, tournament_id, Some(matchday_id)).await.map_err(|e| internal_error(e))?;
    Ok(Json(serde_json::json!({ "fixtures": matchday_matches })))
}

#[derive(Deserialize)]
pub struct UpdateMatchdayScheduleRequest {
    pub scheduled_date: Option<String>,
}

pub async fn update_matchday_schedule(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((tournament_id, matchday_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<UpdateMatchdayScheduleRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_id = db::get_tournament_club_id(&state.pool, tournament_id).await.map_err(|e| internal_error(e))?.ok_or_else(|| bad_request("NOT_FOUND", "Tournament not found"))?;
    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id).await.map_err(|e| internal_error(e))?;
    if !is_official { return Err(forbidden("FORBIDDEN", "Only officials can reschedule matchdays.")); }

    let new_date = payload.scheduled_date.as_ref().and_then(|d| chrono::NaiveDate::parse_from_str(&d, "%Y-%m-%d").ok());

    // Validate against tournament boundaries
    let tourney: Option<(Option<chrono::NaiveDate>, Option<chrono::NaiveDate>)> = 
        sqlx::query_as("SELECT start_date, end_date FROM Tournaments WHERE id = $1")
        .bind(tournament_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
        
    if let Some((t_start, t_end)) = tourney {
        if let Some(target_date) = new_date {
            if let Some(start) = t_start {
                if target_date < start {
                    return Err(bad_request("INVALID_DATE", "Cannot schedule matchday before tournament starts"));
                }
            }
            if let Some(end) = t_end {
                if target_date > end {
                    return Err(bad_request("INVALID_DATE", "Cannot schedule matchday after tournament ends"));
                }
            }
        }
    }

    let old_date: Option<chrono::NaiveDate> = sqlx::query_scalar("SELECT scheduled_date FROM Matchdays WHERE id = $1")
        .bind(matchday_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?
        .flatten();
    let old_value_str = old_date.map(|d| d.to_string());

    db::update_matchday_date(&state.pool, matchday_id, new_date).await.map_err(|e| internal_error(e))?;
    
    db::insert_schedule_audit(&state.pool, "matchday", matchday_id, "date_changed", old_value_str.as_deref(), payload.scheduled_date.as_deref(), None, auth.user_id)
        .await.map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({ "success": true })))
}

#[derive(Deserialize)]
pub struct RescheduleMatchRequest {
    pub scheduled_at: String,
    pub reason: Option<String>,
    pub matchday_id: Option<Uuid>,
}

pub async fn reschedule_match(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((tournament_id, match_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<RescheduleMatchRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let club_id = db::get_tournament_club_id(&state.pool, tournament_id).await.map_err(|e| internal_error(e))?.ok_or_else(|| bad_request("NOT_FOUND", "Tournament not found"))?;
    let is_official = db::is_club_official(&state.pool, club_id, auth.user_id).await.map_err(|e| internal_error(e))?;
    if !is_official { return Err(forbidden("FORBIDDEN", "Only officials can reschedule matches.")); }

    let actual_match: Option<(Uuid, Option<Uuid>, Option<Uuid>, Option<Uuid>, i32, String)> = sqlx::query_as("SELECT tournament_id, matchday_id, player_1_id, player_2_id, reschedule_count::INT4 AS reschedule_count, status FROM T_Matches WHERE id = $1")
        .bind(match_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
        
    let (actual_t_id, matchday_id, _p1_id, _p2_id, reschedule_count, status) = actual_match.ok_or_else(|| bad_request("NOT_FOUND", "Match not found"))?;
    
    if status == "completed" {
        return Err(bad_request("ALREADY_COMPLETED", "Cannot reschedule a completed match"));
    }
    
    if actual_t_id != tournament_id {
        return Err(bad_request("INVALID_MATCH", "Match does not belong to this tournament"));
    }

    let dt = chrono::DateTime::parse_from_rfc3339(&payload.scheduled_at)
        .map_err(|_| bad_request("INVALID_DATE", "Invalid scheduled_at format"))?
        .with_timezone(&chrono::Utc);
        
    let target_date = dt.naive_utc().date();

    let tourney: Option<(Option<chrono::NaiveDate>, Option<chrono::NaiveDate>, serde_json::Value)> = 
        sqlx::query_as("SELECT start_date, end_date, rules_config FROM Tournaments WHERE id = $1")
        .bind(tournament_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
        
    let (t_start, t_end, rules_config) = tourney.unwrap_or((None, None, serde_json::json!({})));
    
    // Validate against tournament boundaries
    if let Some(start) = t_start {
        if target_date < start {
            return Err(bad_request("INVALID_DATE", "Cannot schedule match before tournament starts"));
        }
    }
    if let Some(end) = t_end {
        if target_date > end {
            return Err(bad_request("INVALID_DATE", "Cannot schedule match after tournament ends"));
        }
    }
    
    // 50% allowance: Calculate default max reschedules as 50% of total matchdays
    let total_matchdays: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM Matchdays WHERE tournament_id = $1")
        .bind(tournament_id)
        .fetch_one(&state.pool)
        .await
        .unwrap_or(0);
        
    let default_allowance = if total_matchdays > 0 {
        ((total_matchdays as f64) * 0.5).ceil() as i32
    } else {
        3
    };

    let max_reschedules = rules_config.get("max_reschedules")
        .and_then(|v| v.as_i64())
        .map(|v| v as i32)
        .unwrap_or(default_allowance.max(1));
        
    if reschedule_count >= max_reschedules {
        return Err(bad_request("LIMIT_REACHED", "Maximum reschedule limit reached for this match"));
    }
    
    db::reschedule_match(&state.pool, match_id, dt, payload.reason.as_deref(), payload.matchday_id).await.map_err(|e| internal_error(e))?;
    
    // Auto-update matchday status
    if let Some(md_id) = matchday_id {
        let _ = db::update_matchday_status(&state.pool, md_id).await;
    }
    
    db::insert_schedule_audit(&state.pool, "match", match_id, "rescheduled", None, Some(&payload.scheduled_at), payload.reason.as_deref(), auth.user_id)
        .await.map_err(|e| internal_error(e))?;

    Ok(Json(serde_json::json!({ "success": true })))
}

pub async fn get_tournament_progress(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path(tournament_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ApiErrorResponse>)> {
    let progress = db::get_tournament_progress(&state.pool, tournament_id)
        .await
        .map_err(|e| internal_error(e))?;
    Ok(Json(serde_json::json!(progress)))
}

pub async fn export_matchday_fixtures(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((tournament_id, matchday_id)): Path<(Uuid, Uuid)>,
) -> Result<axum::response::Response, (StatusCode, Json<ApiErrorResponse>)> {
    let matchday_matches = db::get_tournament_bracket(&state.pool, tournament_id, Some(matchday_id)).await.map_err(|e| internal_error(e))?;
    
    let md_number = matchday_matches.first().and_then(|m| m.matchday_number).unwrap_or(0);
    
    // Fetch tournament name
    let tourney_name: String = sqlx::query_scalar("SELECT name FROM Tournaments WHERE id = $1")
        .bind(tournament_id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
    
    let pdf_bytes = crate::domain::pdf_export::generate_matchday_pdf(&tourney_name, md_number, &matchday_matches, false);
    
    let headers = [(header::CONTENT_TYPE, "application/pdf"), (header::CONTENT_DISPOSITION, "attachment; filename=\"fixtures.pdf\"")];
    Ok((headers, pdf_bytes).into_response())
}

pub async fn export_matchday_results(
    State(state): State<Arc<AppState>>,
    _auth: AuthenticatedUser,
    Path((tournament_id, matchday_id)): Path<(Uuid, Uuid)>,
) -> Result<axum::response::Response, (StatusCode, Json<ApiErrorResponse>)> {
    let matchday_matches = db::get_tournament_bracket(&state.pool, tournament_id, Some(matchday_id)).await.map_err(|e| internal_error(e))?;
    
    let md_number = matchday_matches.first().and_then(|m| m.matchday_number).unwrap_or(0);
    
    let tourney_name: String = sqlx::query_scalar("SELECT name FROM Tournaments WHERE id = $1")
        .bind(tournament_id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| internal_error(e))?;
    
    let pdf_bytes = crate::domain::pdf_export::generate_matchday_pdf(&tourney_name, md_number, &matchday_matches, true);
    
    let headers = [(header::CONTENT_TYPE, "application/pdf"), (header::CONTENT_DISPOSITION, "attachment; filename=\"results.pdf\"")];
    Ok((headers, pdf_bytes).into_response())
}

#[derive(Deserialize)]
pub struct ExportPdfQuery {
    #[serde(default)]
    pub include_results: Option<bool>,
}

pub async fn export_matchday_pdf(
    State(state): State<Arc<AppState>>,
    auth: AuthenticatedUser,
    Path((tournament_id, matchday_id)): Path<(Uuid, Uuid)>,
    Query(query): Query<ExportPdfQuery>,
) -> Result<axum::response::Response, (StatusCode, Json<ApiErrorResponse>)> {
    if query.include_results.unwrap_or(false) {
        export_matchday_results(State(state), auth, Path((tournament_id, matchday_id))).await
    } else {
        export_matchday_fixtures(State(state), auth, Path((tournament_id, matchday_id))).await
    }
}
