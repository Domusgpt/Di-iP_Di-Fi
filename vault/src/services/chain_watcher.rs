//! Blockchain Event Watcher
//!
//! Listens to EVM events from the Crowdsale and DividendVault contracts.
//! When a transaction is confirmed on-chain, publishes `investment.confirmed`
//! to Pub/Sub so the TypeScript backend can update Firestore.

use anyhow::Result;
use ethers::prelude::*;
use ethers::abi::{self, Token};
use std::sync::Arc;

use crate::services::pubsub::{PubSubClient, InvestmentConfirmedMessage};

/// Watch for Investment events on the Crowdsale contract.
pub async fn watch_crowdsale_events(
    rpc_url: &str,
    contract_address: &str,
    pool: sqlx::PgPool,
    project_id: &str,
) -> Result<()> {
    let provider = Provider::<Http>::try_from(rpc_url)?;
    let provider = Arc::new(provider);

    let address: Address = contract_address.parse()?;

    // Event signature: Investment(address indexed investor, uint256 amount, uint256 tokenAmount)
    let investment_event = Filter::new()
        .address(address)
        .event("Investment(address,uint256,uint256)")
        .from_block(BlockNumber::Latest);

    tracing::info!("Watching for Investment events on {}", contract_address);

    let mut stream = provider.watch(&investment_event).await?;

    while let Some(log) = stream.next().await {
        tracing::info!("Investment event detected: tx={:?}", log.transaction_hash);

        match decode_investment_log(&log) {
            Ok((investor, amount_usdc, token_amount)) => {
                let tx_hash = log
                    .transaction_hash
                    .map(|h| format!("{:?}", h))
                    .unwrap_or_default();
                let block_number = log.block_number.map(|b| b.as_u64()).unwrap_or(0);

                tracing::info!(
                    "Investment decoded: investor={:?}, usdc={}, tokens={}, block={}",
                    investor,
                    amount_usdc,
                    token_amount,
                    block_number
                );

                // Record in PostgreSQL
                if let Err(e) = record_investment(
                    &pool,
                    &tx_hash,
                    &format!("{:?}", investor),
                    amount_usdc,
                    token_amount,
                    block_number,
                )
                .await
                {
                    tracing::error!("Failed to record investment: {}", e);
                    continue;
                }

                // Publish to Pub/Sub
                let pubsub = PubSubClient::new(project_id.to_string());
                if let Err(e) = pubsub
                    .publish_investment_confirmed(InvestmentConfirmedMessage {
                        investment_id: tx_hash.clone(),
                        invention_id: String::new(), // Decoded from event data if available
                        wallet_address: format!("{:?}", investor).to_lowercase(),
                        amount_usdc,
                        token_amount,
                        block_number,
                    })
                    .await
                {
                    tracing::error!("Failed to publish confirmation: {}", e);
                }
            }
            Err(e) => {
                tracing::error!("Failed to decode Investment event: {}", e);
            }
        }
    }

    Ok(())
}

/// Decode an Investment event log into (investor, amount_usdc, token_amount).
fn decode_investment_log(log: &Log) -> Result<(Address, f64, f64)> {
    // Topic[0] is the event signature hash
    // Topic[1] is the indexed `investor` address (padded to 32 bytes)
    let investor = if log.topics.len() > 1 {
        Address::from(log.topics[1])
    } else {
        return Err(anyhow::anyhow!("Missing investor topic in Investment event"));
    };

    // Non-indexed data: (uint256 amount, uint256 tokenAmount)
    let tokens = abi::decode(
        &[abi::ParamType::Uint(256), abi::ParamType::Uint(256)],
        &log.data,
    )
    .map_err(|e| anyhow::anyhow!("ABI decode error: {}", e))?;

    let amount_raw = match &tokens[0] {
        Token::Uint(v) => *v,
        _ => return Err(anyhow::anyhow!("Invalid amount type")),
    };

    let token_amount_raw = match &tokens[1] {
        Token::Uint(v) => *v,
        _ => return Err(anyhow::anyhow!("Invalid tokenAmount type")),
    };

    // USDC uses 6 decimals
    let amount_usdc = amount_raw.as_u128() as f64 / 1_000_000.0;
    // Royalty tokens use 18 decimals
    let token_amount = token_amount_raw.as_u128() as f64 / 1e18;

    Ok((investor, amount_usdc, token_amount))
}

/// Record an investment event in PostgreSQL.
async fn record_investment(
    pool: &sqlx::PgPool,
    tx_hash: &str,
    wallet_address: &str,
    amount_usdc: f64,
    token_amount: f64,
    block_number: u64,
) -> Result<()> {
    sqlx::query(
        "INSERT INTO investments (investment_id, tx_hash, wallet_address, amount_usdc, token_amount, block_number, status, verified_at)
         VALUES ($1, $2, $3, $4, $5, $6, 'CONFIRMED', NOW())
         ON CONFLICT (tx_hash) DO UPDATE SET status = 'CONFIRMED', verified_at = NOW()"
    )
    .bind(tx_hash) // Use tx_hash as investment_id for chain-discovered events
    .bind(tx_hash)
    .bind(wallet_address.to_lowercase())
    .bind(amount_usdc)
    .bind(token_amount)
    .bind(block_number as i64)
    .execute(pool)
    .await?;

    tracing::info!("Recorded investment: tx={}, amount={} USDC", tx_hash, amount_usdc);
    Ok(())
}

/// Verify a specific transaction hash against expected parameters.
#[allow(dead_code)]
pub async fn verify_transaction(
    rpc_url: &str,
    tx_hash: &str,
    expected_contract: &str,
    expected_amount: f64,
) -> Result<bool> {
    let provider = Provider::<Http>::try_from(rpc_url)?;
    let tx_hash: H256 = tx_hash.parse()?;

    let receipt = provider
        .get_transaction_receipt(tx_hash)
        .await?
        .ok_or_else(|| anyhow::anyhow!("Transaction not found"))?;

    // Check transaction succeeded
    if receipt.status != Some(1.into()) {
        return Ok(false);
    }

    // Check it went to the right contract
    let expected_addr: Address = expected_contract.parse()?;
    if receipt.to != Some(expected_addr) {
        return Ok(false);
    }

    // Decode Investment events from receipt logs to verify amount
    for log in &receipt.logs {
        if let Ok((_, amount_usdc, _)) = decode_investment_log(log) {
            // Allow 1% slippage tolerance
            let diff = (amount_usdc - expected_amount).abs();
            let tolerance = expected_amount * 0.01;
            if diff <= tolerance {
                return Ok(true);
            }
        }
    }

    // No matching Investment event found with expected amount
    Ok(false)
}
