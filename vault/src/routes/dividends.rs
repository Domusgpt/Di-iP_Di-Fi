//! Dividend distribution routes.
//! Handles calculating and distributing royalty payments to token holders.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::crypto::merkle::{build_merkle_tree, ClaimLeaf};
use crate::models::dividend::{DividendClaim, DividendDistribution};
use crate::services::token_calculator;

pub fn router(pool: PgPool) -> Router {
    Router::new()
        .route("/distribute/:invention_id", post(distribute_dividends))
        .route("/claims/:wallet_address", get(get_claimable))
        .with_state(pool)
}

/// Request body for dividend distribution.
#[derive(serde::Deserialize)]
struct DistributeRequest {
    revenue_usdc: f64,
    /// List of token holders with their balances.
    /// In production this would be fetched from the RoyaltyToken contract,
    /// but for MVP the caller provides this data.
    holders: Vec<HolderBalance>,
}

#[derive(serde::Deserialize)]
struct HolderBalance {
    wallet_address: String,
    token_balance: f64,
}

/// POST /api/v1/vault/dividends/distribute/:invention_id
/// Calculate and create dividend distribution for an invention's token holders.
/// Called when licensing revenue is received.
async fn distribute_dividends(
    State(pool): State<PgPool>,
    Path(invention_id): Path<String>,
    Json(payload): Json<DistributeRequest>,
) -> Result<Json<DividendDistribution>, axum::http::StatusCode> {
    let revenue_usdc = payload.revenue_usdc;
    let holders = &payload.holders;

    if holders.is_empty() || revenue_usdc <= 0.0 {
        return Err(axum::http::StatusCode::BAD_REQUEST);
    }

    tracing::info!(
        "Distributing {} USDC for invention {} across {} holders",
        revenue_usdc,
        invention_id,
        holders.len()
    );

    // 1. Calculate total token supply from holder balances
    let total_supply: f64 = holders.iter().map(|h| h.token_balance).sum();
    if total_supply <= 0.0 {
        return Err(axum::http::StatusCode::BAD_REQUEST);
    }

    // 2. Calculate each holder's share and build Merkle tree leaves
    let claims_data: Vec<(String, f64, String)> = holders
        .iter()
        .map(|h| {
            let share = (h.token_balance / total_supply) * revenue_usdc;
            // Convert USDC to wei-like representation (6 decimals for USDC)
            let amount_wei = format!("{}", (share * 1_000_000.0) as u64);
            (h.wallet_address.clone(), share, amount_wei)
        })
        .collect();

    let merkle_leaves: Vec<ClaimLeaf> = claims_data
        .iter()
        .map(|(addr, _, wei)| ClaimLeaf {
            wallet_address: addr.clone(),
            amount_wei: wei.clone(),
        })
        .collect();

    // 3. Build Merkle tree
    let (merkle_root, proofs) = build_merkle_tree(&merkle_leaves).map_err(|e| {
        tracing::error!("Failed to build merkle tree: {}", e);
        axum::http::StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let distribution_id = Uuid::new_v4();

    // 4. Store distribution in PostgreSQL
    sqlx::query(
        r#"
        INSERT INTO dividend_distributions (id, invention_id, total_revenue_usdc, merkle_root, claim_count, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        "#,
    )
    .bind(distribution_id)
    .bind(&invention_id)
    .bind(rust_decimal::Decimal::from_f64_retain(revenue_usdc).unwrap_or_default())
    .bind(&merkle_root)
    .bind(claims_data.len() as i32)
    .execute(&pool)
    .await
    .map_err(|e| {
        tracing::error!("Failed to insert distribution: {}", e);
        axum::http::StatusCode::INTERNAL_SERVER_ERROR
    })?;

    // 5. Store individual claims with Merkle proofs
    for (i, (addr, share, _)) in claims_data.iter().enumerate() {
        let proof = &proofs[i];
        sqlx::query(
            r#"
            INSERT INTO dividend_claims (id, distribution_id, wallet_address, amount_usdc, merkle_proof, claimed, created_at)
            VALUES ($1, $2, $3, $4, $5, false, NOW())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(distribution_id)
        .bind(addr)
        .bind(rust_decimal::Decimal::from_f64_retain(*share).unwrap_or_default())
        .bind(proof)
        .execute(&pool)
        .await
        .map_err(|e| {
            tracing::error!("Failed to insert claim for {}: {}", addr, e);
            axum::http::StatusCode::INTERNAL_SERVER_ERROR
        })?;
    }

    tracing::info!(
        "Distribution {} created: root={}, claims={}",
        distribution_id,
        merkle_root,
        claims_data.len()
    );

    let distribution = DividendDistribution {
        id: distribution_id,
        invention_id,
        total_revenue_usdc: rust_decimal::Decimal::from_f64_retain(revenue_usdc)
            .unwrap_or_default(),
        merkle_root,
        claim_count: claims_data.len() as i32,
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
