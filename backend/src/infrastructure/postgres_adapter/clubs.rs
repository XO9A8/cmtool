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
// Club Leaderboard
// ─────────────────────────────────────────────────────────────────────────────

/// Club leaderboard database row representation.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct LeaderboardRow {
    pub user_id: Uuid,
    pub username: String,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
    pub avatar_graphic: Option<String>,
}

/// Fetches real-time club player rankings sorted by skill rating.
pub async fn get_club_leaderboard_db(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<LeaderboardRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, LeaderboardRow>(
        r#"
        SELECT u.id as user_id, COALESCE(NULLIF(u.full_name, ''), u.username) AS username, COALESCE(cm.skill_rating, 1000) as skill_rating, 
               COALESCE(cm.form_rating, 50.0)::FLOAT8 as form_rating, cm.play_style, pp.avatar_graphic
        FROM Club_Memberships cm
        JOIN Users u ON cm.player_id = u.id
        LEFT JOIN Player_Profiles pp ON u.id = pp.user_id
        WHERE cm.club_id = $1
        ORDER BY COALESCE(cm.skill_rating, 1000) DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

// ─────────────────────────────────────────────────────────────────────────────
// Clubs Management
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a new club and adds the owner as an admin member. Returns the new club UUID.
pub async fn create_club(
    pool: &PgPool,
    name: &str,
    invite_code: &str,
    owner_id: Uuid,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    // Auto-provision user & profile if not existing (prevents foreign key violation)
    sqlx::query(
        r#"
        INSERT INTO Users (id, username)
        VALUES ($1, 'user_' || SUBSTRING($1::text, 1, 8))
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(owner_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id)
        VALUES ($1)
        ON CONFLICT (user_id) DO NOTHING
        "#,
    )
    .bind(owner_id)
    .execute(&mut *tx)
    .await?;

    let club_id = Uuid::new_v4();
    sqlx::query(
        r#"INSERT INTO Clubs (id, name, invite_code, owner_id) VALUES ($1, $2, $3, $4)"#,
    )
    .bind(club_id)
    .bind(name)
    .bind(invite_code)
    .bind(owner_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"INSERT INTO Club_Memberships (player_id, club_id, role) VALUES ($1, $2, 'admin')"#,
    )
    .bind(owner_id)
    .bind(club_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(club_id)
}

/// Joins a player to a club after validating the invite code. Returns an error if code mismatches.
pub async fn join_club_by_invite(
    pool: &PgPool,
    player_id: Uuid,
    username: &str,
    invite_code: &str,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    let row: Option<(Uuid,)> = sqlx::query_as(
        r#"SELECT id FROM Clubs WHERE invite_code = $1 AND deleted_at IS NULL"#,
    )
    .bind(invite_code)
    .fetch_optional(&mut *tx)
    .await?;

    let row = row.ok_or(sqlx::Error::RowNotFound)?;
    let club_id = row.0;

    sqlx::query(r#"
        INSERT INTO Users (id, username)
        VALUES ($1, $2)
        ON CONFLICT (id) DO NOTHING
    "#)
    .bind(player_id)
    .bind(username)
    .execute(&mut *tx)
    .await?;

    sqlx::query(r#"
        INSERT INTO Player_Profiles (user_id)
        VALUES ($1)
        ON CONFLICT (user_id) DO NOTHING
    "#)
    .bind(player_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"
        INSERT INTO Club_Memberships (player_id, club_id, role)
        VALUES ($1, $2, 'player')
        ON CONFLICT (player_id, club_id) DO NOTHING
        "#,
    )
    .bind(player_id)
    .bind(club_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(club_id)
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Details & Members
// ─────────────────────────────────────────────────────────────────────────────

/// Club detail row from DB.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct ClubDetailRow {
    pub id: Uuid,
    pub name: String,
    pub invite_code: String,
    pub owner_id: Option<Uuid>,
    pub member_count: i64,
}

/// Fetches summary info for clubs a player belongs to.
pub async fn get_player_clubs(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Vec<ClubDetailRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubDetailRow>(
        r#"
        SELECT c.id, c.name, c.invite_code, c.owner_id,
               (SELECT COUNT(*) FROM Club_Memberships cm2 WHERE cm2.club_id = c.id) AS member_count
        FROM Clubs c
        JOIN Club_Memberships cm ON cm.club_id = c.id
        WHERE cm.player_id = $1 AND c.deleted_at IS NULL
        ORDER BY cm.joined_at DESC
        "#,
    )
    .bind(player_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Club member row including profile ratings.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct ClubMemberRow {
    pub user_id: Uuid,
    pub username: String,
    pub role: String,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
    pub matches_played: i64,
    pub avatar_graphic: Option<String>,
}

/// Fetches all members of a club with their profile data.
pub async fn get_club_members(
    pool: &PgPool,
    club_id: Uuid,
) -> Result<Vec<ClubMemberRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubMemberRow>(
        r#"
        SELECT u.id AS user_id, COALESCE(NULLIF(u.full_name, ''), u.username) AS username, cm.role,
               COALESCE(cm.skill_rating, 1000) AS skill_rating,
               COALESCE(cm.form_rating, 50.0)::FLOAT8 AS form_rating,
               cm.play_style,
               pp.avatar_graphic,
               (SELECT COUNT(*) FROM Match_Records mr WHERE mr.player_id = u.id AND mr.verification_status = 'approved' AND mr.club_id = $1) AS matches_played
        FROM Club_Memberships cm
        JOIN Users u ON cm.player_id = u.id
        LEFT JOIN Player_Profiles pp ON u.id = pp.user_id
        WHERE cm.club_id = $1
        ORDER BY COALESCE(cm.skill_rating, 1000) DESC
        "#,
    )
    .bind(club_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Updates a club member's role (admin/organizer/player).
pub async fn update_member_role(
    pool: &PgPool,
    club_id: Uuid,
    player_id: Uuid,
    new_role: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"UPDATE Club_Memberships SET role = $1 WHERE club_id = $2 AND player_id = $3"#,
    )
    .bind(new_role)
    .bind(club_id)
    .bind(player_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Removes a member from a club.
pub async fn remove_club_member(
    pool: &PgPool,
    club_id: Uuid,
    player_id: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"DELETE FROM Club_Memberships WHERE club_id = $1 AND player_id = $2"#,
    )
    .bind(club_id)
    .bind(player_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Updates club name and/or invite code.
pub async fn update_club_details(
    pool: &PgPool,
    club_id: Uuid,
    name: &str,
    invite_code: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"UPDATE Clubs SET name = $1, invite_code = $2, updated_at = NOW() WHERE id = $3"#,
    )
    .bind(name)
    .bind(invite_code)
    .bind(club_id)
    .execute(pool)
    .await?;

    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Activity & Seasons
// ─────────────────────────────────────────────────────────────────────────────

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ClubActivityRow {
    pub id: Uuid,
    pub player_id: Uuid,
    pub player_name: String,
    pub opponent_id: Uuid,
    pub opponent_name: String,
    pub match_type: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn get_club_activity(
    pool: &sqlx::PgPool,
    club_id: Uuid,
    limit: i64,
) -> Result<Vec<ClubActivityRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubActivityRow>(
        r#"
        SELECT m.id,
               m.player_id,
               COALESCE(NULLIF(u1.full_name, ''), u1.username, 'Unknown') AS player_name,
               m.opponent_id,
               COALESCE(NULLIF(u2.full_name, ''), u2.username, 'Unknown') AS opponent_name,
               m.match_type, m.goals_for::INT4 AS goals_for, m.goals_against::INT4 AS goals_against,
               m.created_at
        FROM Match_Records m
        LEFT JOIN Users u1 ON m.player_id = u1.id
        LEFT JOIN Users u2 ON m.opponent_id = u2.id
        WHERE m.club_id = $1 AND m.deleted_at IS NULL
        ORDER BY m.created_at DESC
        LIMIT $2
        "#,
    )
    .bind(club_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ClubResolvedMatchRow {
    pub id: Uuid,
    pub player_id: Uuid,
    pub player_name: String,
    pub opponent_id: Uuid,
    pub opponent_name: String,
    pub match_type: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub verified_by_id: Option<Uuid>,
    pub verifier_username: Option<String>,
}

pub async fn get_club_resolved_matches(
    pool: &sqlx::PgPool,
    club_id: Uuid,
    limit: i64,
) -> Result<Vec<ClubResolvedMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ClubResolvedMatchRow>(
        r#"
        SELECT m.id,
               m.player_id,
               COALESCE(NULLIF(u1.full_name, ''), u1.username, 'Unknown') AS player_name,
               m.opponent_id,
               COALESCE(NULLIF(u2.full_name, ''), u2.username, 'Unknown') AS opponent_name,
               m.match_type, m.goals_for::INT4 AS goals_for, m.goals_against::INT4 AS goals_against,
               m.created_at,
               m.verified_by_id,
               COALESCE(NULLIF(uv.full_name, ''), uv.username) AS verifier_username
        FROM Match_Records m
        LEFT JOIN Users u1 ON m.player_id = u1.id
        LEFT JOIN Users u2 ON m.opponent_id = u2.id
        LEFT JOIN Users uv ON m.verified_by_id = uv.id
        WHERE m.club_id = $1 AND m.deleted_at IS NULL AND m.verification_status = 'approved'
        ORDER BY m.updated_at DESC
        LIMIT $2
        "#,
    )
    .bind(club_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ClubSeasonRow {
    pub id: Uuid,
    pub name: String,
    pub start_date: chrono::NaiveDate,
    pub end_date: Option<chrono::NaiveDate>,
    pub is_active: bool,
}

pub async fn get_club_seasons(
    _pool: &sqlx::PgPool,
    _club_id: Uuid,
) -> Result<Vec<ClubSeasonRow>, sqlx::Error> {
    Ok(vec![])
}

#[derive(sqlx::FromRow, serde::Serialize)]
pub struct ScheduledMatchRow {
    pub id: Uuid,
    pub tournament_id: Uuid,
    pub tournament_name: String,
    pub format_type: Option<String>,
    pub player_1_id: Option<Uuid>,
    pub player_1_name: Option<String>,
    pub player_1_avatar: Option<String>,
    pub player_2_id: Option<Uuid>,
    pub player_2_name: Option<String>,
    pub player_2_avatar: Option<String>,
    pub round_number: i32,
    pub group_name: Option<String>,
    pub status: String,
    pub scheduled_at: Option<chrono::DateTime<chrono::Utc>>,
    pub original_scheduled_at: Option<chrono::DateTime<chrono::Utc>>,
    pub is_rescheduled: Option<bool>,
    pub reschedule_reason: Option<String>,
    pub matchday_number: Option<i32>,
    pub matchday_scheduled_date: Option<chrono::NaiveDate>,
    pub start_date: Option<chrono::NaiveDate>,
    pub created_at: Option<chrono::DateTime<chrono::Utc>>,
}

pub async fn get_player_scheduled_matches(
    pool: &sqlx::PgPool,
    player_id: Uuid,
) -> Result<Vec<ScheduledMatchRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, ScheduledMatchRow>(
        r#"
        SELECT 
            m.id,
            m.tournament_id,
            t.name AS tournament_name,
            t.format_type,
            m.player_1_id,
            COALESCE(NULLIF(u1.full_name, ''), u1.username) AS player_1_name,
            pp1.avatar_graphic AS player_1_avatar,
            m.player_2_id,
            COALESCE(NULLIF(u2.full_name, ''), u2.username) AS player_2_name,
            pp2.avatar_graphic AS player_2_avatar,
            m.round_number::INT4 AS round_number,
            m.group_name,
            m.status,
            m.scheduled_at,
            m.original_scheduled_at,
            COALESCE(m.is_rescheduled, false) AS is_rescheduled,
            m.reschedule_reason,
            COALESCE(md.matchday_number::INT4, m.round_number::INT4) AS matchday_number,
            md.scheduled_date AS matchday_scheduled_date,
            t.start_date,
            t.created_at
        FROM T_Matches m
        INNER JOIN Tournaments t ON m.tournament_id = t.id
        LEFT JOIN Users u1 ON m.player_1_id = u1.id
        LEFT JOIN Users u2 ON m.player_2_id = u2.id
        LEFT JOIN Player_Profiles pp1 ON u1.id = pp1.user_id
        LEFT JOIN Player_Profiles pp2 ON u2.id = pp2.user_id
        LEFT JOIN Matchdays md ON (m.matchday_id = md.id OR (m.tournament_id = md.tournament_id AND m.round_number = md.matchday_number))
        WHERE (m.player_1_id = $1 OR m.player_2_id = $1)
          AND m.status IN ('scheduled', 'rescheduled')
          AND t.deleted_at IS NULL
          AND t.status NOT IN ('deleted', 'completed', 'archived', 'cancelled')
        ORDER BY 
            COALESCE(m.scheduled_at, (md.scheduled_date::TIMESTAMPTZ + INTERVAL '23 hours 59 minutes'), (t.start_date::TIMESTAMPTZ + (m.round_number - 1) * INTERVAL '1 day' + INTERVAL '23 hours 59 minutes'), (t.created_at::DATE::TIMESTAMPTZ + (m.round_number - 1) * INTERVAL '1 day' + INTERVAL '23 hours 59 minutes')) ASC,
            m.round_number ASC,
            m.created_at ASC
        "#,
    )
    .bind(player_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Checks if a user is a club official (admin, organizer, president, captain, vice-captain).
pub async fn is_club_official(
    pool: &PgPool,
    club_id: Uuid,
    user_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let row = sqlx::query!(
        r#"
        SELECT EXISTS (
            SELECT 1 FROM Club_Memberships
            WHERE club_id = $1 AND player_id = $2
              AND LOWER(role) IN ('admin', 'organizer', 'president', 'captain', 'vice-captain')
        ) AS is_official
        "#,
        club_id,
        user_id
    )
    .fetch_one(pool)
    .await?;

    Ok(row.is_official.unwrap_or(false))
}

/// Checks if a user is the owner of a club.
pub async fn is_club_owner(
    pool: &PgPool,
    club_id: Uuid,
    user_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let is_owner: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS (
            SELECT 1 FROM Clubs
            WHERE id = $1 AND owner_id = $2
        )
        "#,
    )
    .bind(club_id)
    .bind(user_id)
    .fetch_one(pool)
    .await?;

    Ok(is_owner)
}

/// Deletes a tournament.
pub async fn delete_tournament(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE Tournaments SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1")
        .bind(tournament_id)
        .execute(pool)
        .await?;

    sqlx::query("DELETE FROM T_Matches WHERE tournament_id = $1")
        .bind(tournament_id)
        .execute(pool)
        .await?;

    sqlx::query("DELETE FROM Matchdays WHERE tournament_id = $1")
        .bind(tournament_id)
        .execute(pool)
        .await?;

    Ok(())
}

/// Gets the club_id for a given tournament.
pub async fn get_tournament_club_id(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<Option<Uuid>, sqlx::Error> {
    let club_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT club_id FROM Tournaments WHERE id = $1",
    )
    .bind(tournament_id)
    .fetch_optional(pool)
    .await?;
    
    Ok(club_id)
}

/// Checks if all group stage matches (with a group_name) for a tournament are completed.
pub async fn check_group_stage_completed(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM T_Matches
        WHERE tournament_id = $1
          AND group_name IS NOT NULL
          AND status != 'completed'
        "#,
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    Ok(count == 0)
}

/// Checks if any knockout matches (no group_name) have already been generated for this tournament.
pub async fn check_knockout_stage_generated(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM T_Matches
            WHERE tournament_id = $1
              AND group_name IS NULL
              AND round_number > COALESCE((
                  SELECT MAX(round_number) 
                  FROM T_Matches 
                  WHERE tournament_id = $1 AND group_name IS NOT NULL
              ), 0)
        )
        "#,
    )
    .bind(tournament_id)
    .fetch_one(pool)
    .await?;

    Ok(exists)
}

/// Fetches advancing_per_group from tournament format_config / rules_config.
pub async fn get_tournament_advancing_count(
    pool: &PgPool,
    tournament_id: Uuid,
) -> Result<usize, sqlx::Error> {
    let row = sqlx::query!(
        "SELECT rules_config FROM Tournaments WHERE id = $1",
        tournament_id
    )
    .fetch_optional(pool)
    .await?;

    if let Some(row) = row {
        let config = row.rules_config;
        let advancing = config.get("advancing_per_group").and_then(|v| v.as_u64()).unwrap_or(2);
        return Ok(advancing as usize);
    }
    Ok(2)
}
pub async fn void_match(
    pool: &PgPool,
    match_id: Uuid,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    let row = sqlx::query(
        r#"
        SELECT t_match_id, player_id, opponent_id, goals_for::INT4 AS goals_for, goals_against::INT4 AS goals_against
        FROM Match_Records
        WHERE id = $1
        "#,
    )
    .bind(match_id)
    .fetch_optional(&mut *tx)
    .await?;

    let Some(row) = row else {
        return Err(sqlx::Error::RowNotFound);
    };

    let t_match_id: Option<Uuid> = row.try_get("t_match_id").ok();
    let player_id: Uuid = row.get("player_id");
    let opponent_id: Uuid = row.get("opponent_id");
    let goals_for: i32 = row.get("goals_for");
    let goals_against: i32 = row.get("goals_against");

    if let Some(tm_id) = t_match_id {
        sqlx::query(
            "UPDATE T_Matches SET status = 'scheduled', player_1_score = NULL, player_2_score = NULL WHERE id = $1"
        )
        .bind(tm_id)
        .execute(&mut *tx)
        .await?;
        
        let t_row = sqlx::query("SELECT tournament_id, round_number::INT4 AS round_number, match_number::INT4 AS match_number, group_name, player_1_id, player_2_id, player_1_score::INT4 AS player_1_score, player_2_score::INT4 AS player_2_score FROM T_Matches WHERE id = $1")
            .bind(tm_id)
            .fetch_optional(&mut *tx)
            .await?;
            
        if let Some(tr) = t_row {
            let tournament_id: Uuid = tr.get("tournament_id");
            let round_number: i32 = tr.get("round_number");
            let match_number: i32 = tr.get("match_number");
            let group_name: Option<String> = tr.try_get("group_name").ok().flatten();
            let p1_id: Option<Uuid> = tr.try_get("player_1_id").ok().flatten();
            let p2_id: Option<Uuid> = tr.try_get("player_2_id").ok().flatten();
            let p1_score: Option<i32> = tr.try_get("player_1_score").ok().flatten();
            let p2_score: Option<i32> = tr.try_get("player_2_score").ok().flatten();

            let status: String = sqlx::query_scalar("SELECT status FROM Tournaments WHERE id = $1")
                .bind(tournament_id)
                .fetch_one(&mut *tx)
                .await?;
            
            if status == "completed" {
                sqlx::query("UPDATE Tournaments SET status = 'active', updated_at = NOW() WHERE id = $1")
                    .bind(tournament_id)
                    .execute(&mut *tx)
                    .await?;
            }

            // Knockout bracket rollback
            if group_name.is_none() {
                let next_round = round_number + 1;
                let next_slot = (match_number + 1) / 2;
                
                let winner_id = if let (Some(p1), Some(p2), Some(s1), Some(s2)) = (p1_id, p2_id, p1_score, p2_score) {
                    if s1 > s2 { p1 } else { p2 }
                } else if goals_for > goals_against {
                    player_id
                } else {
                    opponent_id
                };

                let next_match = sqlx::query("SELECT id, player_1_id, player_2_id FROM T_Matches WHERE tournament_id = $1 AND round_number = $2 AND match_number = $3")
                    .bind(tournament_id)
                    .bind(next_round)
                    .bind(next_slot)
                    .fetch_optional(&mut *tx)
                    .await?;

                if let Some(nm) = next_match {
                    let nm_id: Uuid = nm.get("id");
                    let p1: Option<Uuid> = nm.try_get("player_1_id").ok().flatten();
                    let p2: Option<Uuid> = nm.try_get("player_2_id").ok().flatten();

                    if p1 == Some(winner_id) {
                        sqlx::query("UPDATE T_Matches SET player_1_id = NULL, status = 'scheduled', updated_at = NOW() WHERE id = $1")
                            .bind(nm_id)
                            .execute(&mut *tx)
                            .await?;
                    } else if p2 == Some(winner_id) {
                        sqlx::query("UPDATE T_Matches SET player_2_id = NULL, status = 'scheduled', updated_at = NOW() WHERE id = $1")
                            .bind(nm_id)
                            .execute(&mut *tx)
                            .await?;
                    }
                }
            }

            let (won, drawn, lost) = if goals_for > goals_against {
                (1, 0, 0)
            } else if goals_for == goals_against {
                (0, 1, 0)
            } else {
                (0, 0, 1)
            };
            
            sqlx::query(
                r#"
                UPDATE League_Standings
                SET played = GREATEST(0, played - 1),
                    won = GREATEST(0, won - $1),
                    drawn = GREATEST(0, drawn - $2),
                    lost = GREATEST(0, lost - $3),
                    goals_for = GREATEST(0, goals_for - $4),
                    goals_against = GREATEST(0, goals_against - $5),
                    goal_diff = GREATEST(0, goals_for - $4) - GREATEST(0, goals_against - $5),
                    points = GREATEST(0, won - $1) * 3 + GREATEST(0, drawn - $2),
                    last_processed_match_id = NULL,
                    updated_at = NOW()
                WHERE tournament_id = $6 AND player_id = $7
                "#
            )
            .bind(won)
            .bind(drawn)
            .bind(lost)
            .bind(goals_for)
            .bind(goals_against)
            .bind(tournament_id)
            .bind(player_id)
            .execute(&mut *tx)
            .await?;
            
            let (o_won, o_drawn, o_lost) = if goals_against > goals_for {
                (1, 0, 0)
            } else if goals_against == goals_for {
                (0, 1, 0)
            } else {
                (0, 0, 1)
            };
            
            sqlx::query(
                r#"
                UPDATE League_Standings
                SET played = GREATEST(0, played - 1),
                    won = GREATEST(0, won - $1),
                    drawn = GREATEST(0, drawn - $2),
                    lost = GREATEST(0, lost - $3),
                    goals_for = GREATEST(0, goals_for - $4),
                    goals_against = GREATEST(0, goals_against - $5),
                    goal_diff = GREATEST(0, goals_for - $5) - GREATEST(0, goals_against - $4),
                    points = GREATEST(0, won - $1) * 3 + GREATEST(0, drawn - $2),
                    last_processed_match_id = NULL,
                    updated_at = NOW()
                WHERE tournament_id = $6 AND player_id = $7
                "#
            )
            .bind(o_won)
            .bind(o_drawn)
            .bind(o_lost)
            .bind(goals_against)
            .bind(goals_for)
            .bind(tournament_id)
            .bind(opponent_id)
            .execute(&mut *tx)
            .await?;
        }
    }

    let elo_rows = sqlx::query(
        "SELECT player_id, club_id, rating_before, rating_after FROM Elo_History WHERE match_record_id = $1"
    )
    .bind(match_id)
    .fetch_all(&mut *tx)
    .await?;

    for hist in elo_rows {
        let p_id: Uuid = hist.get("player_id");
        let c_id: Option<Uuid> = hist.try_get("club_id").ok();
        let rating_before: i32 = hist.get("rating_before");
        let rating_after: i32 = hist.get("rating_after");
        let delta = rating_after - rating_before;
        if let Some(club_id) = c_id {
            sqlx::query(
                "UPDATE Club_Memberships SET skill_rating = skill_rating - $1 WHERE player_id = $2 AND club_id = $3"
            )
            .bind(delta)
            .bind(p_id)
            .bind(club_id)
            .execute(&mut *tx)
            .await?;
        }
    }
    
    sqlx::query("DELETE FROM Elo_History WHERE match_record_id = $1")
        .bind(match_id)
        .execute(&mut *tx)
        .await?;

    let player_win = if goals_for > goals_against { 1 } else { 0 };
    sqlx::query(
        "UPDATE Player_Profiles SET lifetime_matches = GREATEST(0, lifetime_matches - 1), lifetime_wins = GREATEST(0, lifetime_wins - $1) WHERE user_id = $2"
    )
    .bind(player_win)
    .bind(player_id)
    .execute(&mut *tx)
    .await?;

    let opponent_win = if goals_against > goals_for { 1 } else { 0 };
    sqlx::query(
        "UPDATE Player_Profiles SET lifetime_matches = GREATEST(0, lifetime_matches - 1), lifetime_wins = GREATEST(0, lifetime_wins - $1) WHERE user_id = $2"
    )
    .bind(opponent_win)
    .bind(opponent_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        "UPDATE Match_Records SET deleted_at = NOW() WHERE id = $1"
    )
    .bind(match_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn apply_match_stats(
    pool: &sqlx::PgPool,
    match_id: Uuid,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    // Defense in depth against double stats application
    let already_applied: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM Elo_History WHERE match_record_id = $1)"
    )
    .bind(match_id)
    .fetch_one(&mut *tx)
    .await?;

    if already_applied {
        tx.commit().await?;
        return Ok(());
    }

    let match_row = sqlx::query(
        r#"
        SELECT player_id, opponent_id, club_id, goals_for::INT4 AS goals_for, goals_against::INT4 AS goals_against, match_type
        FROM Match_Records
        WHERE id = $1
        "#
    )
    .bind(match_id)
    .fetch_one(&mut *tx)
    .await?;

    let player_id: Uuid = match_row.get("player_id");
    let opponent_id: Uuid = match_row.get("opponent_id");
    let club_id: Option<Uuid> = match_row.get("club_id");
    let goals_for: i32 = match_row.get("goals_for");
    let goals_against: i32 = match_row.get("goals_against");
    let match_type_str: String = match_row.get("match_type");

    let is_player_win = goals_for > goals_against;
    let is_draw = goals_for == goals_against;

    let elo_match_type = match match_type_str.as_str() {
        "league" | "tournament_group" => crate::domain::elo::MatchType::League,
        "knockout" | "tournament_knockout" => crate::domain::elo::MatchType::TournamentFinal,
        _ => crate::domain::elo::MatchType::Friendly,
    };

    if let Some(c_id) = club_id {
        let p1_rating: i32 = sqlx::query_scalar("SELECT skill_rating FROM Club_Memberships WHERE player_id = $1 AND club_id = $2")
            .bind(player_id).bind(c_id).fetch_optional(&mut *tx).await?.unwrap_or(1000);
        let p2_rating: i32 = sqlx::query_scalar("SELECT skill_rating FROM Club_Memberships WHERE player_id = $1 AND club_id = $2")
            .bind(opponent_id).bind(c_id).fetch_optional(&mut *tx).await?.unwrap_or(1000);

        let p1_elo = crate::domain::elo::calculate_elo(&crate::domain::elo::EloInput {
            player_rating: p1_rating,
            opponent_rating: p2_rating,
            goals_for: goals_for,
            goals_against: goals_against,
            match_type: elo_match_type.clone(),
            is_provisional: false,
        });
        
        let p2_elo = crate::domain::elo::calculate_elo(&crate::domain::elo::EloInput {
            player_rating: p2_rating,
            opponent_rating: p1_rating,
            goals_for: goals_against,
            goals_against: goals_for,
            match_type: elo_match_type,
            is_provisional: false,
        });

        sqlx::query("UPDATE Club_Memberships SET skill_rating = $1 WHERE player_id = $2 AND club_id = $3")
        .bind(p1_elo.new_rating).bind(player_id).bind(c_id).execute(&mut *tx).await?;

        sqlx::query("UPDATE Club_Memberships SET skill_rating = $1 WHERE player_id = $2 AND club_id = $3")
        .bind(p2_elo.new_rating).bind(opponent_id).bind(c_id).execute(&mut *tx).await?;

        sqlx::query("INSERT INTO Elo_History (club_id, player_id, match_record_id, rating_before, rating_after) VALUES ($1, $2, $3, $4, $5)")
        .bind(c_id).bind(player_id).bind(match_id).bind(p1_rating).bind(p1_elo.new_rating).execute(&mut *tx).await?;

        sqlx::query("INSERT INTO Elo_History (club_id, player_id, match_record_id, rating_before, rating_after) VALUES ($1, $2, $3, $4, $5)")
        .bind(c_id).bind(opponent_id).bind(match_id).bind(p2_rating).bind(p2_elo.new_rating).execute(&mut *tx).await?;
    }

    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id, lifetime_matches, lifetime_wins)
        VALUES ($1, 1, $2)
        ON CONFLICT (user_id) DO UPDATE SET
            lifetime_matches = Player_Profiles.lifetime_matches + 1,
            lifetime_wins    = Player_Profiles.lifetime_wins + $2,
            updated_at       = NOW()
        "#
    ).bind(player_id).bind(if is_player_win { 1 } else { 0 }).execute(&mut *tx).await?;

    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id, lifetime_matches, lifetime_wins)
        VALUES ($1, 1, $2)
        ON CONFLICT (user_id) DO UPDATE SET
            lifetime_matches = Player_Profiles.lifetime_matches + 1,
            lifetime_wins    = Player_Profiles.lifetime_wins + $2,
            updated_at       = NOW()
        "#
    ).bind(opponent_id).bind(if !is_player_win && !is_draw { 1 } else { 0 }).execute(&mut *tx).await?;

    tx.commit().await?;
    Ok(())
}
