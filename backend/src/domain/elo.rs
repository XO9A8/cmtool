pub enum MatchType {
    Friendly,
    League,
    TournamentFinal,
}

impl MatchType {
    pub fn base_k(&self) -> f64 {
        match self {
            MatchType::TournamentFinal => 40.0,
            MatchType::League => 32.0,
            MatchType::Friendly => 16.0,
        }
    }
}

pub struct EloInput {
    pub player_rating: i32,
    pub opponent_rating: i32,
    pub goals_for: i32,
    pub goals_against: i32,
    pub match_type: MatchType,
    pub is_provisional: bool,
}

#[allow(dead_code)]
pub struct EloResult {
    pub expected_score: f64,
    pub actual_score: f64,
    pub k_factor: f64,
    pub rating_delta: i32,
    pub new_rating: i32,
}

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

#[allow(dead_code)]
pub struct CoOpEloInput {
    pub p1_rating: i32,
    pub p2_rating: i32,
    pub opp_team_rating: i32,
    pub goals_for: i32,
    pub goals_against: i32,
    pub match_type: MatchType,
}

#[allow(dead_code)]
pub struct CoOpEloResult {
    pub team_rating: i32,
    pub p1_new_rating: i32,
    pub p2_new_rating: i32,
    pub p1_delta: i32,
    pub p2_delta: i32,
}

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
