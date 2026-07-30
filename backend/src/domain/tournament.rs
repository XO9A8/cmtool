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

/// Circle Method Scheduler for Round-Robin / League format.
pub fn generate_round_robin_fixtures(
    _tournament_id: Uuid,
    mut players: Vec<TournamentPlayer>,
) -> Vec<FixtureNode> {
    if players.len() % 2 != 0 {
        // Add dummy bye player if odd count
        players.push(TournamentPlayer {
            id: Uuid::nil(),
            username: "BYE".into(),
            skill_rating: 0,
        });
    }

    let n = players.len();
    let rounds = n - 1;
    let matches_per_round = n / 2;

    let mut fixtures = Vec::new();

    for round in 0..rounds {
        for i in 0..matches_per_round {
            let p1 = &players[i];
            let p2 = &players[n - 1 - i];

            if p1.id != Uuid::nil() && p2.id != Uuid::nil() {
                fixtures.push(FixtureNode {
                    id: Uuid::new_v4(),
                    round_number: (round + 1) as u32,
                    match_number: (i + 1) as u32,
                    player_1: Some(p1.clone()),
                    player_2: Some(p2.clone()),
                    winner_id: None,
                });
            }
        }

        // Rotate players array using Circle Method (keep 0 fixed, rotate others)
        let last = players.pop().unwrap();
        players.insert(1, last);
    }

    fixtures
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

        let fixtures = generate_round_robin_fixtures(Uuid::new_v4(), players);
        assert_eq!(fixtures.len(), 6);
    }
}
