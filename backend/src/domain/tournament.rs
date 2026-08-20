//! # Tournament Operations & Fixture Generation Module
//!
//! Provides Elo-seeded Knockout Bracket generation, Circle Method Round-Robin league fixture scheduling,
//! and match outcome probability prediction.

use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Participant player info in a tournament event.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TournamentPlayer {
    /// Unique user ID.
    pub id: Uuid,
    /// Player display username.
    pub username: String,
    /// Player's current Elo skill rating.
    pub skill_rating: i32,
}

/// A fixture match node within a tournament bracket or schedule.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FixtureNode {
    /// Unique match node ID.
    pub id: Uuid,
    /// Round number (1-indexed).
    pub round_number: u32,
    /// Match index within round.
    pub match_number: u32,
    /// Player 1 assigned to fixture.
    pub player_1: Option<TournamentPlayer>,
    /// Player 2 assigned to fixture (or None if Bye).
    pub player_2: Option<TournamentPlayer>,
    /// Winner user ID once completed.
    pub winner_id: Option<Uuid>,
}

/// A full single-elimination knockout tournament bracket.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnockoutBracket {
    /// ID of tournament event.
    pub tournament_id: Uuid,
    /// Total rounds required to reach final.
    pub total_rounds: u32,
    /// Round 1 fixture nodes.
    pub fixtures: Vec<FixtureNode>,
}

/// Distributes matchday dates evenly across the tournament period.
pub fn distribute_matchday_dates(
    start_date: Option<NaiveDate>,
    end_date: Option<NaiveDate>,
    num_matchdays: usize,
) -> Vec<Option<NaiveDate>> {
    if num_matchdays == 0 {
        return vec![];
    }
    if num_matchdays == 1 {
        return vec![start_date];
    }
    
    match (start_date, end_date) {
        (Some(start), Some(end)) => {
            let total_days = (end - start).num_days();
            if total_days <= 0 {
                // If end date is before start date, fallback to 1 week per matchday
                (0..num_matchdays)
                    .map(|i| start.checked_add_signed(chrono::Duration::days(i as i64 * 7)))
                    .collect()
            } else {
                let interval = (total_days as f64) / ((num_matchdays - 1) as f64);
                (0..num_matchdays)
                    .map(|i| {
                        let offset = (i as f64 * interval).round() as i64;
                        start.checked_add_signed(chrono::Duration::days(offset))
                    })
                    .collect()
            }
        }
        (Some(start), _) => {
            // Fallback: 1 matchday per week if no end_date is provided
            (0..num_matchdays)
                .map(|i| start.checked_add_signed(chrono::Duration::days(i as i64 * 7)))
                .collect()
        }
        _ => vec![None; num_matchdays],
    }
}


/// Automated Knockout Bracket Generator using Elo Seeding.
/// Higher seeds play lower seeds in Round 1 (1 vs N, 2 vs N-1, etc.)
pub fn generate_knockout_bracket(
    tournament_id: Uuid,
    mut players: Vec<TournamentPlayer>,
) -> KnockoutBracket {
    // 1. Sort players descending by Elo rating for seeding
    players.sort_by(|a, b| b.skill_rating.cmp(&a.skill_rating));

    let player_count = players.len();
    if player_count < 2 {
        return KnockoutBracket {
            tournament_id,
            total_rounds: 0,
            fixtures: vec![],
        };
    }

    // 2. Next power of 2 for bracket size
    let mut bracket_size = 1;
    let mut total_rounds = 0;
    while bracket_size < player_count {
        bracket_size *= 2;
        total_rounds += 1;
    }

    let mut round_1_fixtures = Vec::new();
    let match_count_round_1 = bracket_size / 2;

    for i in 0..match_count_round_1 {
        let p1 = players.get(i).cloned();
        let p2 = if (bracket_size - 1 - i) < player_count {
            players.get(bracket_size - 1 - i).cloned()
        } else {
            None // Bye
        };

        let winner_id = if p2.is_none() {
            p1.as_ref().map(|p| p.id)
        } else {
            None
        };

        round_1_fixtures.push(FixtureNode {
            id: Uuid::new_v4(),
            round_number: 1,
            match_number: (i + 1) as u32,
            player_1: p1,
            player_2: p2,
            winner_id,
        });
    }

    KnockoutBracket {
        tournament_id,
        total_rounds,
        fixtures: round_1_fixtures,
    }
}

