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
// Player Analytics & MPS History
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the last N MPS values for a player (oldest first), used for EWMA form calculation.
/// Fetches the current form rating for a player (either from Club_Memberships or default).
pub async fn get_player_current_form(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<f64, sqlx::Error> {
    let row: Option<(f64,)> = sqlx::query_as(
        r#"
        SELECT form_rating::float8
        FROM Club_Memberships
        WHERE player_id = $1
        LIMIT 1
        "#,
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|r| r.0).unwrap_or(50.0))
}

pub async fn get_player_mps_history(
    pool: &PgPool,
    player_id: Uuid,
    n: i64,
) -> Result<Vec<f64>, sqlx::Error> {
    let rows: Vec<(f64,)> = sqlx::query_as(
        r#"
        SELECT possession * 0.20
             + (CASE WHEN passes_attempted > 0 THEN passes_completed::float / passes_attempted * 100 ELSE 0 END) * 0.30
             + (CASE WHEN shots_on_target  > 0 THEN goals_for::float      / shots_on_target         * 100 ELSE 0 END) * 0.30
             + LEAST(100, interceptions * 10)::float * 0.20
          AS mps
        FROM Match_Records
        WHERE player_id = $1
        ORDER BY created_at DESC
        LIMIT $2
        "#,
    )
    .bind(player_id)
    .bind(n)
    .fetch_all(pool)
    .await?;

    // Reverse so oldest is first for EWMA computation
    let mut values: Vec<f64> = rows.into_iter().map(|(v,)| v).collect();
    values.reverse();
    Ok(values)
}

/// Player profile row returned for analytics endpoint.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct PlayerAnalyticsRow {
    pub user_id: Uuid,
    pub username: Option<String>,
    pub skill_rating: i32,
    pub form_rating: f64,
    pub play_style: Option<String>,
    pub matches_played: i64,
    pub wins: i64,
    pub draws: i64,
    pub losses: i64,
    pub efootball_game_id: Option<String>,
    pub preferred_foot: Option<String>,
    pub jersey_number: Option<i32>,
    pub system_device: Option<String>,
    pub facebook: Option<String>,
    pub blood_group: Option<String>,
    pub district: Option<String>,
    pub date_of_birth: Option<chrono::NaiveDate>,
    pub registrar_joined: Option<chrono::NaiveDate>,
    pub contract_start: Option<chrono::NaiveDate>,
    pub contract_end: Option<chrono::NaiveDate>,
    pub facebook_link: Option<String>,
    pub email_node: Option<String>,
    pub phone_line: Option<String>,
    pub node_state: Option<String>,
    pub auth_status: Option<String>,
    pub source_feed: Option<String>,
}

