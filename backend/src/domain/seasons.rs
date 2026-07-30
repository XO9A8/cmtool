use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct Season {
    pub id: Uuid,
    pub club_id: Uuid,
    pub name: String,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub is_active: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SeasonSnapshot {
    pub id: Uuid,
    pub season_id: Uuid,
    pub player_id: Uuid,
    pub final_skill_rating: i32,
    pub final_form_rating: f64,
    pub matches_played: u32,
    pub win_rate: f64,
}

pub fn create_season_snapshot(
    season_id: Uuid,
    player_id: Uuid,
    final_skill_rating: i32,
    final_form_rating: f64,
    matches_played: u32,
    wins: u32,
) -> SeasonSnapshot {
    let win_rate = if matches_played > 0 {
        ((wins as f64 / matches_played as f64) * 100.0 * 100.0).round() / 100.0
    } else {
        0.0
    };

    SeasonSnapshot {
        id: Uuid::new_v4(),
        season_id,
        player_id,
        final_skill_rating,
        final_form_rating,
        matches_played,
        win_rate,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_season_snapshot_creation() {
        let snapshot = create_season_snapshot(Uuid::new_v4(), Uuid::new_v4(), 1450, 82.5, 20, 15);
        assert_eq!(snapshot.final_skill_rating, 1450);
        assert_eq!(snapshot.win_rate, 75.0);
    }
}
