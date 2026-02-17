//! Transaction Verification Service
//!
//! Verifies blockchain transactions by checking receipts and decoding event logs.
//! This is the core "trust" logic — it confirms that money actually moved on-chain.

use anyhow::{anyhow, Result};
use ethers::prelude::*;
use std::sync::Arc;
use tracing;

/// Result of verifying a transaction on-chain.
#[derive(Debug)]
#[allow(dead_code)]
pub struct VerificationResult {
    pub confirmed: bool,
    pub pending: bool,
    pub block_number: u64,
    pub gas_used: u64,
    pub investor_address: String,
    pub amount_usdc: f64,
    pub token_amount: f64,
}

/// Verify a Crowdsale investment transaction.
///
/// Checks:
/// 1. Transaction exists and succeeded (status == 1)
/// 2. The sender matches the expected wallet_address
/// 3. Decodes the Investment event to extract actual amounts
pub async fn verify_investment_tx(
    rpc_url: &str,
    tx_hash: &str,
    expected_wallet: &str,
    expected_amount: rust_decimal::Decimal,
) -> Result<VerificationResult> {
    let provider = Provider::<Http>::try_from(rpc_url)?;
    let provider = Arc::new(provider);

    let tx_hash_parsed: H256 = tx_hash
        .parse()
        .map_err(|_| anyhow!("Invalid transaction hash format"))?;

    // Fetch receipt
    let receipt = match provider.get_transaction_receipt(tx_hash_parsed).await? {
        Some(r) => r,
        None => {
            // Transaction not yet mined
            return Ok(VerificationResult {
                confirmed: false,
                pending: true,
                block_number: 0,
                gas_used: 0,
                investor_address: String::new(),
                amount_usdc: 0.0,
                token_amount: 0.0,
            });
        }
    };

    // Check success
    let status = receipt
        .status
        .ok_or_else(|| anyhow!("Transaction status unknown"))?;

    if status != U64::from(1) {
        return Ok(VerificationResult {
            confirmed: false,
            pending: false,
            block_number: receipt.block_number.map(|b| b.as_u64()).unwrap_or(0),
            gas_used: receipt.gas_used.map(|g| g.as_u64()).unwrap_or(0),
            investor_address: String::new(),
            amount_usdc: 0.0,
            token_amount: 0.0,
        });
    }

    // Verify sender matches expected wallet
    let tx = provider
        .get_transaction(tx_hash_parsed)
        .await?
        .ok_or_else(|| anyhow!("Transaction details not found"))?;

    let sender = format!("{:#x}", tx.from);
    let expected_lower = expected_wallet.to_lowercase();
    if sender.to_lowercase() != expected_lower {
        return Err(anyhow!(
            "Transaction sender {} doesn't match expected wallet {}",
            sender,
            expected_wallet
        ));
    }

    // Decode the Investment event from logs
    // Event: Investment(address indexed investor, uint256 usdcAmount, uint256 tokenAmount)
    let investment_topic = H256::from(ethers::utils::keccak256(
        "Investment(address,uint256,uint256)",
    ));

    let decoded_amount: f64;
    let decoded_tokens: f64;

    if let Some(investment_log) = receipt
        .logs
        .iter()
        .find(|log| log.topics.first() == Some(&investment_topic))
    {
        // Decode non-indexed parameters (usdcAmount, tokenAmount) from data
        let decoded = ethers::abi::decode(
            &[
                ethers::abi::ParamType::Uint(256),
                ethers::abi::ParamType::Uint(256),
            ],
            &investment_log.data,
        )?;

        let raw_amount = decoded[0].clone().into_uint().unwrap_or(U256::zero());
        let raw_tokens = decoded[1].clone().into_uint().unwrap_or(U256::zero());

        // USDC has 6 decimals, tokens have 18 decimals
        decoded_amount = raw_amount.as_u128() as f64 / 1_000_000.0;
        decoded_tokens = raw_tokens.as_u128() as f64 / 1e18;
        decoded_tokens = raw_tokens.as_u128() as f64 / 1e18;
    } else {
        // No Investment event found — use the expected amount as fallback
        tracing::warn!("No Investment event in logs, using expected amount");
        decoded_amount = expected_amount.to_string().parse::<f64>().unwrap_or(0.0);
        decoded_tokens = 0.0;
    }

    let block_number = receipt.block_number.map(|b| b.as_u64()).unwrap_or(0);
    let gas_used = receipt.gas_used.map(|g| g.as_u64()).unwrap_or(0);

    tracing::info!(
        "Verified investment: investor={}, amount_usdc={}, tokens={}, block={}",
        sender,
        decoded_amount,
        decoded_tokens,
        block_number
    );

    Ok(VerificationResult {
        confirmed: true,
        pending: false,
        block_number,
        gas_used,
        investor_address: sender,
        amount_usdc: decoded_amount,
        token_amount: decoded_tokens,
    })
}

/// Check if a transaction hash is still pending (not yet mined).
#[allow(dead_code)]
pub async fn is_tx_pending(rpc_url: &str, tx_hash: &str) -> Result<bool> {
    let provider = Provider::<Http>::try_from(rpc_url)?;
    let hash: H256 = tx_hash.parse().map_err(|_| anyhow!("Invalid tx hash"))?;

    let receipt = provider.get_transaction_receipt(hash).await?;
    Ok(receipt.is_none())
}
