//! # Dynamic Elo Rating System Module
//!
//! Provides mathematical calculations for player skill ratings in 1v1 and 2v2 competitive matches.
//! Includes expected score calculation, dynamic K-factor scaling based on margin of victory and
//! provisional status, and inverse-weighted 2v2 rating distribution.

/// Match categories determining the baseline K-factor multiplier.
pub enum MatchType {
    /// Friendly match (Base K = 16)
    Friendly,
    /// Standard League match (Base K = 32)
    League,
    /// Tournament Final match (Base K = 40)
    TournamentFinal,
}

impl MatchType {
    /// Returns the baseline K-factor integer multiplier for the match category.
    pub fn base_k(&self) -> f64 {
        match self {
            MatchType::TournamentFinal => 40.0,
            MatchType::League => 32.0,
            MatchType::Friendly => 16.0,
        }
    }
}

/// Input parameters required to compute an Elo rating update for a single player.
pub struct EloInput {
    /// Current Elo rating of the primary player.
    pub player_rating: i32,
    /// Current Elo rating of the opponent.
    pub opponent_rating: i32,
    /// Goals scored by the primary player.
    pub goals_for: i32,
    /// Goals conceded by the primary player.
    pub goals_against: i32,
    /// Match type category determining base K-factor.
    pub match_type: MatchType,
    /// Whether the player has played fewer than 10 matches (multiplier = 1.5x).
    pub is_provisional: bool,
}

/// Output results returned by the Elo rating calculation engine.
#[allow(dead_code)]
pub struct EloResult {
    /// Win probability / Expected score $E$ (0.0 to 1.0).
    pub expected_score: f64,
    /// Actual outcome score $S$ (1.0 = Win, 0.5 = Draw, 0.0 = Loss).
    pub actual_score: f64,
    /// Dynamic K-factor computed for this match ($K_{base} \cdot M_{margin} \cdot M_{provisional}$).
    pub k_factor: f64,
    /// The net change in rating points (positive or negative).
    pub rating_delta: i32,
    /// The updated skill rating integer ($R_{new} = R_{old} + \Delta R$).
    pub new_rating: i32,
}

/// Calculates the updated Elo rating for a 1v1 match.
///
/// Implements the formula:
/// $E = \frac{1}{1 + 10^{(R_{opp} - R_{player}) / 400}}$
///
/// $\Delta R = K \cdot (S - E)$
pub fn calculate_elo(input: &EloInput) -> EloResult {
    let r_player = input.player_rating as f64;
    let r_opp = input.opponent_rating as f64;

    // 1. Expected Score Formula: E = 1 / (1 + 10^((R_opp - R_player) / 400))
    let expected_score = 1.0 / (1.0 + 10.0_f64.powf((r_opp - r_player) / 400.0));

    // 2. Actual Score S (Win = 1.0, Draw = 0.5, Loss = 0.0)
    let actual_score = if input.goals_for > input.goals_against {
        1.0
    } else if input.goals_for == input.goals_against {
        0.5
    } else {
        0.0
    };

    // 3. Dynamic K-Factor = K_base * M_margin * M_provisional
    let k_base = input.match_type.base_k();
    let goal_diff = (input.goals_for - input.goals_against).abs() as f64;
    let m_margin = (1.0 + goal_diff).ln();
    let m_provisional = if input.is_provisional { 1.5 } else { 1.0 };

    let k_factor = k_base * m_margin * m_provisional;

    // 4. New Rating Delta = K * (S - E)
    let raw_delta = k_factor * (actual_score - expected_score);
    let rating_delta = raw_delta.round() as i32;
    let new_rating = input.player_rating + rating_delta;

    EloResult {
        expected_score,
        actual_score,
        k_factor,
        rating_delta,
        new_rating,
    }
}

/// Parameters for calculating 2v2 Co-op team Elo rating updates.
#[allow(dead_code)]
pub struct CoOpEloInput {
    /// Rating of Player 1 on Team A.
    pub p1_rating: i32,
    /// Rating of Player 2 on Team A.
    pub p2_rating: i32,
    /// Combined team rating of opposing Team B.
    pub opp_team_rating: i32,
    /// Goals scored by Team A.
    pub goals_for: i32,
    /// Goals conceded by Team A.
    pub goals_against: i32,
    /// Match category type.
    pub match_type: MatchType,
}

/// Output rating deltas for both co-op team members.
#[allow(dead_code)]
pub struct CoOpEloResult {
    /// Computed baseline team rating.
    pub team_rating: i32,
    /// Updated rating for Player 1.
    pub p1_new_rating: i32,
    /// Updated rating for Player 2.
    pub p2_new_rating: i32,
    /// Net rating change for Player 1.
    pub p1_delta: i32,
    /// Net rating change for Player 2.
    pub p2_delta: i32,
}

/// Calculates inverse-weighted 2v2 Co-Op Elo rating adjustments to prevent rating boosting.
#[allow(dead_code)]
pub fn calculate_coop_elo(input: &CoOpEloInput) -> CoOpEloResult {
    let team_rating = ((input.p1_rating + input.p2_rating) as f64 / 2.0).round() as i32;

    let base_elo = calculate_elo(&EloInput {
        player_rating: team_rating,
        opponent_rating: input.opp_team_rating,
        goals_for: input.goals_for,
        goals_against: input.goals_against,
        match_type: match input.match_type {
            MatchType::TournamentFinal => MatchType::TournamentFinal,
            MatchType::League => MatchType::League,
            MatchType::Friendly => MatchType::Friendly,
        },
        is_provisional: false,
    });

    let total_delta = base_elo.rating_delta as f64;
    let sum_ratings = (input.p1_rating + input.p2_rating) as f64;

    // Distribute delta inversely weighted by baseline rating to avoid boosting
    let p1_weight = if sum_ratings > 0.0 {
        1.0 - (input.p1_rating as f64 / sum_ratings)
    } else {
        0.5
    };
    let p2_weight = 1.0 - p1_weight;

    let p1_delta = (total_delta * p1_weight * 2.0).round() as i32;
    let p2_delta = (total_delta * p2_weight * 2.0).round() as i32;

    CoOpEloResult {
        team_rating,
        p1_new_rating: input.p1_rating + p1_delta,
        p2_new_rating: input.p2_rating + p2_delta,
        p1_delta,
        p2_delta,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_elo_win_against_equal_opponent() {
        let input = EloInput {
            player_rating: 1000,
            opponent_rating: 1000,
            goals_for: 2,
            goals_against: 0,
            match_type: MatchType::League,
            is_provisional: false,
        };

        let result = calculate_elo(&input);
        assert_eq!(result.expected_score, 0.5);
        assert_eq!(result.actual_score, 1.0);
        assert!(result.rating_delta > 0);
        assert_eq!(result.new_rating, 1000 + result.rating_delta);
    }

    #[test]
    fn test_elo_provisional_multiplier() {
        let std_input = EloInput {
            player_rating: 1000,
            opponent_rating: 1000,
            goals_for: 1,
            goals_against: 0,
            match_type: MatchType::League,
            is_provisional: false,
        };
        let prov_input = EloInput {
            player_rating: 1000,
            opponent_rating: 1000,
            goals_for: 1,
            goals_against: 0,
            match_type: MatchType::League,
            is_provisional: true,
        };

        let std_res = calculate_elo(&std_input);
        let prov_res = calculate_elo(&prov_input);

        assert!(prov_res.rating_delta > std_res.rating_delta);
    }
}
