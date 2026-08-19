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
// Tournament Bracket
// ─────────────────────────────────────────────────────────────────────────────

/// A single T_Match row fetched from the database.
#[derive(FromRow, Serialize)]
pub struct TMatchRow {
    pub id: Uuid,
    pub player_1_id: Option<Uuid>,
    pub player_1_name: Option<String>,
    pub player_2_id: Option<Uuid>,
    pub player_2_name: Option<String>,
    pub round_number: i32,
    pub status: String,
    /// The winning player's UUID (NULL when match is not yet completed).
    pub winner_player_id: Option<Uuid>,
    pub player_1_score: Option<i32>,
    pub player_2_score: Option<i32>,
    pub group_name: Option<String>,
    pub player_1_rating: Option<i32>,
    pub player_2_rating: Option<i32>,
    pub player_1_avatar: Option<String>,
    pub player_2_avatar: Option<String>,
    pub matchday_id: Option<Uuid>,
    pub scheduled_at: Option<chrono::DateTime<chrono::Utc>>,
    pub original_scheduled_at: Option<chrono::DateTime<chrono::Utc>>,
    pub is_rescheduled: bool,
    pub reschedule_reason: Option<String>,
    pub matchday_number: Option<i32>,
    pub matchday_scheduled_date: Option<chrono::NaiveDate>,
    pub reschedule_count: i32,
}

/// Fetches all T_Matches for a tournament, ordered by round number.
pub async fn get_tournament_bracket(
    pool: &PgPool,
    tournament_id: Uuid,
    matchday_id: Option<Uuid>,
) -> Result<Vec<TMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TMatchRow>(
        r#"
        SELECT
            m.id,
            m.player_1_id,
            COALESCE(NULLIF(u1.full_name, ''), u1.username) AS player_1_name,
            m.player_2_id,
            COALESCE(NULLIF(u2.full_name, ''), u2.username) AS player_2_name,
            m.round_number::INT4 AS round_number,
            m.status,
            CASE
                WHEN COALESCE(m.player_1_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_against ELSE NULL END) >
                     COALESCE(m.player_2_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_against ELSE NULL END)
                     THEN m.player_1_id
                WHEN COALESCE(m.player_2_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_against ELSE NULL END) >
                     COALESCE(m.player_1_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_against ELSE NULL END)
                     THEN m.player_2_id
                WHEN mr.result = 'win'  THEN mr.player_id
                WHEN mr.result = 'loss' THEN mr.opponent_id
                ELSE NULL
            END AS winner_player_id,
            COALESCE(m.player_1_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_against ELSE NULL END)::INT4 AS player_1_score,
            COALESCE(m.player_2_score, CASE WHEN mr.id IS NOT NULL AND mr.player_id = m.player_2_id THEN mr.goals_for WHEN mr.id IS NOT NULL AND mr.player_id = m.player_1_id THEN mr.goals_against ELSE NULL END)::INT4 AS player_2_score,
            m.group_name,
            cm1.skill_rating AS player_1_rating,
            cm2.skill_rating AS player_2_rating,
            pp1.avatar_graphic AS player_1_avatar,
            pp2.avatar_graphic AS player_2_avatar,
            m.matchday_id,
            m.scheduled_at,
            m.original_scheduled_at,
            m.is_rescheduled,
            m.reschedule_reason,
            m.reschedule_count,
            md.matchday_number::INT4 as "matchday_number: i32",
            md.scheduled_date as "matchday_scheduled_date: chrono::NaiveDate"
        FROM T_Matches m
        LEFT JOIN Users u1 ON m.player_1_id = u1.id
        LEFT JOIN Users u2 ON m.player_2_id = u2.id
        LEFT JOIN Player_Profiles pp1 ON u1.id = pp1.user_id
        LEFT JOIN Player_Profiles pp2 ON u2.id = pp2.user_id
        LEFT JOIN LATERAL (SELECT * FROM Match_Records WHERE t_match_id = m.id LIMIT 1) mr ON true
        LEFT JOIN Tournaments t ON m.tournament_id = t.id
        LEFT JOIN Club_Memberships cm1 ON cm1.player_id = m.player_1_id AND cm1.club_id = t.club_id
        LEFT JOIN Club_Memberships cm2 ON cm2.player_id = m.player_2_id AND cm2.club_id = t.club_id
        LEFT JOIN Matchdays md ON m.matchday_id = md.id
        WHERE m.tournament_id = $1 AND ($2::UUID IS NULL OR m.matchday_id = $2)
        ORDER BY m.round_number ASC, m.created_at ASC
        "#,
    )
    .bind(tournament_id)
    .bind(matchday_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}



