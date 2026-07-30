pub struct MpsInput {
    pub possession: f64,
    pub passes_completed: u32,
    pub passes_attempted: u32,
    pub goals_scored: u32,
    pub shots_on_target: u32,
    pub interceptions: u32,
    pub player_rating: i32,
    pub opponent_rating: i32,
}

#[allow(dead_code)]
pub struct MpsResult {
    pub mps: f64,
    pub possession_score: f64,
    pub passing_score: f64,
    pub efficiency_score: f64,
    pub defense_score: f64,
    pub opponent_coeff: f64,
}

pub fn calculate_mps(input: &MpsInput) -> MpsResult {
    // Sub-score 1: Possession (0-100)
    let possession_score = input.possession.clamp(0.0, 100.0);

    // Sub-score 2: Passing Accuracy (0-100)
    let passing_score = if input.passes_attempted > 0 {
        (input.passes_completed as f64 / input.passes_attempted as f64) * 100.0
    } else {
        0.0
    };

    // Sub-score 3: Shot Efficiency (0-100)
    let efficiency_score = if input.shots_on_target > 0 {
        (input.goals_scored as f64 / input.shots_on_target as f64) * 100.0
    } else {
        0.0
    };

    // Sub-score 4: Defensive Actions (0-100)
    let defense_score = ((input.interceptions * 10) as f64).min(100.0);

    // Opponent Coefficient C_opp (clamped between 0.8 and 1.2)
    let raw_coeff = 1.0 + ((input.opponent_rating - input.player_rating) as f64 / 2000.0);
    let opponent_coeff = raw_coeff.clamp(0.8, 1.2);

    // Weights: w1=0.20, w2=0.30, w3=0.30, w4=0.20
    let base_mps = (0.20 * possession_score)
        + (0.30 * passing_score)
        + (0.30 * efficiency_score)
        + (0.20 * defense_score);

    let final_mps = (base_mps * opponent_coeff).min(100.0);

    MpsResult {
        mps: (final_mps * 100.0).round() / 100.0,
        possession_score,
        passing_score,
        efficiency_score,
        defense_score,
        opponent_coeff,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_perfect_mps() {
        let input = MpsInput {
            possession: 70.0,
            passes_completed: 100,
            passes_attempted: 100,
            goals_scored: 3,
            shots_on_target: 3,
            interceptions: 10,
            player_rating: 1000,
            opponent_rating: 1200,
        };

        let result = calculate_mps(&input);
        assert_eq!(result.mps, 100.0);
    }
}
