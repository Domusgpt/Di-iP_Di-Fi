use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DividendDistribution {
    pub id: Uuid,
    pub invention_id: String,
    pub total_revenue_usdc: Decimal,
    pub merkle_root: String,
    pub claim_count: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct DividendClaim {
    pub id: Uuid,
    pub distribution_id: Uuid,
    pub wallet_address: String,
    pub amount_usdc: Decimal,
    pub merkle_proof: Vec<String>,
    pub claimed: bool,
    pub claim_tx_hash: Option<String>,
    pub created_at: DateTime<Utc>,
}
