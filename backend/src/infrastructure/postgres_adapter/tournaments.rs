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
            m.reschedule_count::INT4 AS reschedule_count,
            md.matchday_number::INT4 AS matchday_number,
            md.scheduled_date AS matchday_scheduled_date
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
    matchday_gap_days: Option<i16>,
    allow_multi_match_per_matchday: Option<bool>,
) -> Result<Uuid, sqlx::Error> {
    let id = Uuid::new_v4();
    
    let gap = matchday_gap_days.unwrap_or(7);
    let multi_match = allow_multi_match_per_matchday.unwrap_or(false);

    sqlx::query(
        r#"
        INSERT INTO Tournaments (id, club_id, name, format_type, status, rules_config, start_date, end_date, matchday_gap_days, allow_multi_match_per_matchday)
        VALUES ($1, $2, $3, $4, 'draft', $5, $6, $7, $8, $9)
        "#,
    )
    .bind(id)
    .bind(club_id)
    .bind(name)
    .bind(format_type)
    .bind(rules_config)
    .bind(start_date)
    .bind(end_date)
    .bind(gap)
    .bind(multi_match)
    .execute(pool)
    .await?;

    Ok(id)
}

/// Tournament summary row.
#[allow(dead_code)]
#[derive(FromRow, Serialize)]
pub struct TournamentRow {
    pub id: Uuid,
    pub name: String,
    pub format_type: String,
    pub status: String,
    pub participant_count: i64,
    pub club_id: Uuid,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub end_date: Option<chrono::NaiveDate>,
    pub matchday_gap_days: i16,
    pub allow_multi_match_per_matchday: bool,
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
        SELECT t.id, t.name, t.format_type, t.status, t.club_id,
               COALESCE(
                   (SELECT COUNT(DISTINCT ls.player_id) FROM League_Standings ls WHERE ls.tournament_id = t.id),
                   (SELECT COUNT(DISTINCT tm_p.player_id)
                    FROM (
                        SELECT player_1_id AS player_id FROM T_Matches WHERE tournament_id = t.id
                        UNION
                        SELECT player_2_id AS player_id FROM T_Matches WHERE tournament_id = t.id
                    ) tm_p WHERE tm_p.player_id IS NOT NULL)
               ) AS participant_count,
               t.created_at, t.end_date, t.matchday_gap_days, t.allow_multi_match_per_matchday
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

/// Retrieves tournament settings.
pub async fn get_tournament_settings(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Option<(Option<chrono::NaiveDate>, Option<chrono::NaiveDate>, i16, bool)>, sqlx::Error> {
    let row = sqlx::query(
        r#"
        SELECT start_date, end_date, matchday_gap_days, allow_multi_match_per_matchday 
        FROM Tournaments 
        WHERE id = $1
        "#,
    )
    .bind(tournament_id)
    .fetch_optional(pool)
    .await?;

    if let Some(r) = row {
        Ok(Some((
            r.try_get("start_date")?,
            r.try_get("end_date")?,
            r.try_get("matchday_gap_days")?,
            r.try_get("allow_multi_match_per_matchday")?,
        )))
    } else {
        Ok(None)
    }
}

/// Updates tournament settings.
pub async fn update_tournament_settings(
    pool: &PgPool,
    tournament_id: Uuid,
    matchday_gap_days: Option<i16>,
    end_date: Option<Option<chrono::NaiveDate>>,
    allow_multi_match_per_matchday: Option<bool>,
) -> Result<(), sqlx::Error> {
    let mut query = String::from("UPDATE Tournaments SET updated_at = NOW()");
    
    if matchday_gap_days.is_some() {
        query.push_str(", matchday_gap_days = $2");
    }
    if end_date.is_some() {
        query.push_str(", end_date = $3");
    }
    if allow_multi_match_per_matchday.is_some() {
        query.push_str(", allow_multi_match_per_matchday = $4");
    }
    
    query.push_str(" WHERE id = $1");

    let mut q = sqlx::query(&query).bind(tournament_id);
    
    // Binding dynamically for pg requires exact index matching, which sqlx::query doesn't easily support dynamically. 
    // We'll just construct the specific query or use COALESCE.
    // Let's rewrite it safely.
    let _ = q; // Ignore above
    
    sqlx::query(
        r#"
        UPDATE Tournaments 
        SET 
            updated_at = NOW(),
            matchday_gap_days = COALESCE($2, matchday_gap_days),
            end_date = CASE WHEN $3 THEN $4 ELSE end_date END,
            allow_multi_match_per_matchday = COALESCE($5, allow_multi_match_per_matchday)
        WHERE id = $1
        "#,
    )
    .bind(tournament_id)
    .bind(matchday_gap_days)
    .bind(end_date.is_some())
    .bind(end_date.flatten())
    .bind(allow_multi_match_per_matchday)
    .execute(pool)
    .await?;

    Ok(())
}

/// Recalculates and updates matchday dates for a tournament.
pub async fn rebuild_remaining_matchdays(
    pool: &PgPool,
    tournament_id: Uuid,
    end_date: Option<chrono::NaiveDate>,
    gap_days: i16,
    allow_multi_match: bool,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    // 1. Identify untouched (partially or fully completed) matchdays
    // A matchday is untouched if it has AT LEAST 1 completed match.
    // We also need its scheduled_date to find the anchor date.
    let untouched_matchdays = sqlx::query!(
        r#"
        SELECT md.id, md.scheduled_date, md.matchday_number
        FROM matchdays md
        WHERE md.tournament_id = $1 
          AND EXISTS (
              SELECT 1 FROM t_matches tm 
              WHERE tm.matchday_id = md.id AND tm.status IN ('completed', 'disputed', 'forfeit', 'bye')
          )
        ORDER BY md.matchday_number ASC
        "#,
        tournament_id
    )
    .fetch_all(&mut *tx)
    .await?;

    // 2. Identify touched (completely pending) matchdays
    let touched_matchdays = sqlx::query!(
        r#"
        SELECT md.id, md.matchday_number
        FROM matchdays md
        WHERE md.tournament_id = $1
          AND NOT EXISTS (
              SELECT 1 FROM t_matches tm 
              WHERE tm.matchday_id = md.id AND tm.status IN ('completed', 'disputed', 'forfeit', 'bye')
          )
        ORDER BY md.matchday_number ASC
        "#,
        tournament_id
    )
    .fetch_all(&mut *tx)
    .await?;

    if touched_matchdays.is_empty() {
        // No remaining matchdays to rebuild
        tx.commit().await?;
        return Ok(());
    }

    // 3. Determine Anchor Date
    // Anchor date = max(today, last_untouched_date + gap)
    let today = chrono::Utc::now().naive_utc().date();
    let anchor_date = if let Some(last_untouched) = untouched_matchdays.last() {
        if let Some(d) = last_untouched.scheduled_date {
            let next_date = d.checked_add_signed(chrono::Duration::days(gap_days as i64)).unwrap_or(today);
            if next_date > today { next_date } else { today }
        } else {
            today
        }
    } else {
        // No untouched matchdays, so start from today (or tournament start_date)
        // Let's fetch tournament start_date
        let t_start: Option<chrono::NaiveDate> = sqlx::query_scalar!(
            "SELECT start_date FROM Tournaments WHERE id = $1",
            tournament_id
        )
        .fetch_optional(&mut *tx)
        .await?.flatten();
        
        let mut st = t_start.unwrap_or(today);
        if st < today { st = today; }
        st
    };

    // 4. Extract pending fixtures from touched matchdays
    let touched_ids: Vec<Uuid> = touched_matchdays.iter().map(|m| m.id).collect();
    
    // We need to fetch t_matches, grouped by round_number, ordered by round_number
    #[derive(sqlx::FromRow)]
    struct PendingFixture {
        id: Uuid,
        round_number: i16,
    }
    
    let pending_fixtures = sqlx::query_as::<_, PendingFixture>(
        r#"
        SELECT id, round_number 
        FROM t_matches
        WHERE matchday_id = ANY($1)
        ORDER BY round_number ASC
        "#
    )
    .bind(&touched_ids)
    .fetch_all(&mut *tx)
    .await?;
    
    if pending_fixtures.is_empty() {
        tx.commit().await?;
        return Ok(());
    }

    // Determine max round_number from pending fixtures
    let max_round = pending_fixtures.last().map(|f| f.round_number as usize).unwrap_or(1);
    let min_round = pending_fixtures.first().map(|f| f.round_number as usize).unwrap_or(1);
    let rounds_to_pack = max_round - min_round + 1;

    // 5. Delete touched matchdays
    sqlx::query(
        "DELETE FROM matchdays WHERE id = ANY($1)"
    )
    .bind(&touched_ids)
    .execute(&mut *tx)
    .await?;

    // 6. Calculate new matchdays
    let num_mds = if allow_multi_match {
        match end_date {
            Some(e) => {
                let total_days = (e - anchor_date).num_days();
                if total_days >= 0 {
                    (total_days / (gap_days as i64) + 1) as usize
                } else {
                    1
                }
            }
            None => rounds_to_pack,
        }
    } else {
        rounds_to_pack
    };
    
    let num_matchdays = std::cmp::max(1, std::cmp::min(num_mds, rounds_to_pack));
    
    let new_dates = crate::domain::tournament::distribute_matchday_dates(
        Some(anchor_date),
        end_date,
        num_matchdays,
        Some(gap_days as i64),
    );
    
    let packing = crate::domain::tournament::pack_rounds_into_matchdays(rounds_to_pack, num_matchdays);
    
    // Determine starting matchday number
    let starting_md_num = untouched_matchdays.last().map(|m| m.matchday_number).unwrap_or(0) + 1;
    
    // 7. Create new matchdays and re-assign fixtures
    for (i, round_groups) in packing.into_iter().enumerate() {
        let md_date = new_dates.get(i).copied().flatten();
        let md_num = starting_md_num + (i as i16);
        
        let new_md_id: Uuid = sqlx::query_scalar!(
            r#"
            INSERT INTO matchdays (tournament_id, matchday_number, scheduled_date, status)
            VALUES ($1, $2, $3, 'upcoming')
            RETURNING id
            "#,
            tournament_id, md_num, md_date
        )
        .fetch_one(&mut *tx)
        .await?;
        
        // Find which fixtures belong to this matchday
        // packing returns indices relative to 1..rounds_to_pack.
        // We need to map these to actual round_numbers.
        let actual_rounds: Vec<i16> = round_groups.iter().map(|&r| (r as usize - 1 + min_round) as i16).collect();
        
        let mut fixture_ids = Vec::new();
        for fix in &pending_fixtures {
            if actual_rounds.contains(&fix.round_number) {
                fixture_ids.push(fix.id);
            }
        }
        
        if !fixture_ids.is_empty() {
            let scheduled_at = md_date.map(|d| {
                chrono::DateTime::<chrono::Utc>::from_naive_utc_and_offset(
                    d.and_hms_opt(0, 0, 0).unwrap(), 
                    chrono::Utc
                )
            });
            
            sqlx::query(
                "UPDATE t_matches SET matchday_id = $1, scheduled_at = $2, updated_at = NOW() WHERE id = ANY($3)"
            )
            .bind(new_md_id)
            .bind(scheduled_at)
            .bind(&fixture_ids)
            .execute(&mut *tx)
            .await?;
        }
    }

    tx.commit().await?;
    Ok(())
}

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
             .push_bind(m.2)
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

#[derive(FromRow)]
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
    sqlx::query_as::<_, AdvancementContext>(
        r#"
        SELECT
            m.id          AS t_match_id,
            m.tournament_id,
            m.player_1_id,
            m.player_2_id,
            m.round_number::INT4 AS round_number,
            m.match_number::INT4 AS match_number,
            m.group_name,
            m.status      AS match_status,
            m.matchday_id,
            t.format_type,
            mr.id         AS mr_id,
            mr.player_id  AS mr_player_id,
            mr.goals_for::INT4  AS goals_for,
            mr.goals_against::INT4 AS goals_against
        FROM T_Matches m
        LEFT JOIN Match_Records mr ON mr.t_match_id = m.id
            AND mr.deleted_at IS NULL
            AND mr.verification_status = 'approved'
        LEFT JOIN Tournaments t   ON t.id  = m.tournament_id
        WHERE m.id = $1 OR mr.id = $1
        ORDER BY mr.created_at DESC NULLS LAST
        LIMIT 1
        "#,
    )
    .bind(match_id)
    .fetch_optional(pool)
    .await
}

pub async fn get_match_scores(pool: &PgPool, match_id: Uuid) -> Result<Option<(Option<i32>, Option<i32>)>, sqlx::Error> {
    let row: Option<(Option<i32>, Option<i32>)> = sqlx::query_as(
        "SELECT player_1_score::INT4, player_2_score::INT4 FROM T_Matches WHERE id = $1",
    )
    .bind(match_id)
    .fetch_optional(pool)
    .await?;

    Ok(row)
}

pub async fn update_match_scores_completed(pool: &PgPool, match_id: Uuid, p1_goals: i32, p2_goals: i32) -> Result<(), sqlx::Error> {
    sqlx::query(
        "UPDATE T_Matches SET player_1_score = $1, player_2_score = $2, status = 'completed' WHERE id = $3",
    )
    .bind(p1_goals as i16)
    .bind(p2_goals as i16)
    .bind(match_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn get_pending_matches_count(pool: &PgPool, tournament_id: Uuid) -> Result<i64, sqlx::Error> {
    let count: Option<i64> = sqlx::query_scalar(
        "SELECT COUNT(*) FROM T_Matches WHERE tournament_id = $1 AND status NOT IN ('completed', 'bye')",
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;
    Ok(count.unwrap_or(0))
}

pub async fn get_max_group_round(pool: &PgPool, tournament_id: Uuid) -> Result<Option<i32>, sqlx::Error> {
    let max: Option<i32> = sqlx::query_scalar(
        "SELECT MAX(round_number)::INT4 FROM T_Matches WHERE tournament_id = $1 AND group_name IS NOT NULL",
    )
    .bind(tournament_id)
    .fetch_optional(pool)
    .await?
    .flatten();
    Ok(max)
}
