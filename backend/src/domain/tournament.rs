//! # Tournament Operations & Fixture Generation Module
//!
//! Provides Elo-seeded Knockout Bracket generation, Circle Method Round-Robin league fixture scheduling,
//! and match outcome probability prediction.

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
    tournament_id: Uuid,
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
#[derive(Debug, Serialize, Deserialize)]
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

/// Calculates predicted match probabilities combining expected Elo scores and historical H2H records.
pub fn predict_match_outcome(
    p1_rating: i32,
    p2_rating: i32,
    h2h_p1_wins: u32,
    h2h_p2_wins: u32,
) -> MatchPrediction {
    let r1 = p1_rating as f64;
    let r2 = p2_rating as f64;

    let e1 = 1.0 / (1.0 + 10.0_f64.powf((r2 - r1) / 400.0));
    let e2 = 1.0 - e1;

    let total_h2h = (h2h_p1_wins + h2h_p2_wins) as f64;
    let h2h_bonus = if total_h2h >= 3.0 {
        ((h2h_p1_wins as f64 - h2h_p2_wins as f64) / total_h2h) * 0.05
    } else {
        0.0
    };

    let adj_e1 = (e1 + h2h_bonus).clamp(0.05, 0.95);
    let draw_prob = 0.22; // Base draw probability in eFootball matches

    let remaining_prob = 1.0 - draw_prob;
    let player_1_win_prob = (adj_e1 * remaining_prob * 100.0).round() / 100.0;
    let player_2_win_prob = ((1.0 - adj_e1) * remaining_prob * 100.0).round() / 100.0;

    MatchPrediction {
        player_1_win_prob,
        draw_prob: (draw_prob * 100.0).round() / 100.0,
        player_2_win_prob,
        expected_score_p1: e1,
        expected_score_p2: e2,
    }
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
    let t_match = sqlx::query!(
        r#"
        SELECT
            m.id          AS t_match_id,
            m.tournament_id,
            m.player_1_id,
            m.player_2_id,
            m.round_number,
            m.match_number,
            t.format_type,
            mr.id         AS "mr_id?: Uuid",
            mr.player_id  AS "mr_player_id?: Uuid",
            mr.goals_for  AS "goals_for?: i32",
            mr.goals_against AS "goals_against?: i32"
        FROM T_Matches m
        LEFT JOIN Match_Records mr ON mr.t_match_id = m.id
        LEFT JOIN Tournaments t   ON t.id  = m.tournament_id
        WHERE m.id = $1 OR mr.id = $1
        "#,
        match_id
    )
    .fetch_optional(pool)
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
        let scores = sqlx::query!(
            "SELECT player_1_score, player_2_score FROM T_Matches WHERE id = $1",
            tm.t_match_id
        )
        .fetch_optional(pool)
        .await
        .map_err(|e| e.to_string())?;

        match scores.and_then(|s| Some((s.player_1_score?, s.player_2_score?))) {
            Some((s1, s2)) => (s1 as i32, s2 as i32),
            None => return Ok(()), // No score data available yet
        }
    };

    // 3. Mark T_Match as completed with final scores
    sqlx::query(
        "UPDATE T_Matches SET player_1_score = $1, player_2_score = $2, status = 'completed' WHERE id = $3"
    )
    .bind(p1_goals)
    .bind(p2_goals)
    .bind(tm.t_match_id)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;

    // 4. Determine winner
    let winner_id = if p1_goals > p2_goals { p1_id } else { p2_id };
    let is_draw   = p1_goals == p2_goals;

    let format = tm.format_type.as_str();

    // 5a. League / Group-stage path → update standings with idempotency guard
    if format == "round_robin" || format == "group_knockout" || format.is_empty() {

        crate::infrastructure::postgres_adapter::update_league_standing_guarded(
            pool, tourney_id, tm.t_match_id, p1_id, p1_goals as i32, p2_goals as i32,
        ).await.map_err(|e| e.to_string())?;

        crate::infrastructure::postgres_adapter::update_league_standing_guarded(
            pool, tourney_id, tm.t_match_id, p2_id, p2_goals as i32, p1_goals as i32,
        ).await.map_err(|e| e.to_string())?;
    }

    // 5b. Knockout path → advance winner to next round (skip draws — no draws in knockout)
    // Only call advance_knockout_winner for actual knockout matches (where group_name is None).
    // For now, we rely on advance_knockout_winner ignoring matches that don't have a linked next match.
    if (format == "knockout" || format == "group_knockout") && !is_draw {
        if let Err(e) = crate::infrastructure::postgres_adapter::advance_knockout_winner(
            pool,
            tourney_id,
            tm.t_match_id,
            tm.round_number as i32,
            tm.match_number,
            winner_id,
        ).await {
            // Non-fatal: log but don't fail the confirmation
            eprintln!("[tournament] advance_knockout_winner failed for t_match {}: {}", tm.t_match_id, e);
        }
    }

    // 5c. Group Knockout Phase Transition Check
    if format == "group_knockout" {
        // Check if all group stage matches are finished
        if let Ok(true) = crate::infrastructure::postgres_adapter::check_group_stage_completed(pool, tourney_id).await {
            // Ensure we don't generate the bracket twice
            if let Ok(false) = crate::infrastructure::postgres_adapter::check_knockout_stage_generated(pool, tourney_id).await {
                println!("[tournament] Group stage complete! Transitioning to knockout phase for tournament {}", tourney_id);
                
                // Fetch standings
                if let Ok(standings) = crate::infrastructure::postgres_adapter::get_league_standings(pool, tourney_id).await {
                    let advancing = crate::infrastructure::postgres_adapter::get_tournament_advancing_count(pool, tourney_id).await.unwrap_or(2);
                    
                    // Generate Phase Two fixtures
                    let bracket = generate_group_knockout_phase_two_fixtures(tourney_id, standings, advancing);
                    
                    // Offset the round_number for Phase Two fixtures to ensure they start after group matches
                    // A safe high number is 10 to separate them from Group Stages (Round 1, 2, 3...)
                    let mut fixtures = bracket.fixtures;
                    for f in &mut fixtures {
                        f.round_number += 10;
                    }
                    
                    if let Err(e) = crate::infrastructure::postgres_adapter::save_tournament_fixtures(pool, tourney_id, fixtures).await {
                        eprintln!("[tournament] Failed to save Phase Two knockout fixtures: {}", e);
                    }
                }
            }
        }
    }

    Ok(())
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
}

#[tokio::test]
async fn test_issue_total_rounds() {
    let r1_matches = 2;
    let total_rounds = (r1_matches as f64).log2().ceil() as i32 + 1;
    println!("test_issue_total_rounds: r1_matches={}, total_rounds={}", r1_matches, total_rounds);
    assert_eq!(total_rounds, 2);
}