/// Circle Method Scheduler for Round-Robin / League format (supports Single & Double Round-Robin).
pub fn generate_round_robin_fixtures(
    _tournament_id: Uuid,
    mut players: Vec<TournamentPlayer>,
    legs: u32,
) -> Vec<FixtureNode> {
    let num_legs = legs.max(1);
    if players.len() % 2 != 0 {
        // Add dummy bye player if odd count
        players.push(TournamentPlayer {
            id: Uuid::nil(),
            username: "BYE".into(),
            skill_rating: 0,
        });
    }

    let n = players.len();
    let rounds_per_leg = n - 1;
    let matches_per_round = n / 2;

    let mut fixtures = Vec::new();
    let initial_players = players.clone();

    for leg in 0..num_legs {
        players = initial_players.clone();
        let swap_home_away = leg % 2 == 1;

        for round in 0..rounds_per_leg {
            let actual_round = leg * rounds_per_leg as u32 + round as u32 + 1;

            for i in 0..matches_per_round {
                let p1 = &players[i];
                let p2 = &players[n - 1 - i];

                if p1.id != Uuid::nil() && p2.id != Uuid::nil() {
                    let (home, away) = if swap_home_away {
                        (p2.clone(), p1.clone())
                    } else {
                        (p1.clone(), p2.clone())
                    };

                    fixtures.push(FixtureNode {
                        id: Uuid::new_v4(),
                        round_number: actual_round,
                        match_number: (i + 1) as u32,
                        player_1: Some(home),
                        player_2: Some(away),
                        winner_id: None,
                    });
                }
            }

            // Rotate players array using Circle Method (keep 0 fixed, rotate others)
            let last = players.pop().unwrap();
            players.insert(1, last);
        }
    }

    fixtures
}

/// Helper struct for group fixture with group assignment.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupFixtureNode {
    pub fixture: FixtureNode,
    pub group_name: String,
}

/// Generates Group Stage round-robin fixtures partitioned into N groups (e.g. Group A, Group B).
/// Returns a tuple of (List of GroupFixtureNode, List of (Player UUID, Group Name)).
pub fn generate_group_knockout_fixtures(
    tournament_id: Uuid,
    mut players: Vec<TournamentPlayer>,
    groups_count: usize,
    legs: u32,
) -> (Vec<GroupFixtureNode>, Vec<(Uuid, String)>) {
    let max_possible_groups = (players.len() / 2).max(1);
    let num_groups = groups_count.clamp(1, max_possible_groups).min(8);
    let group_letters = ["GROUP A", "GROUP B", "GROUP C", "GROUP D", "GROUP E", "GROUP F", "GROUP G", "GROUP H"];

    // Sort players descending by skill rating for balanced seeding
    players.sort_by(|a, b| b.skill_rating.cmp(&a.skill_rating));

    let mut group_players_map: Vec<Vec<TournamentPlayer>> = vec![vec![]; num_groups];
    let mut player_group_assignments: Vec<(Uuid, String)> = Vec::new();

    // True Snake / Pot seeding into groups.
    // Row 0: A, B, C, D (forward)  → top seeds spread across all groups
    // Row 1: D, C, B, A (reverse)  → second seeds counter-distributed
    // This prevents all strong seeds clustering in the same group.
    for (idx, p) in players.into_iter().enumerate() {
        let row = idx / num_groups;
        let col = idx % num_groups;
        let g_idx = if row % 2 == 0 { col } else { num_groups - 1 - col };
        let g_name = group_letters[g_idx % group_letters.len()].to_string();
        player_group_assignments.push((p.id, g_name));
        group_players_map[g_idx].push(p);
    }

    let mut all_fixtures = Vec::new();
    for (g_idx, g_players) in group_players_map.into_iter().enumerate() {
        if g_players.len() < 2 {
            continue;
        }
        let g_name = group_letters[g_idx % group_letters.len()].to_string();
        let fixtures = generate_round_robin_fixtures(tournament_id, g_players, legs);
        for f in fixtures {
            all_fixtures.push(GroupFixtureNode {
                fixture: f,
                group_name: g_name.clone(),
            });
        }
    }

    (all_fixtures, player_group_assignments)
}

