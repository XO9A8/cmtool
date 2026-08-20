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
};

// ─────────────────────────────────────────────────────────────────────────────
// Matchdays & Scheduling
// ─────────────────────────────────────────────────────────────────────────────

#[derive(FromRow, Serialize)]
pub struct MatchdayRow {
    pub id: Uuid,
    pub tournament_id: Uuid,
    pub matchday_number: i32,
    pub scheduled_date: Option<chrono::NaiveDate>,
    pub status: String,
    pub match_count: i64,
    pub completed_count: i64,
    pub pending_count: i64,
    pub rescheduled_count: i64,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

pub async fn create_matchdays_batch(
    pool: &PgPool,
    tournament_id: Uuid,
    matchdays: &[(i32, Option<chrono::NaiveDate>)],
) -> Result<Vec<Uuid>, sqlx::Error> {
    if matchdays.is_empty() {
        return Ok(Vec::new());
    }

    let mut ids = Vec::with_capacity(matchdays.len());
    let mut query_builder = sqlx::QueryBuilder::new(
        "INSERT INTO Matchdays (id, tournament_id, matchday_number, scheduled_date, status) "
    );

    query_builder.push_values(matchdays, |mut b, (number, date)| {
        let id = Uuid::new_v4();
        ids.push(id);
        b.push_bind(id)
         .push_bind(tournament_id)
         .push_bind(*number)
         .push_bind(*date)
         .push_bind("upcoming");
    });

    query_builder.build().execute(pool).await?;
    
    Ok(ids)
}

pub async fn get_matchdays(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Vec<MatchdayRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, MatchdayRow>(
        r#"
        SELECT 
            md.id, md.tournament_id, md.matchday_number::INT4 AS matchday_number, md.scheduled_date, md.status,
            md.created_at, md.updated_at,
            COUNT(m.id)::INT8 AS match_count,
            COUNT(m.id) FILTER (WHERE m.status = 'completed')::INT8 AS completed_count,
            COUNT(m.id) FILTER (WHERE m.status IN ('scheduled', 'disputed'))::INT8 AS pending_count,
            COUNT(m.id) FILTER (WHERE m.is_rescheduled = true)::INT8 AS rescheduled_count
        FROM Matchdays md
        LEFT JOIN T_Matches m ON m.matchday_id = md.id
        WHERE md.tournament_id = $1
        GROUP BY md.id
        ORDER BY md.matchday_number ASC
        "#
    )
    .bind(tournament_id)
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

pub async fn update_matchday_date(
    pool: &PgPool,
    matchday_id: Uuid,
    new_date: Option<chrono::NaiveDate>,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query("UPDATE Matchdays SET scheduled_date = $1, updated_at = NOW() WHERE id = $2")
        .bind(new_date)
        .bind(matchday_id)
        .execute(&mut *tx)
        .await?;

    // Propagate new date to child matches that haven't been individually rescheduled
    let new_scheduled_at = new_date.map(|d| d.and_hms_opt(12, 0, 0).unwrap().and_utc());
    sqlx::query(
        "UPDATE T_Matches SET scheduled_at = $1, updated_at = NOW() WHERE matchday_id = $2 AND is_rescheduled = false"
    )
    .bind(new_scheduled_at)
    .bind(matchday_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn reschedule_match(
    pool: &PgPool,
    match_id: Uuid,
    new_scheduled_at: chrono::DateTime<chrono::Utc>,
    reason: Option<&str>,
) -> Result<(), sqlx::Error> {
    // We only set original_scheduled_at if it's currently NULL (i.e., first reschedule)
    sqlx::query(
        r#"
        UPDATE T_Matches 
        SET 
            original_scheduled_at = COALESCE(original_scheduled_at, scheduled_at),
            scheduled_at = $1,
            is_rescheduled = true,
            reschedule_count = reschedule_count + 1,
            reschedule_reason = $2,
            status = CASE WHEN status = 'scheduled' THEN 'rescheduled' ELSE status END,
            updated_at = NOW()
        WHERE id = $3
        "#
    )
    .bind(new_scheduled_at)
    .bind(reason)
    .bind(match_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn update_matchday_status(
    pool: &PgPool,
    matchday_id: Uuid,
) -> Result<String, sqlx::Error> {
    let stats = sqlx::query(
        "SELECT COUNT(*) as total, 
                COUNT(*) FILTER (WHERE status = 'completed') as completed,
                COUNT(*) FILTER (WHERE status = 'rescheduled' OR is_rescheduled = true) as rescheduled
         FROM T_Matches WHERE matchday_id = $1"
    )
    .bind(matchday_id)
    .fetch_one(pool)
    .await?;

    let total: i64 = stats.try_get("total").unwrap_or(0);
    let completed: i64 = stats.try_get("completed").unwrap_or(0);
    let rescheduled: i64 = stats.try_get("rescheduled").unwrap_or(0);

    let new_status = if total == 0 {
        "upcoming"
    } else if completed == total {
        "completed"
    } else if completed > 0 || rescheduled > 0 {
        "in_progress"
    } else {
        "upcoming"
    };

    sqlx::query("UPDATE Matchdays SET status = $1, updated_at = NOW() WHERE id = $2")
        .bind(new_status)
        .bind(matchday_id)
        .execute(pool)
        .await?;
    
    Ok(new_status.to_string())
}

pub async fn insert_schedule_audit(
    pool: &PgPool,
    entity_type: &str,
    entity_id: Uuid,
    action: &str,
    old_value: Option<&str>,
    new_value: Option<&str>,
    reason: Option<&str>,
    changed_by: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO schedule_audit_log (entity_type, entity_id, action, old_value, new_value, reason, changed_by)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#
    )
    .bind(entity_type)
    .bind(entity_id)
    .bind(action)
    .bind(old_value)
    .bind(new_value)
    .bind(reason)
    .bind(changed_by)
    .execute(pool)
    .await?;
    Ok(())
}

#[derive(Serialize)]
pub struct TournamentProgressRow {
    pub total_matchdays: i64,
    pub completed_matchdays: i64,
    pub total_matches: i64,
    pub completed_matches: i64,
    pub pending_matches: i64,
    pub rescheduled_matches: i64,
}

pub async fn get_tournament_progress(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<TournamentProgressRow, sqlx::Error> {
    let md_stats = sqlx::query(
        "SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE status = 'completed') as completed FROM Matchdays WHERE tournament_id = $1"
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    let match_stats = sqlx::query(
        "SELECT COUNT(*) as total, 
                COUNT(*) FILTER (WHERE status = 'completed') as completed,
                COUNT(*) FILTER (WHERE status IN ('scheduled', 'rescheduled', 'disputed')) as pending,
                COUNT(*) FILTER (WHERE is_rescheduled = true) as rescheduled
         FROM T_Matches WHERE tournament_id = $1"
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    Ok(TournamentProgressRow {
        total_matchdays: md_stats.try_get("total").unwrap_or(0),
        completed_matchdays: md_stats.try_get("completed").unwrap_or(0),
        total_matches: match_stats.try_get("total").unwrap_or(0),
        completed_matches: match_stats.try_get("completed").unwrap_or(0),
        pending_matches: match_stats.try_get("pending").unwrap_or(0),
        rescheduled_matches: match_stats.try_get("rescheduled").unwrap_or(0),
    })
}

// ─────────────────────────────────────────────────────────────────────────────
// League Standings
// ─────────────────────────────────────────────────────────────────────────────

/// League standing row with player name.
#[allow(dead_code)]
#[derive(FromRow, Serialize)]
pub struct LeagueStandingRow {
    pub player_id: Uuid,
    pub player_name: String,
    pub played: i32,
    pub won: i32,
    pub drawn: i32,
    pub lost: i32,
    pub goals_for: i32,
    pub goals_against: i32,
    pub goal_diff: i32,
    pub points: i32,
    pub group_name: Option<String>,
    pub avatar_graphic: Option<String>,
}

/// Fetches league standings for a tournament, sorted by points then GD.
pub async fn get_league_standings(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Vec<LeagueStandingRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, LeagueStandingRow>(
        r#"
        SELECT ls.player_id,
               COALESCE(NULLIF(u.full_name, ''), u.username, 'Unknown') AS player_name,
               ls.played::INT4 AS played, ls.won::INT4 AS won, ls.drawn::INT4 AS drawn, ls.lost::INT4 AS lost,
               ls.goals_for::INT4 AS goals_for, ls.goals_against::INT4 AS goals_against, ls.goal_diff::INT4 AS goal_diff, ls.points::INT4 AS points,
               ls.group_name,
               pp.avatar_graphic
        FROM League_Standings ls
        LEFT JOIN Users u ON ls.player_id = u.id
        LEFT JOIN Player_Profiles pp ON u.id = pp.user_id
        WHERE ls.tournament_id = $1
        ORDER BY ls.group_name ASC NULLS FIRST, ls.points DESC, ls.goal_diff DESC, ls.goals_for DESC, ls.won DESC, ls.drawn DESC
        "#,
    )
    .bind(tournament_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Detailed player stats row aggregated per tournament.
#[allow(dead_code)]
#[derive(FromRow, Serialize)]
pub struct TournamentPlayerStatRow {
    pub player_id: Uuid,
    pub player_name: String,
    pub avatar_graphic: Option<String>,
    pub played: i32,
    pub won: i32,
    pub drawn: i32,
    pub lost: i32,
    pub goals_for: i32,
    pub goals_against: i32,
    pub points: i32,
    pub passes_completed: i32,
    pub passes_attempted: i32,
    pub tackles: i32,
    pub interceptions: i32,
    pub clean_sheets: i32,
}

/// Fetches aggregated player stats (goals, passes, tackles, clean sheets) for a tournament.
pub async fn get_tournament_player_stats(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Vec<TournamentPlayerStatRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TournamentPlayerStatRow>(
        r#"
        SELECT 
            ls.player_id,
            COALESCE(NULLIF(u.full_name, ''), u.username, 'Unknown') AS player_name,
            pp.avatar_graphic,
            ls.played::INT4 AS played,
            ls.won::INT4 AS won,
            ls.drawn::INT4 AS drawn,
            ls.lost::INT4 AS lost,
            ls.goals_for::INT4 AS goals_for,
            ls.goals_against::INT4 AS goals_against,
            ls.points::INT4 AS points,
            COALESCE(SUM(mr.passes_completed), 0)::INT4 AS passes_completed,
            COALESCE(SUM(mr.passes_attempted), 0)::INT4 AS passes_attempted,
            COALESCE(SUM(mr.tackles), 0)::INT4 AS tackles,
            COALESCE(SUM(mr.interceptions), 0)::INT4 AS interceptions,
            COALESCE(SUM(CASE WHEN mr.goals_against = 0 AND mr.id IS NOT NULL THEN 1 ELSE 0 END), 0)::INT4 AS clean_sheets
        FROM League_Standings ls
        LEFT JOIN Users u ON ls.player_id = u.id
        LEFT JOIN Player_Profiles pp ON u.id = pp.user_id
        LEFT JOIN T_Matches tm ON tm.tournament_id = ls.tournament_id
        LEFT JOIN Match_Records mr ON mr.t_match_id = tm.id AND mr.player_id = ls.player_id AND mr.verification_status = 'approved' AND mr.deleted_at IS NULL
        WHERE ls.tournament_id = $1
        GROUP BY ls.player_id, u.full_name, u.username, pp.avatar_graphic, ls.played, ls.won, ls.drawn, ls.lost, ls.goals_for, ls.goals_against, ls.points
        ORDER BY ls.points DESC, ls.goals_for DESC
        "#,
    )
    .bind(tournament_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Initializes league standings rows for all participants when a tournament starts.
pub async fn initialize_league_standings(
    pool: &PgPool,
    tournament_id: Uuid,
    player_ids: &[Uuid],
) -> Result<(), sqlx::Error> {
    if player_ids.is_empty() {
        return Ok(());
    }

    let mut query_builder = sqlx::QueryBuilder::new(
        "INSERT INTO League_Standings (tournament_id, player_id) "
    );
    
    query_builder.push_values(player_ids, |mut b, pid| {
        b.push_bind(tournament_id)
         .push_bind(*pid);
    });

    query_builder.push(" ON CONFLICT (tournament_id, player_id) DO NOTHING");

    query_builder.build().execute(pool).await?;

    Ok(())
}

/// Initializes league standings with explicit group assignments for group_knockout tournaments.
pub async fn initialize_league_standings_with_groups(
    pool: &PgPool,
    tournament_id: Uuid,
    player_groups: &[(Uuid, String)],
) -> Result<(), sqlx::Error> {
    if player_groups.is_empty() {
        return Ok(());
    }

    let mut query_builder = sqlx::QueryBuilder::new(
        "INSERT INTO League_Standings (tournament_id, player_id, group_name) "
    );
    
    query_builder.push_values(player_groups, |mut b, (pid, gname)| {
        b.push_bind(tournament_id)
         .push_bind(*pid)
         .push_bind(gname);
    });

    query_builder.push(" ON CONFLICT (tournament_id, player_id) DO UPDATE SET group_name = EXCLUDED.group_name");

    query_builder.build().execute(pool).await?;

    Ok(())
}

pub async fn insert_tournament_participants(
    pool: &PgPool,
    tournament_id: Uuid,
    player_ids: &[Uuid],
) -> Result<(), sqlx::Error> {
    for pid in player_ids {
        sqlx::query(
            r#"
            INSERT INTO Tournament_Participants (tournament_id, player_id)
            VALUES ($1, $2)
            ON CONFLICT (tournament_id, player_id) DO NOTHING
            "#,
        )
        .bind(tournament_id)
        .bind(pid)
        .execute(pool)
        .await?;
    }

    Ok(())
}

/// Idempotent version of `update_league_standing`.
/// Updates a player's standing only if `last_processed_match_id` is NOT already the given t_match_id.
/// After updating, stamps `last_processed_match_id = t_match_id` to prevent double-counting
/// on any subsequent confirmation attempt for the same match.
pub async fn update_league_standing_guarded(
    pool: &PgPool,
    tournament_id: Uuid,
    t_match_id: Uuid,
    player_id: Uuid,
    goals_for: i32,
    goals_against: i32,
) -> Result<(), sqlx::Error> {
    let (won, drawn, lost) = if goals_for > goals_against {
        (1, 0, 0)
    } else if goals_for == goals_against {
        (0, 1, 0)
    } else {
        (0, 0, 1)
    };

    let query_str = r#"
        INSERT INTO League_Standings (
            tournament_id, player_id, played, won, drawn, lost, goals_for, goals_against, processed_match_ids, group_name, updated_at
        )
        VALUES ($6, $7, 1, $1, $2, $3, $4, $5, ARRAY[$8]::UUID[], (SELECT group_name FROM T_Matches WHERE id = $8), NOW())
        ON CONFLICT (tournament_id, player_id) DO UPDATE
        SET played        = League_Standings.played + 1,
            won           = League_Standings.won + $1,
            drawn         = League_Standings.drawn + $2,
            lost          = League_Standings.lost + $3,
            goals_for     = League_Standings.goals_for + $4,
            goals_against = League_Standings.goals_against + $5,
            processed_match_ids = array_append(COALESCE(League_Standings.processed_match_ids, ARRAY[]::UUID[]), $8),
            updated_at    = NOW()
        WHERE NOT COALESCE($8 = ANY(League_Standings.processed_match_ids), FALSE)
    "#;

    let res = sqlx::query(query_str)
        .bind(won)
        .bind(drawn)
        .bind(lost)
        .bind(goals_for)
        .bind(goals_against)
        .bind(tournament_id)
        .bind(player_id)
        .bind(t_match_id)
        .execute(pool)
        .await;

    match res {
        Ok(_) => Ok(()),
        Err(e) if e.to_string().contains("processed_match_ids") => {
            // Column is missing on unmigrated database: create it and retry
            let _ = sqlx::query("ALTER TABLE public.league_standings ADD COLUMN IF NOT EXISTS processed_match_ids UUID[] DEFAULT '{}'::UUID[];")
                .execute(pool)
                .await;

            sqlx::query(query_str)
                .bind(won)
                .bind(drawn)
                .bind(lost)
                .bind(goals_for)
                .bind(goals_against)
                .bind(tournament_id)
                .bind(player_id)
                .bind(t_match_id)
                .execute(pool)
                .await
                .map(|_| ())
        }
        Err(e) => Err(e),
    }
}

/// Advances the winner of a knockout match to the correct slot in the next round.
///
/// Algorithm:
///   next_round  = current_round + 1
///   next_slot   = ceil(current_match_number / 2)  (integer: (match_number + 1) / 2)
///
/// If a T_Match row already exists for (tournament_id, next_round, next_slot) with one player slot empty,
/// fills that slot with `winner_id`.
/// If no row exists, creates a new T_Match with `player_1_id = winner_id` (player_2 arrives when sibling completes).
pub async fn advance_knockout_winner(
    pool: &PgPool,
    tournament_id: Uuid,
    _completed_match_id: Uuid,
    current_round: i32,
    current_match_number: i32,
    winner_id: Uuid,
) -> Result<(), sqlx::Error> {
    // Find the total rounds from Matchdays to safely determine if current round is the final
    let max_round: i32 = sqlx::query_scalar(
        "SELECT COALESCE(MAX(matchday_number), 1)::INT4 FROM Matchdays WHERE tournament_id = $1"
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await
    .unwrap_or(1);

    if current_round < max_round {
        let next_round = current_round + 1;
        let next_slot  = (current_match_number + 1) / 2;

        // Check if a TBD row exists for this next slot
        let existing: Option<(Uuid, Option<Uuid>, Option<Uuid>)> = sqlx::query_as(
            r#"
            SELECT id, player_1_id, player_2_id
            FROM T_Matches
            WHERE tournament_id = $1 AND round_number = $2 AND match_number = $3
            LIMIT 1
            "#,
        )
        .bind(tournament_id)
        .bind(next_round)
        .bind(next_slot)
        .fetch_optional(pool)
        .await?;

        if let Some((row_id, p1, p2)) = existing {
            // Prevent double advancement if winner is already assigned
            if p1 == Some(winner_id) || p2 == Some(winner_id) {
                // already advanced
            } else if p1.is_none() {
                sqlx::query(
                    "UPDATE T_Matches SET player_1_id = $1, updated_at = NOW() WHERE id = $2"
                )
                .bind(winner_id)
                .bind(row_id)
                .execute(pool)
                .await?;
            } else if p2.is_none() {
                sqlx::query(
                    "UPDATE T_Matches SET player_2_id = $1, updated_at = NOW() WHERE id = $2"
                )
                .bind(winner_id)
                .bind(row_id)
                .execute(pool)
                .await?;
            }
        } else {
            // Fetch matchday_id for the next round
            let matchday_id: Option<Uuid> = sqlx::query_scalar(
                "SELECT id FROM Matchdays WHERE tournament_id = $1 AND matchday_number = $2 LIMIT 1"
            )
            .bind(tournament_id)
            .bind(next_round)
            .fetch_optional(pool)
            .await
            .unwrap_or(None);
            
            let scheduled_at: Option<chrono::DateTime<chrono::Utc>> = if let Some(md_id) = matchday_id {
                let md_date: Option<chrono::NaiveDate> = sqlx::query_scalar("SELECT scheduled_date FROM Matchdays WHERE id = $1")
                    .bind(md_id)
                    .fetch_optional(pool)
                    .await
                    .unwrap_or(None)
                    .flatten();
                md_date.map(|d| d.and_hms_opt(12, 0, 0).unwrap().and_utc())
            } else {
                None
            };

            // No TBD row yet — create one with winner as player_1; sibling will fill player_2
            let new_id = Uuid::new_v4();
            sqlx::query(
                r#"
                INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, match_number, status, matchday_id, scheduled_at)
                VALUES ($1, $2, $3, NULL, $4, $5, 'scheduled', $6, $7)
                "#,
            )
            .bind(new_id)
            .bind(tournament_id)
            .bind(winner_id)
            .bind(next_round)
            .bind(next_slot)
            .bind(matchday_id)
            .bind(scheduled_at)
            .execute(pool)
            .await?;
        }
    }

    // Now check if tournament is complete by ensuring no pending active matches remain
    let pending_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM T_Matches WHERE tournament_id = $1 AND status NOT IN ('completed', 'bye')"
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await
    .unwrap_or(1);

    if current_round >= max_round && pending_count == 0 {
        // Tournament is complete! Mark it as completed.
        let _ = sqlx::query("UPDATE Tournaments SET status = 'completed', updated_at = NOW() WHERE id = $1")
            .bind(tournament_id)
            .execute(pool)
            .await;
    }

    Ok(())
}

