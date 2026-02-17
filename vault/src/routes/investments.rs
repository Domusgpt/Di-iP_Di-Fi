//! Investment verification and tracking routes.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::investment::{Investment, InvestmentStatus, VerifyRequest};
use crate::services::transaction_verifier;
use crate::services::pubsub::{InvestmentConfirmedMessage, PubSubClient};

pub fn router(pool: PgPool) -> Router {
    Router::new()
        .route("/verify", post(verify_transaction))
        .route("/:id", get(get_investment))
        .route("/by-invention/:invention_id", get(get_by_invention))
        .with_state(pool)
}

/// POST /api/v1/vault/investments/verify
/// Verify a blockchain transaction and record the confirmed investment.
async fn verify_transaction(
    State(pool): State<PgPool>,
    Json(req): Json<VerifyRequest>,
) -> Result<Json<Investment>, axum::http::StatusCode> {
    tracing::info!("Verifying transaction: {}", req.tx_hash);

    let rpc_url = std::env::var("RPC_URL")
        .unwrap_or_else(|_| "http://127.0.0.1:8545".to_string());

    // Verify the transaction on-chain
    let verification = transaction_verifier::verify_investment_tx(
        &rpc_url,
        &req.tx_hash,
        &req.wallet_address,
        req.amount_usdc,
    )
    .await
    .map_err(|e| {
        tracing::error!("Transaction verification failed: {}", e);
        axum::http::StatusCode::BAD_REQUEST
    })?;

    if verification.pending {
        tracing::info!("Transaction {} still pending", req.tx_hash);
        return Err(axum::http::StatusCode::ACCEPTED);
    }

    if !verification.confirmed {
        tracing::warn!("Transaction {} failed on-chain", req.tx_hash);
        return Err(axum::http::StatusCode::UNPROCESSABLE_ENTITY);
    }

    // Record in PostgreSQL
    let investment = sqlx::query_as::<_, Investment>(
        r#"
        INSERT INTO investments (id, invention_id, wallet_address, amount_usdc, tx_hash, status, block_number, token_amount)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (tx_hash) DO UPDATE SET status = $6, block_number = $7
        RETURNING *
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(&req.invention_id)
    .bind(&req.wallet_address)
    .bind(req.amount_usdc)
    .bind(&req.tx_hash)
    .bind(InvestmentStatus::Confirmed)
    .bind(verification.block_number as i64)
    .bind(verification.token_amount)
    .fetch_one(&pool)
    .await
    .map_err(|e| {
        tracing::error!("Failed to insert investment: {}", e);
        axum::http::StatusCode::INTERNAL_SERVER_ERROR
    })?;

    // Publish `investment.confirmed` to Pub/Sub
    let project_id = std::env::var("GOOGLE_CLOUD_PROJECT").unwrap_or_default();
    if !project_id.is_empty() {
        let pubsub = PubSubClient::new(project_id);
        let confirmed_msg = InvestmentConfirmedMessage {
            investment_id: investment.id.to_string(),
            invention_id: req.invention_id.clone(),
            wallet_address: req.wallet_address.clone(),
            amount_usdc: verification.amount_usdc,
            token_amount: verification.token_amount,
            block_number: verification.block_number,
        };
        if let Err(e) = pubsub.publish_investment_confirmed(confirmed_msg).await {
            tracing::error!("Failed to publish investment.confirmed: {}", e);
        }
    }

    Ok(Json(investment))
}

/// GET /api/v1/vault/investments/:id
async fn get_investment(
    State(pool): State<PgPool>,
    Path(id): Path<Uuid>,
) -> Result<Json<Investment>, axum::http::StatusCode> {
    let investment = sqlx::query_as::<_, Investment>(
        "SELECT * FROM investments WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(&pool)
    .await
    .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?
    .ok_or(axum::http::StatusCode::NOT_FOUND)?;

    Ok(Json(investment))
}

/// GET /api/v1/vault/investments/by-invention/:invention_id
async fn get_by_invention(
    State(pool): State<PgPool>,
    Path(invention_id): Path<String>,
) -> Result<Json<Vec<Investment>>, axum::http::StatusCode> {
    let investments = sqlx::query_as::<_, Investment>(
        "SELECT * FROM investments WHERE invention_id = $1 ORDER BY created_at DESC",
    )
    .bind(&invention_id)
    .fetch_all(&pool)
    .await
    .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(investments))
}
