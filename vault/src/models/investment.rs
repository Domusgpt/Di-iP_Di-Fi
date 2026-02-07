use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "investment_status", rename_all = "lowercase")]
pub enum InvestmentStatus {
    Pending,
    Confirmed,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Investment {
    pub id: Uuid,
    pub investment_id: String, // Added to match schema
    pub invention_id: String,
    pub wallet_address: String,
    pub amount_usdc: Decimal,
    pub tx_hash: String,
    pub status: InvestmentStatus,
    pub block_number: Option<i64>,
    pub token_amount: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub verified_at: Option<DateTime<Utc>>, // Renamed from confirmed_at
}

#[derive(Debug, Deserialize)]
pub struct VerifyRequest {
    pub invention_id: String,
    pub wallet_address: String,
    pub amount_usdc: Decimal,
    pub tx_hash: String,
}
