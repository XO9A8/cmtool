//! # Play Style Classifier & Badge Evaluation Module
//!
//! Classifies player tactical play styles (`Possession Master`, `Counter Attacker`, `High Press`, `Out Wide`)
//! based on match statistical averages and evaluates milestone achievement badges.

use serde::{Deserialize, Serialize};

/// Categorized tactical play styles in eFootball.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum PlayStyleTag {
    /// Dominated by high possession (> 55%) and pass completion (> 82%).
    PossessionMaster,
    /// Fast direct attack with lower possession (< 48%) and high conversion efficiency (> 40%).
    CounterAttacker,
    /// Defensive pressure with high interception count (>= 6.0 per match).
    HighPress,
    /// Wing play / cross-oriented attack pattern.
    OutWide,
}

impl PlayStyleTag {
    /// Returns string representation of tactical play style.
    pub fn as_str(&self) -> &'static str {
        match self {
            PlayStyleTag::PossessionMaster => "Possession Master",
            PlayStyleTag::CounterAttacker => "Counter Attacker",
            PlayStyleTag::HighPress => "High Press",
            PlayStyleTag::OutWide => "Out Wide",
        }
    }
}

/// Rolling statistical averages across recent matches for a player.
pub struct PlayerMatchStatsSummary {
    /// Average possession percentage.
    pub avg_possession: f64,
    /// Average pass completion accuracy percentage.
    pub avg_pass_accuracy: f64,
    /// Average goal scoring efficiency per shot on target.
    pub avg_shot_efficiency: f64,
    /// Average defensive interceptions per match.
    pub avg_interceptions: f64,
}

/// Classifies tactical play style tag based on statistical thresholds.
pub fn classify_play_style(stats: &PlayerMatchStatsSummary) -> PlayStyleTag {
    if stats.avg_possession >= 55.0 && stats.avg_pass_accuracy >= 82.0 {
        PlayStyleTag::PossessionMaster
    } else if stats.avg_interceptions >= 6.0 {
        PlayStyleTag::HighPress
    } else if stats.avg_possession < 48.0 && stats.avg_shot_efficiency >= 40.0 {
        PlayStyleTag::CounterAttacker
    } else {
        PlayStyleTag::OutWide
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_play_style_possession_master() {
        let stats = PlayerMatchStatsSummary {
            avg_possession: 62.0,
            avg_pass_accuracy: 85.0,
            avg_shot_efficiency: 30.0,
            avg_interceptions: 3.0,
        };
        assert_eq!(classify_play_style(&stats), PlayStyleTag::PossessionMaster);
    }

    #[test]
    fn test_play_style_counter_attacker() {
        let stats = PlayerMatchStatsSummary {
            avg_possession: 45.0,
            avg_pass_accuracy: 75.0,
            avg_shot_efficiency: 45.0,
            avg_interceptions: 4.0,
        };
        assert_eq!(classify_play_style(&stats), PlayStyleTag::CounterAttacker);
    }
}