/// Retrieves aggregated player analytics from the database.
/// Uses DISTINCT ON to pick only the most recently-joined club membership,
/// preventing duplicate rows for players who belong to multiple clubs.
pub async fn get_player_analytics(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<PlayerAnalyticsRow, sqlx::Error> {
    let row = sqlx::query_as::<_, PlayerAnalyticsRow>(
        r#"
        SELECT
            p.user_id,
            COALESCE(NULLIF(u.full_name, ''), u.username) AS username,
            COALESCE(cm.skill_rating, 1000)::INT4                     AS skill_rating,
            COALESCE(cm.form_rating, 50.0)::FLOAT8                   AS form_rating,
            cm.play_style,
            COUNT(m.id)::INT8                                        AS matches_played,
            COUNT(*) FILTER (WHERE (m.player_id = p.user_id AND m.goals_for > m.goals_against) OR (m.opponent_id = p.user_id AND m.goals_against > m.goals_for))::INT8 AS wins,
            COUNT(*) FILTER (WHERE m.goals_for = m.goals_against)::INT8 AS draws,
            COUNT(*) FILTER (WHERE (m.player_id = p.user_id AND m.goals_for < m.goals_against) OR (m.opponent_id = p.user_id AND m.goals_against < m.goals_for))::INT8 AS losses,
            p.efootball_game_id,
            p.preferred_foot,
            p.jersey_number::INT4                                    AS jersey_number,
            p.system_device,
            c.facebook_handle                                        AS facebook,
            c.blood_group,
            c.district,
            c.date_of_birth,
            c.facebook_url                                           AS facebook_link,
            c.email                                                  AS email_node,
            c.phone                                                  AS phone_line,
            comp.registrar_joined,
            comp.contract_start,
            comp.contract_end,
            comp.node_state,
            comp.auth_status,
            comp.source_feed
        FROM Player_Profiles p
        LEFT JOIN Users u ON u.id = p.user_id
        LEFT JOIN Player_Contact_Info c ON c.user_id = p.user_id
        LEFT JOIN Player_Compliance comp ON comp.user_id = p.user_id
        -- DISTINCT ON ensures only one membership row per player (most recently joined club)
        LEFT JOIN (
            SELECT DISTINCT ON (player_id)
                player_id, club_id, skill_rating, form_rating, play_style
            FROM Club_Memberships
            ORDER BY player_id, joined_at DESC NULLS LAST
        ) cm ON cm.player_id = p.user_id
        LEFT JOIN Match_Records m ON (m.player_id = p.user_id OR m.opponent_id = p.user_id) AND m.verification_status = 'approved' AND m.deleted_at IS NULL
        WHERE p.user_id = $1
        GROUP BY p.user_id, COALESCE(NULLIF(u.full_name, ''), u.username), cm.skill_rating, cm.form_rating, cm.play_style,
                 p.efootball_game_id, p.preferred_foot, p.jersey_number, p.system_device,
                 c.facebook_handle, c.blood_group, c.district, c.date_of_birth, c.facebook_url,
                 c.email, c.phone, comp.registrar_joined, comp.contract_start,
                 comp.contract_end, comp.node_state, comp.auth_status, comp.source_feed
        LIMIT 1
        "#,
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await?;

    Ok(row.unwrap_or(PlayerAnalyticsRow {
        user_id: player_id,
        username: None,
        skill_rating: 1000,
        form_rating: 50.0,
        play_style: Some("Unclassified".into()),
        matches_played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        efootball_game_id: None,
        preferred_foot: None,
        jersey_number: None,
        system_device: None,
        facebook: None,
        blood_group: None,
        district: None,
        date_of_birth: None,
        registrar_joined: None,
        contract_start: None,
        contract_end: None,
        facebook_link: None,
        email_node: None,
        phone_line: None,
        node_state: None,
        auth_status: None,
        source_feed: None,
    }))
}
// ─────────────────────────────────────────────────────────────────────────────

pub async fn update_player_profile(
    pool: &PgPool,
    player_id: Uuid,
    payload: serde_json::Value,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    let efootball_game_id = payload.get("efootball_game_id").and_then(|v| v.as_str());
    let preferred_foot = payload.get("preferred_foot").and_then(|v| v.as_str());
    let jersey_number = payload.get("jersey_number").and_then(|v| v.as_i64()).map(|v| v as i32);
    let system_device = payload.get("system_device").and_then(|v| v.as_str());
    let avatar_graphic = payload.get("avatar_graphic").and_then(|v| v.as_str());

    sqlx::query(
        r#"
        INSERT INTO Player_Profiles (user_id, efootball_game_id, preferred_foot, jersey_number, system_device, avatar_graphic)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (user_id) DO UPDATE SET
            efootball_game_id = EXCLUDED.efootball_game_id,
            preferred_foot = EXCLUDED.preferred_foot,
            jersey_number = EXCLUDED.jersey_number,
            system_device = EXCLUDED.system_device,
            avatar_graphic = EXCLUDED.avatar_graphic
        "#,
    )
    .bind(player_id)
    .bind(efootball_game_id)
    .bind(preferred_foot)
    .bind(jersey_number)
    .bind(system_device)
    .bind(avatar_graphic)
    .execute(&mut *tx)
    .await?;

    if let Some(contact) = payload.get("contact_info") {
        let blood_group = contact.get("blood_group").and_then(|v| v.as_str());
        let district = contact.get("district").and_then(|v| v.as_str());
        let facebook_link = contact.get("facebook_link").or_else(|| contact.get("facebook_url")).and_then(|v| v.as_str());
        let facebook_handle = contact.get("facebook").or_else(|| contact.get("facebook_handle")).and_then(|v| v.as_str());
        let email_node = contact.get("email_node").or_else(|| contact.get("email")).and_then(|v| v.as_str());
        let phone_line = contact.get("phone_line").or_else(|| contact.get("phone")).and_then(|v| v.as_str());
        let date_of_birth = contact.get("date_of_birth").and_then(|v| v.as_str()).and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok());

        sqlx::query(
            r#"
            INSERT INTO Player_Contact_Info (user_id, blood_group, district, date_of_birth, facebook_url, facebook_handle, email, phone)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (user_id) DO UPDATE SET
                blood_group = EXCLUDED.blood_group,
                district = EXCLUDED.district,
                date_of_birth = EXCLUDED.date_of_birth,
                facebook_url = EXCLUDED.facebook_url,
                facebook_handle = EXCLUDED.facebook_handle,
                email = EXCLUDED.email,
                phone = EXCLUDED.phone
            "#,
        )
        .bind(player_id)
        .bind(blood_group)
        .bind(district)
        .bind(date_of_birth)
        .bind(facebook_link)
        .bind(facebook_handle)
        .bind(email_node)
        .bind(phone_line)
        .execute(&mut *tx)
        .await?;
    }

    if let Some(comp) = payload.get("compliance") {
        let node_state = comp.get("node_state").and_then(|v| v.as_str());
        let auth_status = comp.get("auth_status").and_then(|v| v.as_str());
        let source_feed = comp.get("source_feed").and_then(|v| v.as_str());
        let registrar_joined = comp.get("registrar_joined").and_then(|v| v.as_str()).and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok());
        let contract_start = comp.get("contract_start").and_then(|v| v.as_str()).and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok());
        let contract_end = comp.get("contract_end").and_then(|v| v.as_str()).and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok());

        sqlx::query(
            r#"
            INSERT INTO Player_Compliance (user_id, registrar_joined, contract_start, contract_end, node_state, auth_status, source_feed)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (user_id) DO UPDATE SET
                registrar_joined = EXCLUDED.registrar_joined,
                contract_start = EXCLUDED.contract_start,
                contract_end = EXCLUDED.contract_end,
                node_state = EXCLUDED.node_state,
                auth_status = EXCLUDED.auth_status,
                source_feed = EXCLUDED.source_feed
            "#,
        )
        .bind(player_id)
        .bind(registrar_joined)
        .bind(contract_start)
        .bind(contract_end)
        .bind(node_state)
        .bind(auth_status)
        .bind(source_feed)
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;
    Ok(())
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Profile & Match History
// ─────────────────────────────────────────────────────────────────────────────