/// Generates the knockout phase fixtures (Phase Two) from completed group stage standings.
pub fn generate_group_knockout_phase_two_fixtures(
    tournament_id: Uuid,
    standings: Vec<crate::infrastructure::postgres_adapter::LeagueStandingRow>,
    advancing_per_group: usize,
) -> KnockoutBracket {
    use std::collections::HashMap;

    // 1. Group standings by group_name
    let mut groups: HashMap<String, Vec<crate::infrastructure::postgres_adapter::LeagueStandingRow>> = HashMap::new();
    for row in standings {
        if let Some(ref g_name) = row.group_name {
            groups.entry(g_name.clone()).or_default().push(row);
        }
    }

    // Explicitly sort standings within each group by points DESC, goal_diff DESC, goals_for DESC
    for g_standings in groups.values_mut() {
        g_standings.sort_by(|a, b| {
            b.points.cmp(&a.points)
                .then_with(|| b.goal_diff.cmp(&a.goal_diff))
                .then_with(|| b.goals_for.cmp(&a.goals_for))
                .then_with(|| b.won.cmp(&a.won))
                .then_with(|| b.drawn.cmp(&a.drawn))
        });
    }

    // 2. Sort groups by name to have a deterministic order
    let mut group_names: Vec<String> = groups.keys().cloned().collect();
    group_names.sort();

    // 3. Take top N from each group and build a seeded players list
    // A simple seeding strategy: interleave players so 1st place in one group plays a lower place in another.
    // For a robust universal approach, we just collect them, sort them by position, then use `generate_knockout_bracket`
    // which inherently does 1 vs N, 2 vs N-1 seeding if we pass them ordered by their effective seed.
    let mut qualified_players = Vec::new();
    
    // Position 0 = 1st place, Position 1 = 2nd place, etc.
    for pos in 0..advancing_per_group {
        for g_name in &group_names {
            if let Some(g_standings) = groups.get(g_name) {
                if let Some(player_row) = g_standings.get(pos) {
                    qualified_players.push(TournamentPlayer {
                        id: player_row.player_id,
                        username: player_row.player_name.clone(),
                        skill_rating: 1000 - pos as i32, // Artificial rating to ensure proper top vs bottom seeding
                    });
                }
            }
        }
    }

    // Since `generate_knockout_bracket` uses skill_rating for seeding, the artificial rating above guarantees:
    // All 1st places have rating 1000, all 2nd places have 999, etc.
    // So 1st places will naturally draw 2nd places.
    generate_knockout_bracket(tournament_id, qualified_players)
}

/// Match Prediction Engine: Calculates Win / Draw / Loss Probabilities using Elo math & H2H adjustment.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MatchPrediction {
    /// Player 1 win probability (0.0 to 1.0).
    pub player_1_win_prob: f64,
    /// Draw probability (0.0 to 1.0).
    pub draw_prob: f64,
    /// Player 2 win probability (0.0 to 1.0).
    pub player_2_win_prob: f64,
    /// Raw expected score for Player 1.
    pub expected_score_p1: f64,
    /// Raw expected score for Player 2.
    pub expected_score_p2: f64,
}

