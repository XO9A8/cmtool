//! # eFootball Club Management & Analytics Backend API Server
//!
//! Entry point initializing environment variables, tracing log subscribers, PostgreSQL database pool connections,
//! and starting the live Axum web server on port 3000.

mod api;
mod domain;
mod infrastructure;

use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Initialize environment configuration
    dotenvy::dotenv().ok();

    // 2. Initialize tracing logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "cmtool_backend=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Initializing eFootball Club Management Backend API Server...");

    // 3. Connect to PostgreSQL Database pool
    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres@localhost:5432/postgres".to_string());

    match sqlx::PgPool::connect(&db_url).await {
        Ok(_pool) => {
            tracing::info!("✅ Connected to PostgreSQL Database successfully.");
        }
        Err(e) => {
            tracing::warn!("⚠️ Database connection deferred or offline: {}", e);
        }
    }

    // 4. Create Axum Router & bind server socket
    let app = api::routes::create_router();

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
