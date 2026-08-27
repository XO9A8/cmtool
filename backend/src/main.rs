#![recursion_limit = "256"]

//! # eFootball Club Management & Analytics Backend API Server
//!
//! Entry point initializing environment variables, tracing log subscribers,
//! PostgreSQL database pool, reqwest HTTP client, and the Axum web server on port 3000.

mod api;
mod domain;
mod infrastructure;

use std::{net::SocketAddr, sync::Arc};
use tokio::sync::RwLock;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use crate::domain::feature_flags::FeatureFlags;

/// Shared application state injected into every Axum route handler.
pub struct AppState {
    /// PostgreSQL connection pool.
    pub pool: sqlx::PgPool,
    /// Reusable HTTP client for Gemini AI calls.
    pub http_client: reqwest::Client,
    /// Gemini API key loaded from environment (optional).
    pub gemini_api_key: Option<String>,
    /// JWT signing secret.
    pub jwt_secret: String,
    /// Runtime feature flags (RwLock for live admin toggling).
    pub flags: RwLock<FeatureFlags>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Load environment configuration
    dotenvy::dotenv().ok();

    // 2. Initialize structured logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "cmtool_backend=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Initializing eFootball Club Management Backend API Server...");

    // 3. Connect to PostgreSQL
    let mut db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres:postgres@127.0.0.1:5432/efootball_db".to_string());

    // Force Session Mode for Supabase Pooler to fix sqlx prepared statement panics
    if db_url.contains(".pooler.supabase.com:6543") {
        tracing::warn!("Detected Supabase Transaction Mode pooler (port 6543). Rewriting to Session Mode (port 5432) for sqlx compatibility...");
        db_url = db_url.replace(":6543", ":5432");
    }

    let max_conns: u32 = std::env::var("DATABASE_MAX_CONNECTIONS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(15);

    let pool = match sqlx::postgres::PgPoolOptions::new()
        .max_connections(max_conns)
        .min_connections(2)
        .acquire_timeout(std::time::Duration::from_secs(15))
        .idle_timeout(std::time::Duration::from_secs(60))
        .max_lifetime(std::time::Duration::from_secs(1800))
        .connect(&db_url)
        .await
    {
        Ok(p) => {
            tracing::info!("✅ Connected to PostgreSQL successfully (max_connections: {}).", max_conns);
            // Run safe idempotent schema additions (IF NOT EXISTS) to ensure required columns exist
            let _ = sqlx::query("ALTER TABLE public.league_standings ADD COLUMN IF NOT EXISTS processed_match_ids UUID[] DEFAULT '{}'::UUID[];").execute(&p).await;
            let _ = sqlx::query("ALTER TABLE public.t_matches ADD COLUMN IF NOT EXISTS reschedule_count INT NOT NULL DEFAULT 0;").execute(&p).await;
            p
        }
        Err(e) => {
            tracing::warn!("⚠️ PostgreSQL connection failed: {}. Starting in offline mode.", e);
            sqlx::postgres::PgPoolOptions::new()
                .max_connections(max_conns)
                .min_connections(1)
                .acquire_timeout(std::time::Duration::from_secs(15))
                .idle_timeout(std::time::Duration::from_secs(60))
                .max_lifetime(std::time::Duration::from_secs(1800))
                .connect_lazy(&db_url)?
        }
    };

    // 4. Build shared AppState
    let gemini_api_key = std::env::var("GEMINI_API_KEY").ok();
    let jwt_secret = std::env::var("JWT_SECRET")
        .unwrap_or_else(|_| "default_cmtool_jwt_secret_key_2026".to_string());

    let state = Arc::new(AppState {
        pool: pool.clone(),
        http_client: reqwest::Client::new(),
        gemini_api_key,
        jwt_secret,
        flags: RwLock::new(FeatureFlags::default()),
    });

    // 5. Create Axum Router and bind socket
    let app = api::routes::create_router(state);

    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse()
        .expect("PORT must be a valid u16 integer");

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("🚀 eFootball Management API Backend running on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