// ─────────────────────────────────────────────────────────────────────────────
// Tournament CRUD
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a tournament row in the database.
pub async fn create_tournament(
    pool: &PgPool,
    club_id: Uuid,
    name: &str,
    format_type: &str,
    rules_config: &serde_json::Value,
    start_date: Option<chrono::NaiveDate>,
    end_date: Option<chrono::NaiveDate>,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO Tournaments (id, club_id, name, format_type, status, rules_config, start_date, end_date)
        VALUES ($1, $2, $3, $4, 'draft', $5, $6, $7)
        "#,
    )
    .bind(id)
    .bind(club_id)
    .bind(name)
    .bind(format_type)
    .bind(rules_config)
    .bind(start_date)
    .bind(end_date)
    .execute(pool)
    .await?;

    Ok(id)
}

/// Tournament summary row.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct TournamentRow {
    pub id: Uuid,
    pub name: String,
    pub format_type: String,
    pub status: String,
    pub participant_count: i64,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches all tournaments for a club.
/// participant_count is the number of distinct registered players (from League_Standings),
/// not the raw match count (which was incorrect previously).
pub async fn get_club_tournaments(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<TournamentRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TournamentRow>(
        r#"
        SELECT t.id, t.name, t.format_type, t.status,
               COALESCE(
                   (SELECT COUNT(DISTINCT ls.player_id) FROM League_Standings ls WHERE ls.tournament_id = t.id),
                   (SELECT COUNT(DISTINCT tm_p.player_id)
                    FROM (
                        SELECT player_1_id AS player_id FROM T_Matches WHERE tournament_id = t.id
                        UNION
                        SELECT player_2_id AS player_id FROM T_Matches WHERE tournament_id = t.id
                    ) tm_p WHERE tm_p.player_id IS NOT NULL)
               ) AS participant_count,
               t.created_at
        FROM Tournaments t
        WHERE t.club_id = $1 AND t.deleted_at IS NULL
        ORDER BY t.created_at DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Updates tournament status (draft → active → completed).
pub async fn update_tournament_status(
    pool: &PgPool,
    tournament_id: Uuid,
    status: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"UPDATE Tournaments SET status = $1, updated_at = NOW() WHERE id = $2"#,
    )
    .bind(status)
    .bind(tournament_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Inserts a T_Match fixture into the database.
/// match_number identifies the fixture's slot within its round for knockout advancement.
pub async fn insert_tournament_match(
    pool: &PgPool,
    tournament_id: Uuid,
    player_1_id: Option<Uuid>,
    player_2_id: Option<Uuid>,
    round_number: i32,
    match_number: i32,
    group_name: Option<&str>,
    matchday_id: Option<Uuid>,
    scheduled_at: Option<chrono::DateTime<chrono::Utc>>,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, match_number, status, group_name, matchday_id, scheduled_at)
        VALUES ($1, $2, $3, $4, $5, $6, 'scheduled', $7, $8, $9)
        "#,
    )
    .bind(id)
    .bind(tournament_id)
    .bind(player_1_id)
    .bind(player_2_id)
    .bind(round_number)
    .bind(match_number)
    .bind(group_name)
    .bind(matchday_id)
    .bind(scheduled_at)
    .execute(pool)
    .await?;

    Ok(id)
}

pub async fn insert_tournament_matches_batch(
    pool: &PgPool,
    tournament_id: Uuid,
    matches: &[(Option<Uuid>, Option<Uuid>, i32, i32, Option<String>, Option<Uuid>, Option<chrono::DateTime<chrono::Utc>>)],
) -> Result<(), sqlx::Error> {
    if matches.is_empty() {
        return Ok(());
    }

    // Split into chunks if there are too many matches to avoid exceeding PostgreSQL's bind limit (65535)
    // 10 binds per row. 65535 / 10 = ~6553. Using 1000 for safety.
    for chunk in matches.chunks(1000) {
        let mut query_builder = sqlx::QueryBuilder::new(
            "INSERT INTO T_Matches (id, tournament_id, player_1_id, player_2_id, round_number, match_number, status, group_name, matchday_id, scheduled_at) "
        );

        query_builder.push_values(chunk, |mut b, m| {
            b.push_bind(Uuid::new_v4())
             .push_bind(tournament_id)
             .push_bind(m.0)
             .push_bind(m.1)
             .push_bind(m.2 as i16) // round_number is smallint
             .push_bind(m.3)
             .push_bind("scheduled")
             .push_bind(m.4.clone())
             .push_bind(m.5)
             .push_bind(m.6);
        });

        let query = query_builder.build();
        query.execute(pool).await?;
    }

    Ok(())
}

/// Batch inserts a list of FixtureNodes into T_Matches.
pub async fn save_tournament_fixtures(
    pool: &PgPool,
    tournament_id: Uuid,
    fixtures: Vec<crate::domain::tournament::FixtureNode>,
    matchday_ids: &[Uuid],
    round_offset: u32,
) -> Result<(), sqlx::Error> {
    let batch_matches: Vec<_> = fixtures.iter().map(|f| {
        let p1_id = f.player_1.as_ref().map(|p| p.id);
        let p2_id = f.player_2.as_ref().map(|p| p.id);
        let idx = f.round_number.saturating_sub(round_offset).saturating_sub(1) as usize;
        let md_id = matchday_ids.get(idx).copied();
        (p1_id, p2_id, f.round_number as i32, f.match_number as i32, None, md_id, None)
    }).collect();

    insert_tournament_matches_batch(pool, tournament_id, &batch_matches).await?;
    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// IMP-7: Auto-Advancement SQL Extract
// ─────────────────────────────────────────────────────────────────────────────

pub struct AdvancementContext {
    pub t_match_id: Uuid,
    pub tournament_id: Uuid,
    pub player_1_id: Option<Uuid>,
    pub player_2_id: Option<Uuid>,
    pub round_number: i32,
    pub match_number: i32,
    pub group_name: Option<String>,
    pub match_status: String,
    pub matchday_id: Option<Uuid>,
    pub format_type: String,
    pub mr_id: Option<Uuid>,
    pub mr_player_id: Option<Uuid>,
    pub goals_for: Option<i32>,
    pub goals_against: Option<i32>,
}

pub async fn get_advancement_context(pool: &PgPool, match_id: Uuid) -> Result<Option<AdvancementContext>, sqlx::Error> {
    sqlx::query_as!(
        AdvancementContext,
        r#"
        SELECT
            m.id          AS t_match_id,
            m.tournament_id,
            m.player_1_id,
            m.player_2_id,
            m.round_number,
            m.match_number,
            m.group_name,
            m.status      AS "match_status: String",
            m.matchday_id,
            t.format_type,
            mr.id         AS "mr_id?: Uuid",
            mr.player_id  AS "mr_player_id?: Uuid",
            mr.goals_for  AS "goals_for?: i32",
            mr.goals_against AS "goals_against?: i32"
        FROM T_Matches m
        LEFT JOIN Match_Records mr ON mr.t_match_id = m.id
        LEFT JOIN Tournaments t   ON t.id  = m.tournament_id
        WHERE m.id = $1 OR mr.id = $1
        ORDER BY mr.created_at ASC
        LIMIT 1
        "#,
        match_id
    )
    .fetch_optional(pool)
    .await
}

pub async fn get_match_scores(pool: &PgPool, match_id: Uuid) -> Result<Option<(Option<i32>, Option<i32>)>, sqlx::Error> {
    let row = sqlx::query!(
        "SELECT player_1_score, player_2_score FROM T_Matches WHERE id = $1",
        match_id
    )
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|r| (r.player_1_score.map(|s| s as i32), r.player_2_score.map(|s| s as i32))))
}

pub async fn update_match_scores_completed(pool: &PgPool, match_id: Uuid, p1_goals: i32, p2_goals: i32) -> Result<(), sqlx::Error> {
    sqlx::query!(
        "UPDATE T_Matches SET player_1_score = $1, player_2_score = $2, status = 'completed' WHERE id = $3",
        p1_goals as i16, p2_goals as i16, match_id
    )
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn get_pending_matches_count(pool: &PgPool, tournament_id: Uuid) -> Result<i64, sqlx::Error> {
    let count: Option<i64> = sqlx::query_scalar!(
        "SELECT COUNT(*) FROM T_Matches WHERE tournament_id = $1 AND status NOT IN ('completed', 'bye')",
        tournament_id
    )
    .fetch_one(pool)
    .await?;
    Ok(count.unwrap_or(0))
}

pub async fn get_max_group_round(pool: &PgPool, tournament_id: Uuid) -> Result<Option<i32>, sqlx::Error> {
    let max = sqlx::query_scalar!(
        "SELECT MAX(round_number) FROM T_Matches WHERE tournament_id = $1 AND group_name IS NOT NULL",
        tournament_id
    )
    .fetch_optional(pool)
    .await?
    .flatten()
    .map(|r| r as i32);
    Ok(max)
}
