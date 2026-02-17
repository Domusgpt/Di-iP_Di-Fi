//! Pub/Sub Client for the Vault
//!
//! Handles subscribing to `investment.pending` and publishing `investment.confirmed`.
//! Uses the Google Cloud Pub/Sub REST API via reqwest.
//! Falls back gracefully to local/stub mode when no GCP credentials are available.

use anyhow::Result;
use base64::Engine;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use tracing;

/// Message received from `investment.pending` topic.
#[derive(Debug, Deserialize)]
pub struct InvestmentPendingMessage {
    pub investment_id: String,
    pub invention_id: String,
    pub tx_hash: String,
    pub wallet_address: String,
    pub amount_usdc: Decimal,
}

/// Message published to `investment.confirmed` topic.
#[derive(Debug, Serialize)]
pub struct InvestmentConfirmedMessage {
    pub investment_id: String,
    pub invention_id: String,
    pub wallet_address: String,
    pub amount_usdc: Decimal,
    pub token_amount: Decimal,
    pub block_number: u64,
}

/// REST-based message format for Pub/Sub pull response.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PullResponse {
    #[serde(default)]
    received_messages: Vec<PulledMessage>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PulledMessage {
    ack_id: String,
    message: PubSubMessageBody,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PubSubMessageBody {
    #[serde(default)]
    data: String, // base64-encoded
    #[serde(default)]
    #[allow(dead_code)]
    message_id: String,
}

/// Pub/Sub client wrapper using REST API.
pub struct PubSubClient {
    project_id: String,
    http: reqwest::Client,
}

impl PubSubClient {
    pub fn new(project_id: String) -> Self {
        Self {
            project_id,
            http: reqwest::Client::new(),
        }
    }

    fn has_credentials() -> bool {
        std::env::var("GOOGLE_APPLICATION_CREDENTIALS").is_ok()
            || std::env::var("GOOGLE_CLOUD_PROJECT").is_ok()
    }

    /// Get an access token from the GCE metadata server.
    async fn get_access_token(&self) -> Result<String> {
        // Try GCE metadata server (works on Cloud Run, GKE, etc.)
        let resp = self
            .http
            .get("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token")
            .header("Metadata-Flavor", "Google")
            .timeout(std::time::Duration::from_secs(2))
            .send()
            .await;

        if let Ok(resp) = resp {
            if resp.status().is_success() {
                #[derive(Deserialize)]
                struct TokenResponse {
                    access_token: String,
                }
                let token: TokenResponse = resp.json().await?;
                return Ok(token.access_token);
            }
        }

        Err(anyhow::anyhow!(
            "No access token available. Use GCE metadata or set GOOGLE_APPLICATION_CREDENTIALS."
        ))
    }

    /// Subscribe to the `investment.pending` topic and process messages via polling.
    pub async fn start_investment_listener(
        &self,
        pool: sqlx::PgPool,
        rpc_url: String,
    ) -> Result<()> {
        tracing::info!(
            "Starting investment listener for project: {}",
            self.project_id
        );

        if !Self::has_credentials() {
            tracing::warn!("No GCP credentials — Pub/Sub listener in local/stub mode");
            tracing::info!("Set GOOGLE_APPLICATION_CREDENTIALS to enable production Pub/Sub");
            return Ok(());
        }

        let subscription = format!(
            "projects/{}/subscriptions/investment-pending-vault-sub",
            self.project_id
        );
        let pull_url = format!(
            "https://pubsub.googleapis.com/v1/{}:pull",
            subscription
        );

        tracing::info!("Pub/Sub listener polling: {}", subscription);

        loop {
            match self.pull_and_process(&pull_url, &pool, &rpc_url).await {
                Ok(count) => {
                    if count == 0 {
                        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
                    }
                }
                Err(e) => {
                    tracing::error!("Pub/Sub pull error: {}. Retrying in 10s...", e);
                    tokio::time::sleep(std::time::Duration::from_secs(10)).await;
                }
            }
        }
    }

    /// Pull messages from the subscription and process them.
    async fn pull_and_process(
        &self,
        pull_url: &str,
        pool: &sqlx::PgPool,
        rpc_url: &str,
    ) -> Result<usize> {
        let token = self.get_access_token().await?;

        let resp = self
            .http
            .post(pull_url)
            .bearer_auth(&token)
            .json(&serde_json::json!({
                "maxMessages": 10
            }))
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Pull failed ({}): {}", status, body));
        }

        let pull_response: PullResponse = resp.json().await?;
        let count = pull_response.received_messages.len();

        if count == 0 {
            return Ok(0);
        }

        let mut ack_ids = Vec::new();
        let b64 = base64::engine::general_purpose::STANDARD;

        for msg in &pull_response.received_messages {
            let decoded = b64.decode(&msg.message.data).unwrap_or_default();

            match serde_json::from_slice::<InvestmentPendingMessage>(&decoded) {
                Ok(pending) => {
                    tracing::info!(
                        "Received pending investment: {} (tx: {})",
                        pending.investment_id,
                        pending.tx_hash
                    );

                    match process_pending_investment(&pending, pool, rpc_url, &self.project_id)
                        .await
                    {
                        Ok(_) => {
                            tracing::info!("Processed investment: {}", pending.investment_id);
                            ack_ids.push(msg.ack_id.clone());
                        }
                        Err(e) => {
                            tracing::error!(
                                "Failed to process investment {}: {}",
                                pending.investment_id,
                                e
                            );
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to deserialize message: {}", e);
                    ack_ids.push(msg.ack_id.clone()); // Ack to avoid poison pill
                }
            }
        }

        // Acknowledge processed messages
        if !ack_ids.is_empty() {
            let subscription = format!(
                "projects/{}/subscriptions/investment-pending-vault-sub",
                self.project_id
            );
            let ack_url = format!(
                "https://pubsub.googleapis.com/v1/{}:acknowledge",
                subscription
            );

            let _ = self
                .http
                .post(&ack_url)
                .bearer_auth(&token)
                .json(&serde_json::json!({
                    "ackIds": ack_ids
                }))
                .send()
                .await;
        }

        Ok(count)
    }

    /// Publish a confirmed investment message to Pub/Sub.
    pub async fn publish_investment_confirmed(
        &self,
        message: InvestmentConfirmedMessage,
    ) -> Result<()> {
        tracing::info!(
            "Publishing investment.confirmed: investment={}, amount={}",
            message.investment_id,
            message.amount_usdc
        );

        if !Self::has_credentials() {
            tracing::info!(
                "Local mode — would publish confirmation for investment {}",
                message.investment_id
            );
            return Ok(());
        }

        let token = self.get_access_token().await?;
        let topic = format!(
            "projects/{}/topics/investment.confirmed",
            self.project_id
        );
        let publish_url = format!("https://pubsub.googleapis.com/v1/{}:publish", topic);

        let data = serde_json::to_vec(&message)?;
        let b64 = base64::engine::general_purpose::STANDARD;
        let encoded = b64.encode(&data);

        let resp = self
            .http
            .post(&publish_url)
            .bearer_auth(&token)
            .json(&serde_json::json!({
                "messages": [{
                    "data": encoded
                }]
            }))
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Publish failed ({}): {}", status, body));
        }

        tracing::info!(
            "Published confirmation for investment {}",
            message.investment_id
        );

        Ok(())
    }
}

/// Process a single pending investment: verify on-chain and record result.
async fn process_pending_investment(
    pending: &InvestmentPendingMessage,
    pool: &sqlx::PgPool,
    rpc_url: &str,
    project_id: &str,
) -> Result<()> {
    use crate::services::transaction_verifier;

    let verification = transaction_verifier::verify_investment_tx(
        rpc_url,
        &pending.tx_hash,
        &pending.wallet_address,
        pending.amount_usdc,
    )
    .await?;

    if verification.pending {
        tracing::info!("Transaction {} still pending", pending.tx_hash);
        return Err(anyhow::anyhow!("Transaction pending — will retry"));
    }

    if !verification.confirmed {
        tracing::warn!("Transaction {} failed verification", pending.tx_hash);
        sqlx::query(
            "INSERT INTO investments (investment_id, invention_id, tx_hash, wallet_address, amount_usdc, status, verified_at)
             VALUES ($1, $2, $3, $4, $5, 'FAILED', NOW())
             ON CONFLICT (tx_hash) DO UPDATE SET status = 'FAILED', verified_at = NOW()",
        )
        .bind(&pending.investment_id)
        .bind(&pending.invention_id)
        .bind(&pending.tx_hash)
        .bind(&pending.wallet_address)
        .bind(pending.amount_usdc)
        .execute(pool)
        .await?;

        return Ok(());
    }

    // Record confirmed investment
    sqlx::query(
        "INSERT INTO investments (investment_id, invention_id, tx_hash, wallet_address, amount_usdc, token_amount, block_number, status, verified_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'CONFIRMED', NOW())
         ON CONFLICT (tx_hash) DO UPDATE SET status = 'CONFIRMED', token_amount = $6, block_number = $7, verified_at = NOW()",
    )
    .bind(&pending.investment_id)
    .bind(&pending.invention_id)
    .bind(&pending.tx_hash)
    .bind(&pending.wallet_address)
    .bind(verification.amount_usdc)
    .bind(verification.token_amount)
    .bind(verification.block_number as i64)
    .execute(pool)
    .await?;

    // Publish confirmation
    let client = PubSubClient::new(project_id.to_string());
    client
        .publish_investment_confirmed(InvestmentConfirmedMessage {
            investment_id: pending.investment_id.clone(),
            invention_id: pending.invention_id.clone(),
            wallet_address: pending.wallet_address.clone(),
            amount_usdc: verification.amount_usdc,
            token_amount: verification.token_amount,
            block_number: verification.block_number,
        })
        .await?;

    Ok(())
}
