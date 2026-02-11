# Roadmap to v0.6.0 (Alpha)

> **Theme:** Hardening & Real-World Readiness
> **Target Date:** 2026-03-01

Following the "DeSci & Compliance" (v0.5.1) milestone, this roadmap focuses on eliminating technical debt and activating the "Real" implementations of mocked services.

## 1. Compliance & Security (The Vault)

- [ ] **Fix Floating Point Math:** Refactor `dividends.rs` to use `rust_decimal` exclusively.
- [ ] **Migration Cleanup:** Squashing migrations or creating a clean `003` delta.
- [ ] **Audit Logs:** Add a table `audit_logs` to track every `distribute_dividends` call with immutable inputs/outputs.

## 2. Deep Tech (The Brain)

- [ ] **ZKP Activation:**
    -   Compile `novelty.circom` to `.wasm` and `.zkey`.
    -   Replace `zkp_service.py` mock with `snarkjs` subprocess call.
    -   Verify proof generation time < 10s.
- [ ] **Multimodal AI:**
    -   Un-mock `_analyze_sketch` and `_transcribe_voice`.
    -   Test with real Gemini 1.5 Flash API keys.

## 3. Decentralized Governance (Contracts)

- [ ] **Voting Power Snapshots:** Implement `ERC20Votes` style checkpointing in `ReputationToken.sol` to prevent double-voting via transfers (even though it's soulbound, delegation changes need snapshots).
- [ ] **Proposal Execution:** Add `TimelockController` integration to actually execute on-chain actions (e.g., changing fee splits) based on vote outcomes.

## 4. User Experience (The Face)

- [ ] **Marketplace UI:** Screen for trading `RoyaltyTokens` (secondary market).
- [ ] **WalletConnect Deep Link:** Ensure mobile wallets open correctly from the app on iOS/Android.
- [ ] **Performance:** optimize `Vib3Watermark` painting.

## 5. Infrastructure

- [ ] **Terraform:** Provision real GCP resources (Cloud Run, Postgres, Pub/Sub).
- [ ] **CI/CD:** Add `cargo audit` and `npm audit` to GitHub Actions pipeline.
