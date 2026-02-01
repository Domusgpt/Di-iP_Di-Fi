//! Pub/Sub Client for the Vault
//!
//! Handles subscribing to `investment.pending` and publishing `investment.confirmed`.
//! This is the async bridge between the TypeScript social layer and the Rust financial layer.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use tracing;

/// Message received from `investment.pending` topic.
#[derive(Debug, Deserialize)]
pub struct InvestmentPendingMessage {
    pub investment_id: String,
    pub invention_id: String,
    pub tx_hash: String,
    pub wallet_address: String,
    pub amount_usdc: f64,
}

/// Message published to `investment.confirmed` topic.
#[derive(Debug, Serialize)]
pub struct InvestmentConfirmedMessage {
    pub investment_id: String,
    pub invention_id: String,
    pub wallet_address: String,
    pub amount_usdc: f64,
    pub token_amount: f64,
    pub block_number: u64,
}

/// Pub/Sub client wrapper for Google Cloud Pub/Sub.
pub struct PubSubClient {
    project_id: String,
}

impl PubSubClient {
    pub fn new(project_id: String) -> Self {
        Self { project_id }
    }

    /// Subscribe to the `investment.pending` topic and process messages.
    /// Each confirmed transaction triggers verification and publishing to `investment.confirmed`.
    pub async fn start_investment_listener(
        &self,
        pool: sqlx::PgPool,
        rpc_url: String,
    ) -> Result<()> {
        tracing::info!(
            "Starting investment listener for project: {}",
            self.project_id
        );

        let has_credentials = std::env::var("GOOGLE_APPLICATION_CREDENTIALS").is_ok()
            || std::env::var("GOOGLE_CLOUD_PROJECT").is_ok();

        if !has_credentials {
            tracing::warn!("No GCP credentials detected — Pub/Sub listener running in local mode");
            tracing::info!("Set GOOGLE_APPLICATION_CREDENTIALS to enable production Pub/Sub");
            return Ok(());
        }

        let client = google_cloud_pubsub::client::Client::default().await
            .map_err(|e| anyhow::anyhow!("Failed to create Pub/Sub client: {}", e))?;

        let subscription = client.subscription("investment-pending-vault-sub");

        tracing::info!("Pub/Sub listener active on subscription: investment-pending-vault-sub");

        let pool_clone = pool.clone();
        let rpc_clone = rpc_url.clone();
        let project_id = self.project_id.clone();

        subscription
            .receive(move |message, _cancel| {
                let pool = pool_clone.clone();
                let rpc = rpc_clone.clone();
                let proj = project_id.clone();

                async move {
                    match serde_json::from_slice::<InvestmentPendingMessage>(&message.message.data)
                    {
                        Ok(pending) => {
                            tracing::info!(
                                "Received pending investment: {} (tx: {})",
                                pending.investment_id,
                                pending.tx_hash
                            );

                            match process_pending_investment(&pending, &pool, &rpc, &proj).await {
                                Ok(_) => {
                                    tracing::info!(
                                        "Processed investment: {}",
                                        pending.investment_id
                                    );
                                    let _ = message.ack().await;
                                }
                                Err(e) => {
                                    tracing::error!(
                                        "Failed to process investment {}: {}",
                                        pending.investment_id,
                                        e
                                    );
                                    let _ = message.nack().await;
                                }
                            }
                        }
                        Err(e) => {
                            tracing::error!("Failed to deserialize pending message: {}", e);
                            let _ = message.ack().await; // Ack to avoid poison pill
                        }
                    }
                }
            })
            .await
            .map_err(|e| anyhow::anyhow!("Pub/Sub receive error: {}", e))?;

        Ok(())
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

        let has_credentials = std::env::var("GOOGLE_APPLICATION_CREDENTIALS").is_ok()
            || std::env::var("GOOGLE_CLOUD_PROJECT").is_ok();

        if !has_credentials {
            tracing::info!(
                "Local mode — would publish confirmation for investment {}",
                message.investment_id
            );
            return Ok(());
        }

        let client = google_cloud_pubsub::client::Client::default().await
            .map_err(|e| anyhow::anyhow!("Failed to create Pub/Sub client: {}", e))?;

        let topic = client.topic("investment.confirmed");
        let publisher = topic.new_publisher(None);

        let data = serde_json::to_vec(&message)?;
        let pubsub_msg = google_cloud_pubsub::subscriber::ReceivedMessage {
            ..Default::default()
        };

        // Use the raw publish API
        use google_cloud_pubsub::publisher::PublishConfig;
        let msg = google_cloud_pubsub::client::google::pubsub::v1::PubsubMessage {
            data,
            ..Default::default()
        };

        let awaiter = publisher.publish(msg).await;
        let message_id = awaiter.get().await
            .map_err(|e| anyhow::anyhow!("Failed to publish message: {:?}", e))?;

        tracing::info!(
            "Published confirmation for investment {} (msg_id: {})",
            message.investment_id,
            message_id
        );

        publisher.shutdown().await;

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

    if !verification.valid {
        tracing::warn!("Transaction {} failed verification", pending.tx_hash);
        // Record failure in DB
        sqlx::query(
            "INSERT INTO investments (investment_id, invention_id, tx_hash, wallet_address, amount_usdc, status, verified_at)
             VALUES ($1, $2, $3, $4, $5, 'FAILED', NOW())
             ON CONFLICT (tx_hash) DO UPDATE SET status = 'FAILED', verified_at = NOW()"
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
         ON CONFLICT (tx_hash) DO UPDATE SET status = 'CONFIRMED', token_amount = $6, block_number = $7, verified_at = NOW()"
    )
    .bind(&pending.investment_id)
    .bind(&pending.invention_id)
    .bind(&pending.tx_hash)
    .bind(&pending.wallet_address)
    .bind(verification.amount)
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
            amount_usdc: verification.amount,
            token_amount: verification.token_amount,
            block_number: verification.block_number,
        })
        .await?;

    Ok(())
}
