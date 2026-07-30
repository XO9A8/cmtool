mod api;
mod domain;
mod infrastructure;

use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "cmtool_backend=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres@localhost:5432/postgres".to_string());

    let pool = sqlx::PgPool::connect(&db_url).await;
    match &pool {
        Ok(_) => tracing::info!("✅ Connected to PostgreSQL Database successfully"),
        Err(e) => tracing::warn!("⚠️ Database connection deferred or offline: {}", e),
    }

    let app = api::routes::create_router();

    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse()?;

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("🚀 eFootball Management API Backend running on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
