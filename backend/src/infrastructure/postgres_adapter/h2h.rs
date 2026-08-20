//! # PostgreSQL Infrastructure Adapter Module
//!
//! Provides transaction-safe database interactions with PostgreSQL using SQLx,
//! including match record insertion, player profile Elo rating updates, Elo history logging,
//! real-time club rankings queries, Head-to-Head stats queries, clubs management,
//! dispute persistence, tournament bracket fetching, and player analytics.

use serde::Serialize;
use sqlx::{FromRow, PgPool, Postgres, Row, Transaction};
use uuid::Uuid;

use crate::domain::{
    elo::EloResult,
    mps::MpsResult,
    play_style::{classify_play_style, PlayerMatchStatsSummary},
    tournament::{predict_match_outcome_advanced, MatchPrediction},
};

// ─────────────────────────────────────────────────────────────────────────────
// Head-to-Head Queries
// ─────────────────────────────────────────────────────────────────────────────

/// Head-to-Head database query result row.
#[derive(Serialize, Clone, Debug, Default)]
pub struct PlayerPerformanceStats {
    pub possession: f64,
    pub passing: f64,
    pub shooting: f64,
    pub defending: f64,
    pub form: f64,
}

#[derive(Serialize, Clone, Debug)]
pub struct H2hRecentMatch {
    pub match_id: Uuid,
    pub player_1_score: i32,
    pub player_2_score: i32,
    pub winner_id: Option<Uuid>,
    pub match_type: String,
    pub created_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Serialize, Clone, Debug)]
pub struct H2hFullResult {
    pub player_1_id: Uuid,
    pub player_1_name: String,
    pub player_1_avatar: Option<String>,
    pub player_1_elo: i32,
    pub player_1_stats: PlayerPerformanceStats,
    pub player_2_id: Uuid,
    pub player_2_name: String,
    pub player_2_avatar: Option<String>,
    pub player_2_elo: i32,
    pub player_2_stats: PlayerPerformanceStats,
    pub elo_delta: i32,
    pub total_matches: i64,
    pub player_1_wins: i64,
    pub draws: i64,
    pub player_2_wins: i64,
    pub player_1_goals: i64,
    pub player_2_goals: i64,
    pub avg_goal_diff: f64,
    pub recent_matches: Vec<H2hRecentMatch>,
    pub player_1_overall_matches: i64,
    pub player_1_overall_wins: i64,
    pub player_1_overall_draws: i64,
    pub player_1_overall_losses: i64,
    pub player_1_overall_goals: i64,
    pub player_2_overall_matches: i64,
    pub player_2_overall_wins: i64,
    pub player_2_overall_draws: i64,
    pub player_2_overall_losses: i64,
    pub player_2_overall_goals: i64,
    pub scope: String,
    pub match_limit: Option<i64>,
    pub prediction: MatchPrediction,
}

