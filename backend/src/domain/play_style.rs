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

/// Milestone badge definition.
#[allow(dead_code)]
pub struct BadgeDefinition {
    /// Unique badge code.
    pub code: &'static str,
    /// Display name.
    pub title: &'static str,
    /// Detailed description.
    pub description: &'static str,
}

/// Badge awarded for reaching 50 official club matches.
#[allow(dead_code)]
pub const BADGE_FIRST_50: BadgeDefinition = BadgeDefinition {
    code: "CLUB_VETERAN_50",
    title: "Club Veteran",
    description: "Recorded 50 official club matches",
};

/// Badge awarded for achieving a 10-match winning streak.
#[allow(dead_code)]
pub const BADGE_10_WIN_STREAK: BadgeDefinition = BadgeDefinition {
    code: "UNSTOPPABLE_10",
    title: "Unstoppable Force",
    description: "Achieved a 10-match winning streak",
};

/// Badge awarded for conceding 0 goals in 5 consecutive matches.
#[allow(dead_code)]
pub const BADGE_CLEAN_SHEET_MASTER: BadgeDefinition = BadgeDefinition {
    code: "CLEAN_SHEET_5",
    title: "Clean Sheet Master",
    description: "Conceded 0 goals in 5 consecutive matches",
};

/// Evaluates player stats and returns earned milestone badge codes.
#[allow(dead_code)]
pub fn evaluate_badges(
    matches_played: u32,
    current_win_streak: u32,
    consecutive_clean_sheets: u32,
) -> Vec<&'static str> {
    let mut badges = Vec::new();

    if matches_played >= 50 {
        badges.push(BADGE_FIRST_50.code);
    }
    if current_win_streak >= 10 {
        badges.push(BADGE_10_WIN_STREAK.code);
    }
    if consecutive_clean_sheets >= 5 {
        badges.push(BADGE_CLEAN_SHEET_MASTER.code);
    }

    badges
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

    #[test]
    fn test_badge_evaluation() {
        let badges = evaluate_badges(55, 12, 2);
        assert_eq!(badges.len(), 2);
        assert!(badges.contains(&"CLUB_VETERAN_50"));
        assert!(badges.contains(&"UNSTOPPABLE_10"));
    }
}
