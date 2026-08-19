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
// User Registration
// ─────────────────────────────────────────────────────────────────────────────

/// Upserts a user and their player profile from Supabase.
pub async fn upsert_supabase_user(
    pool: &PgPool,
    user_id: Uuid,
    username: &str,
) -> Result<Uuid, sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query(r#"
        INSERT INTO Users (id, username)
        VALUES ($1, $2)
        ON CONFLICT (id) DO NOTHING
    "#)
    .bind(user_id)
    .bind(username)
    .execute(&mut *tx)
    .await?;

    sqlx::query(r#"
        INSERT INTO Player_Profiles (user_id)
        VALUES ($1)
        ON CONFLICT (user_id) DO NOTHING
    "#)
    .bind(user_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(user_id)
}

#[derive(FromRow)]
pub struct UserRecord {
    pub id: Uuid,
    pub username: String,
}

/// Fetches a user by username
pub async fn get_user_by_username(
    pool: &sqlx::PgPool,
    username: &str,
) -> Result<Option<UserRecord>, sqlx::Error> {
    let user = sqlx::query_as::<_, UserRecord>(
        r#"SELECT id, username FROM Users WHERE username = $1"#,
    )
    .bind(username)
    .fetch_optional(pool)
    .await?;

    Ok(user)
}

