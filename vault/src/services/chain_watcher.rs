//! Blockchain Event Watcher
//!
//! Listens to EVM events from the Crowdsale and DividendVault contracts.
//! When a transaction is confirmed on-chain, publishes `investment.confirmed`
//! to Pub/Sub so the TypeScript backend can update Firestore.

use anyhow::Result;
use ethers::prelude::*;
use std::sync::Arc;

/// Watch for Investment events on the Crowdsale contract.
pub async fn watch_crowdsale_events(
    rpc_url: &str,
    contract_address: &str,
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
        tracing::info!("Investment event detected: {:?}", log);

        // TODO: Decode log data
        // TODO: Publish to Pub/Sub `investment.confirmed`
        // TODO: Record in PostgreSQL
    }

    Ok(())
}

/// Verify a specific transaction hash against expected parameters.
pub async fn verify_transaction(
    rpc_url: &str,
    tx_hash: &str,
    expected_contract: &str,
    expected_amount: U256,
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

    // TODO: Decode input data to verify amount matches
    Ok(true)
}