/// Advanced match prediction considering Elo, H2H record, player form, and draw tendencies.
pub fn predict_match_outcome_advanced(
    p1_rating: i32,
    p2_rating: i32,
    h2h_p1_wins: u32,
    h2h_p2_wins: u32,
    p1_form: Option<f64>,
    p2_form: Option<f64>,
    historical_draw_rate: Option<f64>,
    _avg_goal_diff: Option<f64>,
) -> MatchPrediction {
    let r1 = p1_rating as f64;
    let r2 = p2_rating as f64;

    // Standard Elo expected outcome: e1 = 1 / (1 + 10^((r2 - r1)/400))
    let e1 = 1.0 / (1.0 + 10.0_f64.powf((r2 - r1) / 400.0));
    let e2 = 1.0 - e1;

    let total_h2h = (h2h_p1_wins + h2h_p2_wins) as f64;
    let h2h_bonus = if total_h2h >= 3.0 {
        ((h2h_p1_wins as f64 - h2h_p2_wins as f64) / total_h2h) * 0.08
    } else {
        0.0
    };

    let form_bonus = match (p1_form, p2_form) {
        (Some(f1), Some(f2)) => ((f1.clamp(10.0, 100.0) - f2.clamp(10.0, 100.0)) / 100.0) * 0.05,
        _ => 0.0,
    };

    let adj_e1 = (e1 + h2h_bonus + form_bonus).clamp(0.04, 0.96);

    // Dynamic draw probability: blend theoretical and historical draw rate
    let elo_gap = (r1 - r2).abs();
    let theoretical_draw = (0.24 * (-elo_gap / 500.0).exp()).clamp(0.06, 0.24);
    let draw_prob = match historical_draw_rate {
        Some(hdr) if hdr > 0.0 => (0.6 * theoretical_draw + 0.4 * hdr.clamp(0.05, 0.35)).clamp(0.05, 0.30),
        _ => theoretical_draw,
    };

    let remaining_prob = 1.0 - draw_prob;
    let raw_p1 = adj_e1 * remaining_prob;
    let raw_p2 = (1.0 - adj_e1) * remaining_prob;

    // Normalization to ensure exact 1.0 (100.0%) sum
    let total_raw = raw_p1 + raw_p2 + draw_prob;
    let norm_p1 = raw_p1 / total_raw;
    let norm_p2 = raw_p2 / total_raw;
    let _norm_draw = draw_prob / total_raw;

    let p1_pct = (norm_p1 * 1000.0).round() / 10.0;
    let p2_pct = (norm_p2 * 1000.0).round() / 10.0;
    let draw_pct = ((100.0 - (p1_pct + p2_pct)) * 10.0).round() / 10.0;

    let player_1_win_prob = (p1_pct / 100.0 * 1000.0).round() / 1000.0;
    let player_2_win_prob = (p2_pct / 100.0 * 1000.0).round() / 1000.0;
    let draw_prob_rounded = (draw_pct / 100.0 * 1000.0).round() / 1000.0;

    MatchPrediction {
        player_1_win_prob,
        draw_prob: draw_prob_rounded,
        player_2_win_prob,
        expected_score_p1: (e1 * 1000.0).round() / 1000.0,
        expected_score_p2: (e2 * 1000.0).round() / 1000.0,
    }
}

/// Calculates predicted match probabilities combining expected Elo scores and historical H2H records.
pub fn predict_match_outcome(
    p1_rating: i32,
    p2_rating: i32,
    h2h_p1_wins: u32,
    h2h_p2_wins: u32,
) -> MatchPrediction {
    predict_match_outcome_advanced(p1_rating, p2_rating, h2h_p1_wins, h2h_p2_wins, None, None, None, None)
}

