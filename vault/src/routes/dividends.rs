//! Dividend distribution routes.
//! Handles calculating and distributing royalty payments to token holders.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use sqlx::PgPool;

use crate::models::dividend::{DividendDistribution, DividendClaim};

pub fn router(pool: PgPool) -> Router {
    Router::new()
        .route("/distribute/:invention_id", post(distribute_dividends))
        .route("/claims/:wallet_address", get(get_claimable))
        .with_state(pool)
}

/// POST /api/v1/vault/dividends/distribute/:invention_id
/// Calculate and create dividend distribution for an invention's token holders.
/// Called when licensing revenue is received.
async fn distribute_dividends(
    State(pool): State<PgPool>,
    Path(invention_id): Path<String>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<DividendDistribution>, axum::http::StatusCode> {
    let revenue_usdc = payload["revenue_usdc"]
        .as_f64()
        .ok_or(axum::http::StatusCode::BAD_REQUEST)?;

    tracing::info!(
        "Distributing {} USDC for invention {}",
        revenue_usdc,
        invention_id
    );

    // TODO: Implementation steps:
    // 1. Fetch all token holders and their balances from the smart contract
    // 2. Calculate each holder's share (balance / total_supply * revenue)
    // 3. Create Merkle tree of claims for gas-efficient on-chain distribution
    // 4. Store the Merkle root and individual claims in PostgreSQL
    // 5. Deploy/call the DividendVault contract with the Merkle root

    let distribution = DividendDistribution {
        id: uuid::Uuid::new_v4(),
        invention_id,
        total_revenue_usdc: rust_decimal::Decimal::from_f64_retain(revenue_usdc)
            .unwrap_or_default(),
        merkle_root: String::new(), // TODO: compute
        claim_count: 0,
        created_at: chrono::Utc::now(),
    };

    Ok(Json(distribution))
}

/// GET /api/v1/vault/dividends/claims/:wallet_address
/// Get all claimable dividends for a wallet address.
async fn get_claimable(
    State(pool): State<PgPool>,
    Path(wallet_address): Path<String>,
) -> Result<Json<Vec<DividendClaim>>, axum::http::StatusCode> {
    let claims = sqlx::query_as::<_, DividendClaim>(
        r#"
        SELECT * FROM dividend_claims
        WHERE wallet_address = $1 AND claimed = false
        ORDER BY created_at DESC
        "#,
    )
    .bind(&wallet_address)
    .fetch_all(&pool)
    .await
    .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(claims))
}
