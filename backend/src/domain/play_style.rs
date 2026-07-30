use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum PlayStyleTag {
    PossessionMaster,
    CounterAttacker,
    HighPress,
    OutWide,
    Unclassified,
}

impl PlayStyleTag {
    pub fn as_str(&self) -> &'static str {
        match self {
            PlayStyleTag::PossessionMaster => "Possession Master",
            PlayStyleTag::CounterAttacker => "Counter Attacker",
            PlayStyleTag::HighPress => "High Press",
            PlayStyleTag::OutWide => "Out Wide",
            PlayStyleTag::Unclassified => "Unclassified",
        }
    }
}

pub struct PlayerMatchStatsSummary {
    pub avg_possession: f64,
    pub avg_pass_accuracy: f64,
    pub avg_shot_efficiency: f64,
    pub avg_interceptions: f64,
}

pub fn classify_play_style(stats: &PlayerMatchStatsSummary) -> PlayStyleTag {
    if stats.avg_possession > 60.0 && stats.avg_pass_accuracy > 85.0 {
        PlayStyleTag::PossessionMaster
    } else if stats.avg_possession < 45.0 && stats.avg_shot_efficiency > 40.0 {
        PlayStyleTag::CounterAttacker
    } else if stats.avg_interceptions >= 8.0 {
        PlayStyleTag::HighPress
    } else if stats.avg_possession >= 50.0 && stats.avg_pass_accuracy > 80.0 {
        PlayStyleTag::OutWide
    } else {
        PlayStyleTag::Unclassified
    }
}

// Achievement & Badge Evaluator
#[derive(Debug, Serialize, Deserialize)]
pub struct BadgeDefinition {
    pub id: &'static str,
    pub name: &'static str,
    pub description: &'static str,
}

pub const BADGE_FIRST_50: BadgeDefinition = BadgeDefinition {
    id: "first_50_matches",
    name: "Club Veteran",
    description: "Recorded 50 official club matches.",
};

pub const BADGE_10_WIN_STREAK: BadgeDefinition = BadgeDefinition {
    id: "win_streak_10",
    name: "Unstoppable Force",
    description: "Achieved a 10-match winning streak.",
};

pub const BADGE_CLEAN_SHEET_MASTER: BadgeDefinition = BadgeDefinition {
    id: "clean_sheet_master",
    name: "Clean Sheet Master",
    description: "Conceded 0 goals in 5 consecutive matches.",
};

pub fn evaluate_badges(
    total_matches: u32,
    current_win_streak: u32,
    consecutive_clean_sheets: u32,
) -> Vec<BadgeDefinition> {
    let mut earned = Vec::new();

    if total_matches >= 50 {
        earned.push(BADGE_FIRST_50);
    }
    if current_win_streak >= 10 {
        earned.push(BADGE_10_WIN_STREAK);
    }
    if consecutive_clean_sheets >= 5 {
        earned.push(BADGE_CLEAN_SHEET_MASTER);
    }

    earned
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_play_style_possession_master() {
        let stats = PlayerMatchStatsSummary {
            avg_possession: 64.5,
            avg_pass_accuracy: 88.0,
            avg_shot_efficiency: 30.0,
            avg_interceptions: 5.0,
        };
        assert_eq!(classify_play_style(&stats), PlayStyleTag::PossessionMaster);
    }

    #[test]
    fn test_play_style_counter_attacker() {
        let stats = PlayerMatchStatsSummary {
            avg_possession: 42.0,
            avg_pass_accuracy: 75.0,
            avg_shot_efficiency: 50.0,
            avg_interceptions: 4.0,
        };
        assert_eq!(classify_play_style(&stats), PlayStyleTag::CounterAttacker);
    }

    #[test]
    fn test_badge_evaluation() {
        let badges = evaluate_badges(55, 12, 6);
        assert_eq!(badges.len(), 3);
    }
}
