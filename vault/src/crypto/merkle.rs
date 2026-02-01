//! Merkle Tree for Dividend Distribution
//!
//! Generates Merkle proofs for gas-efficient on-chain dividend claims.
//! Each leaf is: keccak256(abi.encodePacked(address, amount))
//! The root is stored on-chain in the DividendVault contract.

use sha2::{Sha256, Digest};
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

    // Generate proofs for each original claim
    let mut proofs = Vec::new();
    for i in 0..claims.len() {
        let mut proof = Vec::new();
        let mut idx = num_leaves + i;

        while idx > 1 {
            let sibling = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
            proof.push(hex::encode(tree[sibling]));
            idx /= 2;
        }

        proofs.push(proof);
    }

    (root, proofs)
}

fn hash_leaf(address: &str, amount: &str) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(address.as_bytes());
    hasher.update(amount.as_bytes());
    let result = hasher.finalize();
    let mut output = [0u8; 32];
    output.copy_from_slice(&result);
    output
}

fn hash_pair(left: &[u8; 32], right: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    // Sort to ensure deterministic ordering
    if left <= right {
        hasher.update(left);
        hasher.update(right);
    } else {
        hasher.update(right);
        hasher.update(left);
    }
    let result = hasher.finalize();
    let mut output = [0u8; 32];
    output.copy_from_slice(&result);
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_merkle_tree_single_claim() {
        let claims = vec![ClaimLeaf {
            wallet_address: "0xAbC123".to_string(),
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
                wallet_address: "0xAAA".to_string(),
                amount_wei: "1000000".to_string(),
            },
            ClaimLeaf {
                wallet_address: "0xBBB".to_string(),
                amount_wei: "2000000".to_string(),
            },
            ClaimLeaf {
                wallet_address: "0xCCC".to_string(),
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
}
