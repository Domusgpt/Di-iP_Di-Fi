# Solana Migration Analysis
**Date:** 2026-02-01
**Target:** Migrating IdeaCapital from EVM (Polygon) to SVM (Solana).

---

## 1. Executive Summary

Moving to Solana represents a fundamental shift from a "Contract-Centric" to a "Program-Centric" architecture. While Solana offers 100x throughput and sub-second finality (crucial for our "Reactive Indexing"), the migration cost is high due to the complete rewrite of the Smart Contract and Vault layers.

**Recommendation:** **Wait for Q4 2026.** The current EVM stack (Polygon Amoy) is sufficient for Alpha. Migrate only if gas costs exceed $0.05/transaction or latency becomes a user churn factor.

---

## 2. Technical Impact Analysis

### A. Smart Contracts (The Hardest Part)
*   **Current:** Solidity (EVM). Objects are contracts with internal state.
*   **Target:** Rust / Anchor (SVM). Programs are stateless; state is stored in separate PDAs (Program Derived Addresses).
*   **Effort:** **High (4-6 weeks).** We must rewrite `IPNFT`, `RoyaltyToken`, and `Governance` from scratch.
    *   `IPNFT` -> Metaplex Core or Token Extensions (Token-2022).
    *   `DividendVault` -> A new Anchor program managing a PDA for each distribution.

### B. The Vault (Rust Backend)
*   **Current:** Uses `ethers-rs` to listen to EVM logs.
*   **Target:** Use `solana-client` and `solana-sdk`.
*   **Effort:** **Medium (2-3 weeks).**
    *   Merkle Tree logic (`tiny-keccak`) is reusable (Solana uses SHA256/Keccak too).
    *   `ChainWatcher` logic needs a total rewrite to use Solana's WebSocket subscription (Geyser plugin is overkill for now).

### C. The Face (Flutter)
*   **Current:** `walletconnect_flutter_v2` / `reown_appkit`.
*   **Target:** `solana_mobile_client` (SAGA Tools).
*   **Effort:** **Medium.**
    *   Solana's mobile stack is excellent (Mobile Wallet Adapter).
    *   We would lose the broad compatibility of WalletConnect but gain deep integration with Solana Saga phones.

### D. ZKP (Zero-Knowledge)
*   **Current:** Groth16 / SnarkJS. Verifier is a Solidity contract.
*   **Target:** Solana BPF Verifier.
*   **Challenge:** Solana compute units (CU) are strict. verifying Groth16 on-chain is expensive. We might need to use Light Protocol or a specialized ZK-coprocessor.

---

## 3. Strategic Cost/Benefit

| Feature | EVM (Polygon) | SVM (Solana) | Winner |
|---------|---------------|--------------|--------|
| **Throughput** | ~50-100 TPS | ~4,000+ TPS | Solana |
| **Finality** | 2-5 seconds | 400ms | Solana |
| **Dev Ecosystem** | Mature (Hardhat, Foundry) | Rapidly Evolving (Anchor) | EVM |
| **Talent Pool** | Massive | Growing | EVM |
| **Mobile UX** | Good (MetaMask) | Best-in-Class (Saga/Phantom) | Solana |

---

## 4. Migration Roadmap (Hypothetical)

If we proceed, the track is:

1.  **Phase 1: Anchor Learning:** Rewrite `Crowdsale.sol` in Anchor.
2.  **Phase 2: Vault Adapter:** Abstract the `ChainWatcher` trait in Rust to support both `EVM` and `SVM` providers.
3.  **Phase 3: Dual-Chain:** Launch on Solana while keeping Polygon active (bridged assets).