/// A single match history row.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct MatchHistoryRow {
    pub id: Uuid,
    pub opponent_id: Uuid,
    pub opponent_name: String,
    pub match_type: String,
    pub result: String,
    pub goals_for: i32,
    pub goals_against: i32,
    pub possession: f64,
    pub passes_completed: i32,
    pub passes_attempted: i32,
    pub shots_on_target: i32,
    pub shots_total: i32,
    pub interceptions: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches paginated match history for a player.
pub async fn get_player_match_history(
    pool: &PgPool,
    player_id: Uuid,
    limit: i64,
    offset: i64,
) -> Result<Vec<MatchHistoryRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, MatchHistoryRow>(
        r#"
        SELECT m.id, 
               CASE WHEN m.player_id = $1 THEN m.opponent_id ELSE m.player_id END AS opponent_id,
               COALESCE(NULLIF(u.full_name, ''), u.username, 'Unknown') AS opponent_name,
               m.match_type, 
               CASE WHEN m.player_id = $1 THEN m.result 
                    ELSE CASE WHEN m.result = 'win' THEN 'loss' WHEN m.result = 'loss' THEN 'win' ELSE m.result END 
               END AS result,
               CASE WHEN m.player_id = $1 THEN m.goals_for::INT4 ELSE m.goals_against::INT4 END AS goals_for, 
               CASE WHEN m.player_id = $1 THEN m.goals_against::INT4 ELSE m.goals_for::INT4 END AS goals_against,
               CASE WHEN m.player_id = $1 THEN m.possession::FLOAT8 ELSE 0.0 END AS possession,
               CASE WHEN m.player_id = $1 THEN m.passes_completed::INT4 ELSE 0 END AS passes_completed,
               CASE WHEN m.player_id = $1 THEN m.passes_attempted::INT4 ELSE 0 END AS passes_attempted,
               CASE WHEN m.player_id = $1 THEN m.shots_on_target::INT4 ELSE 0 END AS shots_on_target,
               CASE WHEN m.player_id = $1 THEN m.shots_total::INT4 ELSE 0 END AS shots_total,
               CASE WHEN m.player_id = $1 THEN m.interceptions::INT4 ELSE 0 END AS interceptions,
               m.created_at
        FROM Match_Records m
        LEFT JOIN Users u ON u.id = CASE WHEN m.player_id = $1 THEN m.opponent_id ELSE m.player_id END
        WHERE (m.player_id = $1 OR m.opponent_id = $1) AND m.deleted_at IS NULL AND m.verification_status = 'approved'
        ORDER BY m.created_at DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(player_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// An Elo history data point.
#[allow(dead_code)]
#[derive(FromRow)]
pub struct EloHistoryRow {
    pub rating_before: i32,
    pub rating_after: i32,
    pub recorded_at: chrono::DateTime<chrono::Utc>,
}

/// Fetches Elo rating progression for a player.
pub async fn get_elo_history(
    pool: &PgPool,
    player_id: Uuid,
    limit: i64,
) -> Result<Vec<EloHistoryRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, EloHistoryRow>(
        r#"
        SELECT rating_before, rating_after, recorded_at
        FROM Elo_History
        WHERE player_id = $1
        ORDER BY recorded_at ASC
        LIMIT $2
        "#,
    )
    .bind(player_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

