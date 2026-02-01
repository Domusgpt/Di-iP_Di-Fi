//! Investment verification and tracking routes.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::investment::{Investment, InvestmentStatus, VerifyRequest};

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

    // TODO: Use ethers-rs to fetch transaction receipt from RPC
    // let provider = Provider::<Http>::try_from(&rpc_url)?;
    // let receipt = provider.get_transaction_receipt(tx_hash).await?;
    // Verify: correct contract, correct amount, correct recipient

    // Record in PostgreSQL
    let investment = sqlx::query_as::<_, Investment>(
        r#"
        INSERT INTO investments (id, invention_id, wallet_address, amount_usdc, tx_hash, status)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(&req.invention_id)
    .bind(&req.wallet_address)
    .bind(&req.amount_usdc)
    .bind(&req.tx_hash)
    .bind(InvestmentStatus::Confirmed)
    .fetch_one(&pool)
    .await
    .map_err(|e| {
        tracing::error!("Failed to insert investment: {}", e);
        axum::http::StatusCode::INTERNAL_SERVER_ERROR
    })?;

    // TODO: Publish `investment.confirmed` to Pub/Sub

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
