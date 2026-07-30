use serde::{Deserialize, Serialize};

use crate::domain::fallback_insights::{generate_fallback_report, InsightInput, InsightReport};

#[allow(dead_code)]
#[derive(Serialize)]
struct GeminiRequest {
    contents: Vec<GeminiContent>,
    generation_config: GeminiGenerationConfig,
}

#[derive(Serialize)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
}

#[derive(Serialize)]
struct GeminiPart {
    text: String,
}

#[derive(Serialize)]
struct GeminiGenerationConfig {
    response_mime_type: String,
}

#[derive(Deserialize)]
struct GeminiResponse {
    candidates: Option<Vec<GeminiCandidate>>,
}

#[derive(Deserialize)]
struct GeminiCandidate {
    content: GeminiCandidateContent,
}

#[derive(Deserialize)]
struct GeminiCandidateContent {
    parts: Vec<GeminiCandidatePart>,
}

#[derive(Deserialize)]
struct GeminiCandidatePart {
    text: String,
}

/// Generates natural language coaching insights using Google Gemini API
/// with strict anti-hallucination prompting and JSON schema enforcement.
pub async fn generate_coaching_insights(
    client: &reqwest::Client,
    api_key: Option<&str>,
    input: &InsightInput,
) -> InsightReport {
    let key = match api_key {
        Some(k) if !k.trim().is_empty() => k,
        _ => return generate_fallback_report(input),
    };

    let prompt = format!(
        r#"You are an expert eFootball tactical analyst. Analyze this match stat JSON and return a JSON object with:
- "summary": concise match summary
- "strengths": array of 1-3 tactical strength strings
- "areas_for_improvement": array of 1-3 improvement strings

CRITICAL RULES:
- STRICT ANTI-HALLUCINATION: Do NOT mention goal timings, goalscorers, player names, team formations, or substitutions. These stats are unavailable in standard post-match OCR screenshots.
- Rely ONLY on possession, pass completion rate, shot conversion efficiency, and interception counts provided.

Match Data:
- Goals Scored: {}
- Goals Conceded: {}
- Possession %: {:.1}%
- Pass Accuracy %: {:.1}%
- Shot Efficiency %: {:.1}%
- Player Season Avg Possession: {:.1}%"#,
        input.goals_for,
        input.goals_against,
        input.possession,
        input.pass_accuracy,
        input.shot_efficiency,
        input.avg_possession_season
    );

    let req_payload = GeminiRequest {
        contents: vec![GeminiContent {
            parts: vec![GeminiPart { text: prompt }],
        }],
        generation_config: GeminiGenerationConfig {
            response_mime_type: "application/json".to_string(),
        },
    };

    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={}",
        key
    );

    let res = client.post(&url).json(&req_payload).send().await;

    match res {
        Ok(response) if response.status().is_success() => {
            if let Ok(gemini_resp) = response.json::<GeminiResponse>().await {
                if let Some(candidate) = gemini_resp.candidates.and_then(|c| c.into_iter().next())
                {
                    if let Some(part) = candidate.content.parts.into_iter().next() {
                        if let Ok(parsed_report) = serde_json::from_str::<InsightReport>(&part.text)
                        {
                            return parsed_report;
                        }
                    }
                }
            }
            generate_fallback_report(input)
        }
        _ => generate_fallback_report(input),
    }
}
