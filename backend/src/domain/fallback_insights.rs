use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct InsightReport {
    pub summary: String,
    pub strengths: Vec<String>,
    pub areas_for_improvement: Vec<String>,
}

pub struct InsightInput {
    pub goals_for: u32,
    pub goals_against: u32,
    pub possession: f64,
    pub pass_accuracy: f64,
    pub shot_efficiency: f64,
    pub avg_possession_season: f64,
}

pub fn generate_fallback_report(input: &InsightInput) -> InsightReport {
    let outcome = if input.goals_for > input.goals_against {
        "won"
    } else if input.goals_for == input.goals_against {
        "drew"
    } else {
        "lost"
    };

    let summary = format!(
        "You {} the match {}-{}. You maintained {:.1}% possession during play.",
        outcome, input.goals_for, input.goals_against, input.possession
    );

    let mut strengths = Vec::new();
    let mut improvements = Vec::new();

    if input.pass_accuracy >= 85.0 {
        strengths.push(format!(
            "Excellent distribution with {:.1}% passing accuracy.",
            input.pass_accuracy
        ));
    } else if input.pass_accuracy < 70.0 {
        improvements.push(format!(
            "Pass completion was low at {:.1}%. Consider safer build-up passes.",
            input.pass_accuracy
        ));
    }

    if input.possession > input.avg_possession_season + 5.0 {
        strengths.push(format!(
            "Possession ({:.1}%) exceeded your season average by {:.1}%.",
            input.possession,
            input.possession - input.avg_possession_season
        ));
    }

    if input.shot_efficiency >= 50.0 {
        strengths.push(format!(
            "High clinical finish rate of {:.1}% goals per shot on target.",
            input.shot_efficiency
        ));
    } else if input.shot_efficiency < 25.0 && input.goals_for < 2 {
        improvements.push(
            "Shot conversion was low. Focus on creating higher quality scoring opportunities."
                .to_string(),
        );
    }

    if strengths.is_empty() {
        strengths.push("Solid competitive effort overall.".to_string());
    }

    InsightReport {
        summary,
        strengths,
        areas_for_improvement: improvements,
    }
}
