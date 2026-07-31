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
                .unwrap_or_else(|_| "cmtool_backend=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Initializing eFootball Club Management Backend API Server...");

    // 3. Connect to PostgreSQL
    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres:postgres@127.0.0.1:5432/efootball_db".to_string());

    let pool = match sqlx::postgres::PgPoolOptions::new()
        .acquire_timeout(std::time::Duration::from_secs(3))
        .connect(&db_url)
        .await
    {
        Ok(p) => {
            tracing::info!("✅ Connected to PostgreSQL successfully.");
            p
        }
        Err(e) => {
            tracing::warn!("⚠️ PostgreSQL connection failed: {}. Starting in offline mode.", e);
            sqlx::postgres::PgPoolOptions::new()
                .acquire_timeout(std::time::Duration::from_secs(3))
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

    // --- Background Cron Job: Badge Evaluation ---
    let cron_pool = pool.clone();
    tokio::spawn(async move {
        tracing::info!("Starting background badge evaluation cron job...");
        // Run every 10 seconds for demonstration (normally would be daily or hourly)
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(10));
        loop {
            interval.tick().await;
            tracing::info!("Running periodic badge evaluation for all players...");
            // In a full implementation, this would query player stats from cron_pool.
            // For now, we invoke the evaluate_badges domain logic to demonstrate the background task.
            let badges = crate::domain::play_style::evaluate_badges(55, 12, 6);
            if !badges.is_empty() {
                tracing::info!("Simulated player earned badges: {:?}", badges);
            }
        }
    });

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
