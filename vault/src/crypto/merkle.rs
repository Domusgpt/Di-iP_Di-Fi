//! Merkle Tree for Dividend Distribution
//!
//! Generates Merkle proofs for gas-efficient on-chain dividend claims.
//! Each leaf is: keccak256(keccak256(abi.encode(address, amount)))
//! The double hashing corresponds to Solidity's:
//! `keccak256(bytes.concat(keccak256(abi.encode(addr, amt))))`
//!
//! The root is stored on-chain in the DividendVault contract.

use tiny_keccak::{Hasher, Keccak};
use ethers::abi::Token;
use ethers::types::{Address, U256};
use std::str::FromStr;
use hex;

/// A leaf node in the Merkle tree representing a single claim.
#[derive(Debug, Clone)]
pub struct ClaimLeaf {
    pub wallet_address: String,
    pub amount_wei: String, // Amount in wei (for precision)
}

/// Build a Merkle tree from a list of claims and return (root, proofs).
pub fn build_merkle_tree(claims: &[ClaimLeaf]) -> (String, Vec<Vec<String>>) {
    if claims.is_empty() {
        return (String::new(), vec![]);
    }

    // Generate leaf hashes
    let mut leaves: Vec<[u8; 32]> = claims
        .iter()
        .map(|claim| hash_leaf(&claim.wallet_address, &claim.amount_wei))
        .collect();

    // Pad to power of 2
    let target_len = leaves.len().next_power_of_two();
    while leaves.len() < target_len {
        leaves.push([0u8; 32]);
    }

    let num_leaves = leaves.len();
    let mut tree: Vec<[u8; 32]> = vec![[0u8; 32]; 2 * num_leaves];

    // Fill leaves
    for (i, leaf) in leaves.iter().enumerate() {
        tree[num_leaves + i] = *leaf;
    }

    // Build tree bottom-up
    for i in (1..num_leaves).rev() {
        tree[i] = hash_pair(&tree[2 * i], &tree[2 * i + 1]);
    }

    let root = hex::encode(tree[1]);

    // Add "0x" prefix for consistency with standard tools
    let root = format!("0x{}", root);

    // Generate proofs for each original claim
    let mut proofs = Vec::new();
    for i in 0..claims.len() {
        let mut proof = Vec::new();
        let mut idx = num_leaves + i;

        while idx > 1 {
            let sibling = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
            // Add "0x" prefix to proof elements
            proof.push(format!("0x{}", hex::encode(tree[sibling])));
            idx /= 2;
        }

        proofs.push(proof);
    }

    (root, proofs)
}

fn hash_leaf(address: &str, amount_wei: &str) -> [u8; 32] {
    // 1. Parse inputs
    let addr = Address::from_str(address).expect("Invalid address format");
    let amt = U256::from_dec_str(amount_wei).expect("Invalid amount format");

    // 2. ABI Encode: abi.encode(address, amount)
    // This adds proper 32-byte padding to both arguments
    let encoded = ethers::abi::encode(&[Token::Address(addr), Token::Uint(amt)]);

    // 3. Inner Hash: keccak256(...)
    let mut inner_hasher = Keccak::v256();
    let mut inner_hash = [0u8; 32];
    inner_hasher.update(&encoded);
    inner_hasher.finalize(&mut inner_hash);

    // 4. Outer Hash: keccak256(inner_hash)
    // Matches Solidity: keccak256(bytes.concat(keccak256(...)))
    let mut outer_hasher = Keccak::v256();
    let mut outer_hash = [0u8; 32];
    outer_hasher.update(&inner_hash);
    outer_hasher.finalize(&mut outer_hash);

    outer_hash
}

fn hash_pair(left: &[u8; 32], right: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Keccak::v256();
    // Sort to ensure deterministic ordering (Zeppelin standard)
    if left <= right {
        hasher.update(left);
        hasher.update(right);
    } else {
        hasher.update(right);
        hasher.update(left);
    }

    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_merkle_tree_single_claim() {
        let claims = vec![ClaimLeaf {
            // Wait, ethers::Address::from_str is strict. "0xAbC123" is too short.
            // Use a real-looking fake address.
            wallet_address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F".to_string(),
            amount_wei: "1000000".to_string(),
        }];

        let (root, proofs) = build_merkle_tree(&claims);
        assert!(!root.is_empty());
        assert_eq!(proofs.len(), 1);
    }

    #[test]
    fn test_merkle_tree_multiple_claims() {
        let claims = vec![
            ClaimLeaf {
                wallet_address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F".to_string(),
                amount_wei: "1000000".to_string(),
            },
            ClaimLeaf {
                wallet_address: "0xeb8da55a0aa150d18b973523cf305342eb35197f".to_string(),
                amount_wei: "2000000".to_string(),
            },
            ClaimLeaf {
                wallet_address: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1".to_string(),
                amount_wei: "3000000".to_string(),
            },
        ];

        let (root, proofs) = build_merkle_tree(&claims);
        assert!(!root.is_empty());
        assert_eq!(proofs.len(), 3);
        // Each proof should have log2(4) = 2 elements (padded to 4 leaves)
        assert_eq!(proofs[0].len(), 2);
    }

    #[test]
    fn test_empty_claims() {
        let (root, proofs) = build_merkle_tree(&[]);
        assert!(root.is_empty());
        assert!(proofs.is_empty());
    }

    #[test]
    fn test_regression_vectors_for_solidity() {
        // These values are used in `contracts/test/MerkleCompatibility.test.ts`
        // If you change this test, you MUST update the Solidity test as well.
        let claims = vec![
            ClaimLeaf {
                wallet_address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F".to_string(),
                amount_wei: "1000000000000000000".to_string(),
            },
            ClaimLeaf {
                wallet_address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266".to_string(), // Hardhat Account #0
                amount_wei: "5000000000000000000".to_string(),
            }
        ];

        let (root, proofs) = build_merkle_tree(&claims);

        // Assert Root
        assert_eq!(root, "0x8140f9815bda3adf6750884e0c94c193c9be3e5891d90d97d4e73934124ec5b1");

        // Assert Proofs
        assert_eq!(proofs[0][0], "0x08d32c0b719aa7d191069df3aa4963442b48ab22b642e50b485c5be6e0450df5");
        assert_eq!(proofs[1][0], "0x68ac16a2532f97e96240f8ecf32dd7c2c94330f78c43d505288b9a7dace30882");
    }
}