/// Queries historical Head-to-Head match records between two players with optional match limit and scope.
pub async fn get_h2h_record_db(
    pool: &PgPool,
    p1_id: Uuid,
    p2_id: Uuid,
    limit: Option<i64>,
    scope: Option<&str>,
) -> Result<H2hFullResult, sqlx::Error> {
    let effective_scope = match scope {
        Some("direct") | Some("h2h") => "direct",
        _ => "overall",
    };
    let is_direct = effective_scope == "direct";
    let effective_limit = limit.unwrap_or(10000);

    #[derive(FromRow)]
    struct PlayerInfoRow {
        name: Option<String>,
        avatar_graphic: Option<String>,
        elo: Option<i32>,
        form: Option<f64>,
    }

    // 1. Get Player 1 Info
    let p1_row = sqlx::query_as::<_, PlayerInfoRow>(
        r#"
        SELECT COALESCE(NULLIF(u.full_name, ''), u.username, 'Player 1') AS name,
               pp.avatar_graphic,
               COALESCE(cm.skill_rating, 1000)::INT4 AS elo,
               COALESCE(cm.form_rating, 50.0)::FLOAT8 AS form
        FROM Users u
        LEFT JOIN Player_Profiles pp ON u.id = pp.user_id
        LEFT JOIN (
            SELECT DISTINCT ON (player_id) player_id, skill_rating, form_rating
            FROM Club_Memberships
            ORDER BY player_id, joined_at DESC NULLS LAST
        ) cm ON cm.player_id = u.id
        WHERE u.id = $1
        "#,
    )
    .bind(p1_id)
    .fetch_optional(pool)
    .await?;

    let p1_name = p1_row.as_ref().and_then(|r| r.name.clone()).unwrap_or_else(|| "Player 1".to_string());
    let p1_avatar = p1_row.as_ref().and_then(|r| r.avatar_graphic.clone());
    let p1_elo = p1_row.as_ref().and_then(|r| r.elo).unwrap_or(1000);
    let p1_form = p1_row.as_ref().and_then(|r| r.form).unwrap_or(50.0);

    // 2. Get Player 2 Info
    let p2_row = sqlx::query_as::<_, PlayerInfoRow>(
        r#"
        SELECT COALESCE(NULLIF(u.full_name, ''), u.username, 'Player 2') AS name,
               pp.avatar_graphic,
               COALESCE(cm.skill_rating, 1000)::INT4 AS elo,
               COALESCE(cm.form_rating, 50.0)::FLOAT8 AS form
        FROM Users u
        LEFT JOIN Player_Profiles pp ON u.id = pp.user_id
        LEFT JOIN (
            SELECT DISTINCT ON (player_id) player_id, skill_rating, form_rating
            FROM Club_Memberships
            ORDER BY player_id, joined_at DESC NULLS LAST
        ) cm ON cm.player_id = u.id
        WHERE u.id = $1
        "#,
    )
    .bind(p2_id)
    .fetch_optional(pool)
    .await?;

    let p2_name = p2_row.as_ref().and_then(|r| r.name.clone()).unwrap_or_else(|| "Player 2".to_string());
    let p2_avatar = p2_row.as_ref().and_then(|r| r.avatar_graphic.clone());
    let p2_elo = p2_row.as_ref().and_then(|r| r.elo).unwrap_or(1000);
    let p2_form = p2_row.as_ref().and_then(|r| r.form).unwrap_or(50.0);

    let elo_delta = p1_elo - p2_elo;

    // 3. Aggregate Direct Match Records stats (filtered by limit if specified)
    #[derive(FromRow)]
    struct StatsRow {
        total_matches: i64,
        p1_wins: i64,
        draws: i64,
        p2_wins: i64,
        p1_goals: i64,
        p2_goals: i64,
        avg_goal_diff: f64,
    }

    let stats = sqlx::query_as::<_, StatsRow>(
        r#"
        SELECT
            COUNT(*)::INT8 as total_matches,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for > goals_against)
                               OR  (opponent_id = $1 AND goals_against > goals_for))::INT8 as p1_wins,
            COUNT(*) FILTER (WHERE goals_for = goals_against)::INT8 as draws,
            COUNT(*) FILTER (WHERE (player_id = $2 AND goals_for > goals_against)
                               OR  (opponent_id = $2 AND goals_against > goals_for))::INT8 as p2_wins,
            COALESCE(SUM(CASE WHEN player_id = $1 THEN goals_for ELSE goals_against END), 0)::INT8 as p1_goals,
            COALESCE(SUM(CASE WHEN player_id = $2 THEN goals_for ELSE goals_against END), 0)::INT8 as p2_goals,
            COALESCE(AVG(ABS(goals_for - goals_against)), 0.0)::FLOAT8 as avg_goal_diff
        FROM (
            SELECT player_id, opponent_id, goals_for, goals_against
            FROM Match_Records
            WHERE ((player_id = $1 AND opponent_id = $2)
               OR  (player_id = $2 AND opponent_id = $1))
              AND deleted_at IS NULL
              AND (verification_status = 'approved' OR verification_status IS NULL)
            ORDER BY created_at DESC
            LIMIT $3
        ) sub
        "#,
    )
    .bind(p1_id)
    .bind(p2_id)
    .bind(effective_limit)
    .fetch_one(pool)
    .await
    .unwrap_or(StatsRow {
        total_matches: 0,
        p1_wins: 0,
        draws: 0,
        p2_wins: 0,
        p1_goals: 0,
        p2_goals: 0,
        avg_goal_diff: 0.0,
    });

    // 4. Query recent direct matches between these two players
    #[derive(FromRow)]
    struct RecentRow {
        id: Uuid,
        player_id: Uuid,
        opponent_id: Uuid,
        goals_for: i32,
        goals_against: i32,
        match_type: String,
        created_at: Option<chrono::DateTime<chrono::Utc>>,
    }

    let recent_limit = if is_direct && limit.is_some() {
        effective_limit.min(20)
    } else {
        10
    };

    let recent_rows = sqlx::query_as::<_, RecentRow>(
        r#"
        SELECT
            id,
            player_id,
            opponent_id,
            goals_for::INT4 as goals_for,
            goals_against::INT4 as goals_against,
            match_type,
            created_at
        FROM Match_Records
        WHERE ((player_id = $1 AND opponent_id = $2)
           OR  (player_id = $2 AND opponent_id = $1))
          AND deleted_at IS NULL
          AND (verification_status = 'approved' OR verification_status IS NULL)
        ORDER BY created_at DESC
        LIMIT $3
        "#,
    )
    .bind(p1_id)
    .bind(p2_id)
    .bind(recent_limit)
    .fetch_all(pool)
    .await?;

    let recent_matches: Vec<H2hRecentMatch> = recent_rows
        .into_iter()
        .map(|r| {
            let (p1_score, p2_score) = if r.player_id == p1_id {
                (r.goals_for, r.goals_against)
            } else {
                (r.goals_against, r.goals_for)
            };

            let winner_id = if p1_score > p2_score {
                Some(p1_id)
            } else if p2_score > p1_score {
                Some(p2_id)
            } else {
                None
            };

            H2hRecentMatch {
                match_id: r.id,
                player_1_score: p1_score,
                player_2_score: p2_score,
                winner_id,
                match_type: r.match_type,
                created_at: r.created_at,
            }
        })
        .collect();

    // 5. Query match performance stats for Player 1 & Player 2 (Direct or Overall based on scope)
    #[derive(FromRow)]
    struct PerfRow {
        possession: Option<f64>,
        passing: Option<f64>,
        shooting: Option<f64>,
        defending: Option<f64>,
    }

    let (p1_perf, p2_perf) = if is_direct {
        let p1 = sqlx::query_as::<_, PerfRow>(
            r#"
            SELECT
                AVG(CASE WHEN player_id = $1 THEN possession::FLOAT8 ELSE (100.0 - possession::FLOAT8) END) as possession,
                AVG(CASE 
                    WHEN player_id = $1 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    WHEN opponent_id = $1 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    ELSE NULL 
                END) as passing,
                AVG(CASE 
                    WHEN player_id = $1 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    WHEN opponent_id = $1 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    ELSE NULL 
                END) as shooting,
                AVG(CASE 
                    WHEN player_id = $1 THEN (GREATEST(0.0, 10.0 - goals_against::FLOAT8) * 6.0 + LEAST(10.0, COALESCE(interceptions::FLOAT8, 0.0)) * 4.0)
                    WHEN opponent_id = $1 THEN (GREATEST(0.0, 10.0 - goals_for::FLOAT8) * 10.0)
                    ELSE NULL 
                END) as defending
            FROM (
                SELECT player_id, opponent_id, possession, passes_attempted, passes_completed, shots_total, shots_on_target, goals_for, goals_against, interceptions
                FROM Match_Records
                WHERE ((player_id = $1 AND opponent_id = $2)
                   OR  (player_id = $2 AND opponent_id = $1))
                  AND deleted_at IS NULL
                  AND (verification_status = 'approved' OR verification_status IS NULL)
                ORDER BY created_at DESC
                LIMIT $3
            ) sub
            "#,
        )
        .bind(p1_id)
        .bind(p2_id)
        .bind(effective_limit)
        .fetch_one(pool)
        .await
        .unwrap_or(PerfRow { possession: None, passing: None, shooting: None, defending: None });

        let p2 = sqlx::query_as::<_, PerfRow>(
            r#"
            SELECT
                AVG(CASE WHEN player_id = $2 THEN possession::FLOAT8 ELSE (100.0 - possession::FLOAT8) END) as possession,
                AVG(CASE 
                    WHEN player_id = $2 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    WHEN opponent_id = $2 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    ELSE NULL 
                END) as passing,
                AVG(CASE 
                    WHEN player_id = $2 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    WHEN opponent_id = $2 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    ELSE NULL 
                END) as shooting,
                AVG(CASE 
                    WHEN player_id = $2 THEN (GREATEST(0.0, 10.0 - goals_against::FLOAT8) * 6.0 + LEAST(10.0, COALESCE(interceptions::FLOAT8, 0.0)) * 4.0)
                    WHEN opponent_id = $2 THEN (GREATEST(0.0, 10.0 - goals_for::FLOAT8) * 10.0)
                    ELSE NULL 
                END) as defending
            FROM (
                SELECT player_id, opponent_id, possession, passes_attempted, passes_completed, shots_total, shots_on_target, goals_for, goals_against, interceptions
                FROM Match_Records
                WHERE ((player_id = $1 AND opponent_id = $2)
                   OR  (player_id = $2 AND opponent_id = $1))
                  AND deleted_at IS NULL
                  AND (verification_status = 'approved' OR verification_status IS NULL)
                ORDER BY created_at DESC
                LIMIT $3
            ) sub
            "#,
        )
        .bind(p1_id)
        .bind(p2_id)
        .bind(effective_limit)
        .fetch_one(pool)
        .await
        .unwrap_or(PerfRow { possession: None, passing: None, shooting: None, defending: None });

        (p1, p2)
    } else {
        let p1 = sqlx::query_as::<_, PerfRow>(
            r#"
            SELECT
                AVG(CASE WHEN player_id = $1 THEN possession::FLOAT8 ELSE (100.0 - possession::FLOAT8) END) as possession,
                AVG(CASE 
                    WHEN player_id = $1 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    WHEN opponent_id = $1 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    ELSE NULL 
                END) as passing,
                AVG(CASE 
                    WHEN player_id = $1 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    WHEN opponent_id = $1 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    ELSE NULL 
                END) as shooting,
                AVG(CASE 
                    WHEN player_id = $1 THEN (GREATEST(0.0, 10.0 - goals_against::FLOAT8) * 6.0 + LEAST(10.0, COALESCE(interceptions::FLOAT8, 0.0)) * 4.0)
                    WHEN opponent_id = $1 THEN (GREATEST(0.0, 10.0 - goals_for::FLOAT8) * 10.0)
                    ELSE NULL 
                END) as defending
            FROM (
                SELECT player_id, opponent_id, possession, passes_attempted, passes_completed, shots_total, shots_on_target, goals_for, goals_against, interceptions
                FROM Match_Records
                WHERE (player_id = $1 OR opponent_id = $1)
                  AND deleted_at IS NULL
                  AND (verification_status = 'approved' OR verification_status IS NULL)
                ORDER BY created_at DESC
                LIMIT $2
            ) sub
            "#,
        )
        .bind(p1_id)
        .bind(effective_limit)
        .fetch_one(pool)
        .await
        .unwrap_or(PerfRow { possession: None, passing: None, shooting: None, defending: None });

        let p2 = sqlx::query_as::<_, PerfRow>(
            r#"
            SELECT
                AVG(CASE WHEN player_id = $1 THEN possession::FLOAT8 ELSE (100.0 - possession::FLOAT8) END) as possession,
                AVG(CASE 
                    WHEN player_id = $1 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    WHEN opponent_id = $1 AND passes_attempted > 0 THEN (passes_completed::FLOAT8 * 100.0 / passes_attempted::FLOAT8)
                    ELSE NULL 
                END) as passing,
                AVG(CASE 
                    WHEN player_id = $1 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    WHEN opponent_id = $1 AND shots_total > 0 THEN (shots_on_target::FLOAT8 * 100.0 / shots_total::FLOAT8)
                    ELSE NULL 
                END) as shooting,
                AVG(CASE 
                    WHEN player_id = $1 THEN (GREATEST(0.0, 10.0 - goals_against::FLOAT8) * 6.0 + LEAST(10.0, COALESCE(interceptions::FLOAT8, 0.0)) * 4.0)
                    WHEN opponent_id = $1 THEN (GREATEST(0.0, 10.0 - goals_for::FLOAT8) * 10.0)
                    ELSE NULL 
                END) as defending
            FROM (
                SELECT player_id, opponent_id, possession, passes_attempted, passes_completed, shots_total, shots_on_target, goals_for, goals_against, interceptions
                FROM Match_Records
                WHERE (player_id = $1 OR opponent_id = $1)
                  AND deleted_at IS NULL
                  AND (verification_status = 'approved' OR verification_status IS NULL)
                ORDER BY created_at DESC
                LIMIT $2
            ) sub
            "#,
        )
        .bind(p2_id)
        .bind(effective_limit)
        .fetch_one(pool)
        .await
        .unwrap_or(PerfRow { possession: None, passing: None, shooting: None, defending: None });

        (p1, p2)
    };

    // 6. Query overall career records for both players (with match limit if specified)
    #[derive(FromRow)]
    struct OverallRow {
        total_matches: i64,
        wins: i64,
        draws: i64,
        losses: i64,
        goals_for: i64,
    }

    let p1_overall = sqlx::query_as::<_, OverallRow>(
        r#"
        SELECT
            COUNT(*)::INT8 as total_matches,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for > goals_against)
                               OR  (opponent_id = $1 AND goals_against > goals_for))::INT8 as wins,
            COUNT(*) FILTER (WHERE goals_for = goals_against)::INT8 as draws,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for < goals_against)
                               OR  (opponent_id = $1 AND goals_against < goals_for))::INT8 as losses,
            COALESCE(SUM(CASE WHEN player_id = $1 THEN goals_for ELSE goals_against END), 0)::INT8 as goals_for
        FROM (
            SELECT player_id, opponent_id, goals_for, goals_against
            FROM Match_Records
            WHERE (player_id = $1 OR opponent_id = $1)
              AND deleted_at IS NULL
              AND (verification_status = 'approved' OR verification_status IS NULL)
            ORDER BY created_at DESC
            LIMIT $2
        ) sub
        "#,
    )
    .bind(p1_id)
    .bind(effective_limit)
    .fetch_one(pool)
    .await
    .unwrap_or(OverallRow { total_matches: 0, wins: 0, draws: 0, losses: 0, goals_for: 0 });

    let p2_overall = sqlx::query_as::<_, OverallRow>(
        r#"
        SELECT
            COUNT(*)::INT8 as total_matches,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for > goals_against)
                               OR  (opponent_id = $1 AND goals_against > goals_for))::INT8 as wins,
            COUNT(*) FILTER (WHERE goals_for = goals_against)::INT8 as draws,
            COUNT(*) FILTER (WHERE (player_id = $1 AND goals_for < goals_against)
                               OR  (opponent_id = $1 AND goals_against < goals_for))::INT8 as losses,
            COALESCE(SUM(CASE WHEN player_id = $1 THEN goals_for ELSE goals_against END), 0)::INT8 as goals_for
        FROM (
            SELECT player_id, opponent_id, goals_for, goals_against
            FROM Match_Records
            WHERE (player_id = $1 OR opponent_id = $1)
              AND deleted_at IS NULL
              AND (verification_status = 'approved' OR verification_status IS NULL)
            ORDER BY created_at DESC
            LIMIT $2
        ) sub
        "#,
    )
    .bind(p2_id)
    .bind(effective_limit)
    .fetch_one(pool)
    .await
    .unwrap_or(OverallRow { total_matches: 0, wins: 0, draws: 0, losses: 0, goals_for: 0 });

    let player_1_stats = PlayerPerformanceStats {
        possession: p1_perf.possession.unwrap_or(50.0).clamp(10.0, 100.0),
        passing: p1_perf.passing.unwrap_or(75.0).clamp(10.0, 100.0),
        shooting: p1_perf.shooting.unwrap_or(50.0).clamp(10.0, 100.0),
        defending: p1_perf.defending.unwrap_or(60.0).clamp(10.0, 100.0),
        form: p1_form.clamp(10.0, 100.0),
    };

    let player_2_stats = PlayerPerformanceStats {
        possession: p2_perf.possession.unwrap_or(50.0).clamp(10.0, 100.0),
        passing: p2_perf.passing.unwrap_or(75.0).clamp(10.0, 100.0),
        shooting: p2_perf.shooting.unwrap_or(50.0).clamp(10.0, 100.0),
        defending: p2_perf.defending.unwrap_or(60.0).clamp(10.0, 100.0),
        form: p2_form.clamp(10.0, 100.0),
    };

    let historical_draw_rate = if stats.total_matches > 0 {
        Some(stats.draws as f64 / stats.total_matches as f64)
    } else {
        let total_combined = p1_overall.total_matches + p2_overall.total_matches;
        if total_combined > 0 {
            Some((p1_overall.draws + p2_overall.draws) as f64 / total_combined as f64)
        } else {
            None
        }
    };

    let prediction = predict_match_outcome_advanced(
        p1_elo,
        p2_elo,
        stats.p1_wins as u32,
        stats.p2_wins as u32,
        Some(p1_form),
        Some(p2_form),
        historical_draw_rate,
        Some(stats.avg_goal_diff),
    );

    Ok(H2hFullResult {
        player_1_id: p1_id,
        player_1_name: p1_name,
        player_1_avatar: p1_avatar,
        player_1_elo: p1_elo,
        player_1_stats,
        player_2_id: p2_id,
        player_2_name: p2_name,
        player_2_avatar: p2_avatar,
        player_2_elo: p2_elo,
        player_2_stats,
        elo_delta,
        total_matches: stats.total_matches,
        player_1_wins: stats.p1_wins,
        draws: stats.draws,
        player_2_wins: stats.p2_wins,
        player_1_goals: stats.p1_goals,
        player_2_goals: stats.p2_goals,
        avg_goal_diff: stats.avg_goal_diff,
        recent_matches,
        player_1_overall_matches: p1_overall.total_matches,
        player_1_overall_wins: p1_overall.wins,
        player_1_overall_draws: p1_overall.draws,
        player_1_overall_losses: p1_overall.losses,
        player_1_overall_goals: p1_overall.goals_for,
        player_2_overall_matches: p2_overall.total_matches,
        player_2_overall_wins: p2_overall.wins,
        player_2_overall_draws: p2_overall.draws,
        player_2_overall_losses: p2_overall.losses,
        player_2_overall_goals: p2_overall.goals_for,
        scope: effective_scope.to_string(),
        match_limit: limit,
        prediction,
    })
}

