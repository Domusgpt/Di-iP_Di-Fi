//! IdeaCapital Vault - Financial Backend
//!
//! The Vault is the trust layer of IdeaCapital. It handles:
//! - Blockchain transaction verification
//! - Investment confirmation and token allocation
//! - Dividend distribution calculations
//! - Merkle tree proofs for airdrop claims
//!
//! Integration Points:
//! - Subscribes to: `investment.pending` (from TypeScript backend)
//! - Publishes to: `investment.confirmed` (consumed by TypeScript backend)
//! - Reads from: Polygon/Base blockchain (via RPC)
//! - Writes to: PostgreSQL (financial ledger)

mod routes;
mod services;
mod models;
mod middleware;
mod crypto;

use axum::{routing::get, Router};
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use std::net::SocketAddr;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load environment
    dotenvy::dotenv().ok();

    // Initialize tracing
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| "ideacapital_vault=debug,tower_http=info".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Database connection
    let database_url = std::env::var("VAULT_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://user:pass@localhost:5432/ideacapital".to_string());

    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;

    // Run migrations
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .unwrap_or_else(|e| tracing::warn!("Migration skipped (expected in dev): {}", e));

    tracing::info!("Database connected");

    // Start background services
    let pool_clone = pool.clone();
    let rpc_url = std::env::var("RPC_URL")
        .unwrap_or_else(|_| "http://127.0.0.1:8545".to_string());
    let project_id = std::env::var("GOOGLE_CLOUD_PROJECT")
        .unwrap_or_else(|_| "ideacapital-dev".to_string());

    tokio::spawn(async move {
        let pubsub = services::pubsub::PubSubClient::new(project_id);
        if let Err(e) = pubsub.start_investment_listener(pool_clone, rpc_url).await {
            tracing::error!("Pub/Sub listener died: {}", e);
        }
    });

    // Build the app
    let app = Router::new()
        .route("/health", get(health_check))
        .nest("/api/v1/vault", routes::vault_router(pool.clone()))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http());

    // Start server
    let port: u16 = std::env::var("VAULT_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse()?;
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("Vault listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> axum::Json<serde_json::Value> {
    axum::Json(serde_json::json!({
        "status": "ok",
        "service": "ideacapital-vault",
        "version": env!("CARGO_PKG_VERSION"),
    }))
}