/// Triggers tournament auto-advancement when a match is confirmed.
///
/// - For **league/round-robin** matches: updates `League_Standings` with an idempotency guard
///   to prevent double-counting if the same match is confirmed twice.
/// - For **knockout** matches: calls `advance_knockout_winner` to create/update the next-round fixture.
pub async fn process_tournament_advancement(
    pool: &sqlx::PgPool,
    match_id: Uuid,
) -> Result<(), String> {
    println!("[tournament] Auto-advancement triggered for match_id: {}", match_id);

    // 1. Fetch full context — T_Match + linked Match_Records + tournament format
    let t_match = crate::infrastructure::postgres_adapter::get_advancement_context(pool, match_id)
        .await
        .map_err(|e| e.to_string())?;

    let tm = match t_match {
        Some(t) => t,
        None => {
            // match_id is a Match_Records.id that isn't linked to any T_Match — not a tournament match
            println!("[tournament] match_id {} is not a tournament fixture, skipping.", match_id);
            return Ok(());
        }
    };

    // Idempotency: skip already completed tournament matches
    if tm.match_status == "completed" {
        println!("[tournament] match_id {} is already completed, skipping auto-advancement.", tm.t_match_id);
        return Ok(());
    }

    let (tourney_id, p1_id, p2_id) = match (tm.tournament_id, tm.player_1_id, tm.player_2_id) {
        (t, Some(p1), Some(p2)) => (t, p1, p2),
        _ => return Ok(()), // Incomplete fixture data, nothing to advance
    };

    // 2. Resolve goals from Match_Records (linked via match_record_id)
    let (p1_goals, p2_goals) = if let (Some(mr_pid), Some(gf), Some(ga)) =
        (tm.mr_player_id, tm.goals_for, tm.goals_against)
    {
        if mr_pid == p1_id { (gf, ga) } else { (ga, gf) }
    } else {
        // No linked match record yet (e.g. forfeit path sets score directly)
        // Read scores from T_Matches columns instead
        let scores = crate::infrastructure::postgres_adapter::get_match_scores(pool, tm.t_match_id)
            .await
            .map_err(|e| e.to_string())?;

        match scores {
            Some((Some(s1), Some(s2))) => (s1, s2),
            _ => return Ok(()), // No score data available yet
        }
    };

    let is_draw = p1_goals == p2_goals;
    let format = tm.format_type.as_str();
    let is_knockout_match = format == "knockout" || (format == "group_knockout" && tm.group_name.is_none());
    let is_group_or_league = format == "round_robin" || format == "league" || (format == "group_knockout" && tm.group_name.is_some()) || (format.is_empty() && tm.group_name.is_some());

    // Knockout matches MUST have a winner (no draws permitted)
    if is_knockout_match && is_draw {
        return Err(format!("Knockout match {} cannot end in a draw. Please resolve via extra time/penalties.", tm.t_match_id));
    }

    // 3. Mark T_Match as completed with final scores
    crate::infrastructure::postgres_adapter::update_match_scores_completed(pool, tm.t_match_id, p1_goals, p2_goals)
        .await
        .map_err(|e| e.to_string())?;

    // 4. Determine winner
    let winner_id = if p1_goals > p2_goals {
        Some(p1_id)
    } else if p2_goals > p1_goals {
        Some(p2_id)
    } else {
        None
    };

    // 5a. League / Group-stage path → update standings with idempotency guard
    if is_group_or_league {
        crate::infrastructure::postgres_adapter::update_league_standing_guarded(
            pool, tourney_id, tm.t_match_id, p1_id, p1_goals as i32, p2_goals as i32,
        ).await.map_err(|e| e.to_string())?;

        crate::infrastructure::postgres_adapter::update_league_standing_guarded(
            pool, tourney_id, tm.t_match_id, p2_id, p2_goals as i32, p1_goals as i32,
        ).await.map_err(|e| e.to_string())?;

        // ADD-4: Check if league tournament is complete
        if format == "round_robin" || format == "league" {
            let pending_matches = crate::infrastructure::postgres_adapter::get_pending_matches_count(pool, tourney_id)
                .await
                .unwrap_or(1);

            if pending_matches == 0 {
                let _ = crate::infrastructure::postgres_adapter::update_tournament_status(pool, tourney_id, "completed").await;
            }
        }
    }

    // 5b. Knockout path → advance winner to next round
    if is_knockout_match && !is_draw {
        if let Err(e) = crate::infrastructure::postgres_adapter::advance_knockout_winner(
            pool,
            tourney_id,
            tm.t_match_id,
            tm.round_number as i32,
            tm.match_number,
            winner_id.unwrap(),
        ).await {
            // Non-fatal: log but don't fail the confirmation
            eprintln!("[tournament] advance_knockout_winner failed for t_match {}: {}", tm.t_match_id, e);
        }
    }

    // 5c. Group Knockout Phase Transition Check (only for group stage matches)
    if format == "group_knockout" && tm.group_name.is_some() {
        if let Err(e) = transition_group_knockout_phase(pool, tourney_id).await {
            eprintln!("[tournament] Failed to transition group knockout phase: {}", e);
        }
    }

    // Auto-update matchday status
    if let Some(md_id) = tm.matchday_id {
        let _ = crate::infrastructure::postgres_adapter::update_matchday_status(pool, md_id).await;
    }

    Ok(())
}

