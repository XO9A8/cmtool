//! # Match Performance Score (MPS) Module
//!
//! Computes a single match performance rating on a 0-100 scale evaluating possession,
//! pass completion accuracy, shot conversion efficiency, and defensive interceptions,
//! scaled by the opponent rating difficulty coefficient ($C_{opp}$).

/// Input statistical parameters extracted from post-match screenshot OCR payload.
pub struct MpsInput {
    /// Match possession percentage (0.0 to 100.0).
    pub possession: f64,
    /// Number of completed passes.
    pub passes_completed: u32,
    /// Total number of attempted passes.
    pub passes_attempted: u32,
    /// Number of goals scored by player.
    pub goals_scored: u32,
    /// Shots on target.
    pub shots_on_target: u32,
    /// Total defensive interceptions performed.
    pub interceptions: u32,
    /// Player's Elo rating before match.
    pub player_rating: i32,
    /// Opponent's Elo rating before match.
    pub opponent_rating: i32,
}

/// Results of the Match Performance Score evaluation.
#[allow(dead_code)]
pub struct MpsResult {
    /// Final overall Match Performance Score (0.0 to 100.0).
    pub mps: f64,
    /// Possession sub-score component (weight = 0.20).
    pub possession_score: f64,
    /// Pass completion accuracy sub-score component (weight = 0.30).
    pub passing_score: f64,
    /// Shot conversion efficiency sub-score component (weight = 0.30).
    pub efficiency_score: f64,
    /// Defensive actions sub-score component (weight = 0.20).
    pub defense_score: f64,
    /// Opponent difficulty multiplier coefficient $C_{opp}$ (clamped 0.8 to 1.2).
    pub opponent_coeff: f64,
}

/// Evaluates a single match performance against historical weights and opponent difficulty coefficient.
///
/// Formula:
/// $\text{MPS} = \min\left(100, \left( 0.20 \cdot S_{possession} + 0.30 \cdot S_{passing} + 0.30 \cdot S_{efficiency} + 0.20 \cdot S_{defense} \right) \times C_{opp} \right)$
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

/// Calculates the Exponentially Weighted Moving Average (EWMA) of recent Match Performance Scores.
///
/// EWMA prioritises recent form over older results.
/// Formula: `EWMA_n = α · MPS_n + (1 − α) · EWMA_{n-1}`
///
/// # Arguments
/// * `mps_history` - Ordered slice of MPS values from oldest to most-recent.
/// * `alpha` - Smoothing factor (0.0–1.0). Use `0.3` for standard form tracking.
///
/// Returns `50.0` (neutral baseline) if the history slice is empty.
pub fn calculate_ewma_form(mps_history: &[f64], alpha: f64) -> f64 {
    if mps_history.is_empty() {
        return 50.0;
    }
    let alpha = alpha.clamp(0.0, 1.0);
    let mut ewma = mps_history[0];
    for &mps in &mps_history[1..] {
        ewma = alpha * mps + (1.0 - alpha) * ewma;
    }
    (ewma * 100.0).round() / 100.0
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
