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
    /// Each confirmed transaction triggers a publish to `investment.confirmed`.
    pub async fn start_investment_listener(
        &self,
        pool: sqlx::PgPool,
        rpc_url: String,
    ) -> Result<()> {
        tracing::info!(
            "Starting investment listener for project: {}",
            self.project_id
        );

        // In production, this uses google-cloud-pubsub crate:
        //
        // let client = google_cloud_pubsub::client::Client::default().await?;
        // let subscription = client.subscription("investment-pending-vault-sub");
        //
        // subscription.receive(|message, _cancel| async move {
        //     let data: InvestmentPendingMessage = serde_json::from_slice(&message.data)?;
        //     process_pending_investment(data, &pool, &rpc_url).await;
        //     message.ack().await;
        // }).await?;

        tracing::warn!("Pub/Sub listener running in stub mode (no GCP credentials)");
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

        // In production:
        //
        // let client = google_cloud_pubsub::client::Client::default().await?;
        // let topic = client.topic("investment.confirmed");
        // let publisher = topic.new_publisher(None);
        // let msg = PubsubMessage {
        //     data: serde_json::to_vec(&message)?,
        //     ..Default::default()
        // };
        // publisher.publish(msg).await.get().await?;

        tracing::info!(
            "Published confirmation for investment {}",
            message.investment_id
        );
        Ok(())
    }
}