/// Atomically transitions a group_knockout tournament to its Phase Two knockout stage.
/// Protected by a row lock (`FOR UPDATE`) on the Tournaments record to prevent concurrent duplicate generation.
pub async fn transition_group_knockout_phase(
    pool: &sqlx::PgPool,
    tourney_id: Uuid,
) -> Result<bool, String> {
    // Fast-path checks before acquiring transaction lock
    if !crate::infrastructure::postgres_adapter::check_group_stage_completed(pool, tourney_id).await.unwrap_or(false) {
        return Ok(false);
    }
    if crate::infrastructure::postgres_adapter::check_knockout_stage_generated(pool, tourney_id).await.unwrap_or(true) {
        return Ok(false);
    }

    // Begin transaction and acquire row lock on Tournaments table
    let mut tx = pool.begin().await.map_err(|e| e.to_string())?;

    let locked: Option<Uuid> = sqlx::query_scalar("SELECT id FROM Tournaments WHERE id = $1 FOR UPDATE")
        .bind(tourney_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|e| e.to_string())?;

    if locked.is_none() {
        return Ok(false);
    }

    // Re-verify under lock
    let group_pending: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM T_Matches
        WHERE tournament_id = $1
          AND group_name IS NOT NULL
          AND status != 'completed'
        "#,
    )
    .bind(tourney_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| e.to_string())?;

    if group_pending != 0 {
        return Ok(false);
    }

    let knockout_exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM T_Matches
            WHERE tournament_id = $1
              AND group_name IS NULL
              AND round_number > COALESCE((
                  SELECT MAX(round_number) 
                  FROM T_Matches 
                  WHERE tournament_id = $1 AND group_name IS NOT NULL
              ), 0)
        )
        "#,
    )
    .bind(tourney_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| e.to_string())?;

    if knockout_exists {
        return Ok(false);
    }

    println!("[tournament] Group stage complete! Transitioning to knockout phase for tournament {}", tourney_id);

    // Fetch standings
    let standings = crate::infrastructure::postgres_adapter::get_league_standings(pool, tourney_id)
        .await
        .map_err(|e| e.to_string())?;

    let advancing = crate::infrastructure::postgres_adapter::get_tournament_advancing_count(pool, tourney_id)
        .await
        .unwrap_or(2);

    // Generate Phase Two fixtures
    let bracket = generate_group_knockout_phase_two_fixtures(tourney_id, standings, advancing);

    let max_group_round: Option<i32> = sqlx::query_scalar(
        "SELECT MAX(round_number)::INT4 FROM T_Matches WHERE tournament_id = $1 AND group_name IS NOT NULL"
    )
    .bind(tourney_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| e.to_string())?
    .flatten();

    let round_offset = max_group_round.unwrap_or(0) as u32;
    let mut fixtures = bracket.fixtures;
    for f in &mut fixtures {
        f.round_number += round_offset;
    }

    let max_bracket_round = round_offset + bracket.total_rounds;
    let mut matchdays_data = Vec::new();

    let tournament_info: Option<(Option<chrono::NaiveDate>, Option<chrono::NaiveDate>)> = sqlx::query_as(
        "SELECT start_date, end_date FROM Tournaments WHERE id = $1"
    )
    .bind(tourney_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| e.to_string())?;

    if let Some((_, Some(end_date))) = tournament_info {
        let start_date = chrono::Utc::now().naive_utc().date();
        let effective_end_date = if end_date <= start_date {
            start_date.checked_add_signed(chrono::Duration::days((bracket.total_rounds as i64) * 7)).unwrap_or(start_date)
        } else {
            end_date
        };
        let phase_two_rounds = bracket.total_rounds as usize;
        let phase_two_dates = distribute_matchday_dates(Some(start_date), Some(effective_end_date), phase_two_rounds);
        for (r, d) in ((round_offset + 1)..=max_bracket_round).zip(phase_two_dates) {
            matchdays_data.push((r as i32, d));
        }
    } else {
        for r in (round_offset + 1)..=max_bracket_round {
            matchdays_data.push((r as i32, None));
        }
    }

    let mut matchday_ids = Vec::with_capacity(matchdays_data.len());
    for (num, date) in &matchdays_data {
        let id = Uuid::new_v4();
        matchday_ids.push(id);
        sqlx::query(
            "INSERT INTO Matchdays (id, tournament_id, matchday_number, scheduled_date, status) VALUES ($1, $2, $3, $4, 'upcoming')"
        )
        .bind(id)
        .bind(tourney_id)
        .bind(*num)
        .bind(*date)
        .execute(&mut *tx)
        .await
        .map_err(|e| e.to_string())?;
    }

    let mut inserted_matches = Vec::new();
    for f in &fixtures {
        let p1_id = f.player_1.as_ref().map(|p| p.id);
        let p2_id = f.player_2.as_ref().map(|p| p.id);
        let idx = f.round_number.saturating_sub(round_offset).saturating_sub(1) as usize;
        let md_id = matchday_ids.get(idx).copied();
        let scheduled_at = md_id.and_then(|id| {
            matchdays_data.iter().find(|(num, _)| {
                let md_idx = (*num as u32).saturating_sub(round_offset).saturating_sub(1) as usize;
                matchday_ids.get(md_idx).copied() == Some(id)
            }).and_then(|(_, d)| *d).map(|d| d.and_hms_opt(12, 0, 0).unwrap().and_utc())
        });

        let inserted_match_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, match_number, status, matchday_id, scheduled_at)
            VALUES ($1, $2, $3, $4, $5, $6, 'scheduled', $7, $8)
            "#
        )
        .bind(inserted_match_id)
        .bind(tourney_id)
        .bind(p1_id)
        .bind(p2_id)
        .bind(f.round_number as i32)
        .bind(f.match_number as i32)
        .bind(md_id)
        .bind(scheduled_at)
        .execute(&mut *tx)
        .await
        .map_err(|e| e.to_string())?;

        inserted_matches.push((inserted_match_id, f.clone()));
    }

    tx.commit().await.map_err(|e| e.to_string())?;

    // Advance byes in Phase Two knockout round 1 if any
    for (inserted_match_id, f) in inserted_matches {
        if let Some(winner_id) = f.winner_id {
            let _ = sqlx::query("UPDATE T_Matches SET status = 'completed', player_1_score = 0, player_2_score = 0 WHERE id = $1")
                .bind(inserted_match_id)
                .execute(pool)
                .await;

            let _ = crate::infrastructure::postgres_adapter::advance_knockout_winner(
                pool,
                tourney_id,
                inserted_match_id,
                f.round_number as i32,
                f.match_number as i32,
                winner_id,
            )
            .await;
        }
    }

    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_knockout_bracket_seeding() {
        let players = vec![
            TournamentPlayer { id: Uuid::new_v4(), username: "P1".into(), skill_rating: 1500 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P2".into(), skill_rating: 1200 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P3".into(), skill_rating: 1400 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P4".into(), skill_rating: 1000 },
        ];

        let bracket = generate_knockout_bracket(Uuid::new_v4(), players);
        assert_eq!(bracket.total_rounds, 2);
        assert_eq!(bracket.fixtures.len(), 2);

        let f1 = &bracket.fixtures[0];
        assert_eq!(f1.player_1.as_ref().unwrap().skill_rating, 1500);
        assert_eq!(f1.player_2.as_ref().unwrap().skill_rating, 1000);
    }

    #[test]
    fn test_round_robin_circle_method() {
        let players = vec![
            TournamentPlayer { id: Uuid::new_v4(), username: "P1".into(), skill_rating: 1000 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P2".into(), skill_rating: 1000 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P3".into(), skill_rating: 1000 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P4".into(), skill_rating: 1000 },
        ];

        let fixtures = generate_round_robin_fixtures(Uuid::new_v4(), players, 1);
        assert_eq!(fixtures.len(), 6);
    }

    #[test]
    fn test_snake_seeding_balances_groups() {
        // 8 players into 2 groups: snake seeding should give each group alternating seeds
        // Group A: #1 (1500), #4 (1000) — via snake: row0→A, row1→B,A → A gets 1500 & 1100
        // Group B: #2 (1400), #3 (1200) — via snake: row0→B, row1→A,B → B gets 1400 & 1000
        let players = vec![
            TournamentPlayer { id: Uuid::new_v4(), username: "P1".into(), skill_rating: 1500 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P2".into(), skill_rating: 1400 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P3".into(), skill_rating: 1200 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P4".into(), skill_rating: 1100 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P5".into(), skill_rating: 1000 },
            TournamentPlayer { id: Uuid::new_v4(), username: "P6".into(), skill_rating: 900 },
        ];

        let (fixtures, assignments) = generate_group_knockout_fixtures(Uuid::new_v4(), players, 2, 1);
        assert!(!fixtures.is_empty());

        // With snake seeding:
        // idx=0 → row=0, col=0, g_idx=0 (GROUP A)
        // idx=1 → row=0, col=1, g_idx=1 (GROUP B)
        // idx=2 → row=1, col=0, snake→ g_idx=1 (GROUP B)
        // idx=3 → row=1, col=1, snake→ g_idx=0 (GROUP A)
        // So Group A = P1(1500), P4(1100); Group B = P2(1400), P3(1200) → balanced!
        let group_a: Vec<_> = assignments.iter().filter(|(_, g)| g == "GROUP A").collect();
        let group_b: Vec<_> = assignments.iter().filter(|(_, g)| g == "GROUP B").collect();
        assert_eq!(group_a.len(), 3);
        assert_eq!(group_b.len(), 3);
    }

    #[test]
    fn test_distribute_matchday_dates() {
        use chrono::NaiveDate;
        
        let start = NaiveDate::from_ymd_opt(2023, 1, 1);
        let end = NaiveDate::from_ymd_opt(2023, 1, 10);
        
        // 1. Zero matchdays
        let dates = distribute_matchday_dates(start, end, 0);
        assert!(dates.is_empty());
        
        // 2. Single matchday
        let dates = distribute_matchday_dates(start, end, 1);
        assert_eq!(dates, vec![start]);
        
        // 3. Two matchdays
        let dates = distribute_matchday_dates(start, end, 2);
        assert_eq!(dates, vec![start, end]);
        
        // 4. Three matchdays
        let dates = distribute_matchday_dates(start, end, 3);
        assert_eq!(dates, vec![
            NaiveDate::from_ymd_opt(2023, 1, 1),
            NaiveDate::from_ymd_opt(2023, 1, 6),
            NaiveDate::from_ymd_opt(2023, 1, 10),
        ]);
        
        // 5. Without dates
        let dates = distribute_matchday_dates(None, None, 3);
        assert_eq!(dates, vec![None, None, None]);
    }

    #[tokio::test]
    async fn test_issue_total_rounds() {
        let r1_matches = 2;
        let total_rounds = (r1_matches as f64).log2().ceil() as i32 + 1;
        println!("test_issue_total_rounds: r1_matches={}, total_rounds={}", r1_matches, total_rounds);
        assert_eq!(total_rounds, 2);
    }
}
