//! Transaction Verification Service
//!
//! Verifies blockchain transactions by checking receipts and decoding event logs.
//! This is the core "trust" logic — it confirms that money actually moved on-chain.

use anyhow::{anyhow, Result};
use ethers::prelude::*;
use ethers::abi::AbiDecode;
use std::sync::Arc;
use tracing;

/// Result of verifying a transaction on-chain.
#[derive(Debug)]
pub struct VerificationResult {
    pub confirmed: bool,
    pub block_number: u64,
    pub gas_used: u64,
    pub investor_address: String,
    pub amount: U256,
    pub token_amount: U256,
}

/// Verify a Crowdsale investment transaction.
///
/// Checks:
/// 1. Transaction exists and succeeded (status == 1)
/// 2. Transaction was sent to the correct Crowdsale contract
/// 3. Decodes the Investment event to extract actual amounts
pub async fn verify_investment_tx(
    rpc_url: &str,
    tx_hash: &str,
    expected_crowdsale: &str,
) -> Result<VerificationResult> {
    let provider = Provider::<Http>::try_from(rpc_url)?;
    let provider = Arc::new(provider);

    let tx_hash: H256 = tx_hash
        .parse()
        .map_err(|_| anyhow!("Invalid transaction hash format"))?;

    // Fetch receipt
    let receipt = provider
        .get_transaction_receipt(tx_hash)
        .await?
        .ok_or_else(|| anyhow!("Transaction not found — may still be pending"))?;

    // Check success
    let status = receipt
        .status
        .ok_or_else(|| anyhow!("Transaction status unknown (pre-Byzantium?)"))?;

    if status != U64::from(1) {
        return Ok(VerificationResult {
            confirmed: false,
            block_number: 0,
            gas_used: 0,
            investor_address: String::new(),
            amount: U256::zero(),
            token_amount: U256::zero(),
        });
    }

    // Check contract address
    let expected_addr: Address = expected_crowdsale
        .parse()
        .map_err(|_| anyhow!("Invalid crowdsale address"))?;

    let tx_to = receipt.to.ok_or_else(|| anyhow!("Contract creation tx, not an investment"))?;
    if tx_to != expected_addr {
        return Err(anyhow!(
            "Transaction was sent to {} but expected {}",
            tx_to,
            expected_addr
        ));
    }

    // Decode the Investment event from logs
    // Event: Investment(address indexed investor, uint256 amount, uint256 tokenAmount)
    let investment_topic = H256::from(ethers::utils::keccak256(
        "Investment(address,uint256,uint256)",
    ));

    let investment_log = receipt
        .logs
        .iter()
        .find(|log| log.topics.first() == Some(&investment_topic))
        .ok_or_else(|| anyhow!("No Investment event found in transaction logs"))?;

    // Topic[1] is the indexed investor address
    let investor_address = format!("{:#x}", Address::from(investment_log.topics[1]));

    // Decode non-indexed parameters (amount, tokenAmount) from data
    let decoded = ethers::abi::decode(
        &[ethers::abi::ParamType::Uint(256), ethers::abi::ParamType::Uint(256)],
        &investment_log.data,
    )?;

    let amount = decoded[0].clone().into_uint().unwrap_or(U256::zero());
    let token_amount = decoded[1].clone().into_uint().unwrap_or(U256::zero());

    let block_number = receipt.block_number.map(|b| b.as_u64()).unwrap_or(0);
    let gas_used = receipt.gas_used.map(|g| g.as_u64()).unwrap_or(0);

    tracing::info!(
        "Verified investment: investor={}, amount={}, tokens={}, block={}",
        investor_address,
        amount,
        token_amount,
        block_number
    );

    Ok(VerificationResult {
        confirmed: true,
        block_number,
        gas_used,
        investor_address,
        amount,
        token_amount,
    })
}

/// Check if a transaction hash is still pending (not yet mined).
pub async fn is_tx_pending(rpc_url: &str, tx_hash: &str) -> Result<bool> {
    let provider = Provider::<Http>::try_from(rpc_url)?;
    let hash: H256 = tx_hash.parse().map_err(|_| anyhow!("Invalid tx hash"))?;

    let receipt = provider.get_transaction_receipt(hash).await?;
    Ok(receipt.is_none())
}
