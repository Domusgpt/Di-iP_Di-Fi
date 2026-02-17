# IdeaCapital: Project Status & Audit Report

> **Date:** 2026-03-01
> **Version:** v0.5.2 (Alpha Candidate)
> **Author:** Jules

This document provides a "brutally honest" assessment of the current state of the IdeaCapital platform, highlighting working features, critical gaps, and the immediate roadmap.

## 1. Executive Summary

IdeaCapital is currently in a **functional prototype** state. The core financial loops (investment -> minting -> dividend distribution) are implemented but require hardening. The "Deep Tech" components (ZKP, AI) are largely scaffolded or mocked. The frontend is functional but relies on hardcoded configuration.

**Overall Health:** 🟡 **Yellow (Needs Hardening)**

---

## 2. Component Audit

### A. The Vault (Rust) — Financial Engine

| Feature | Status | Notes |
| :--- | :--- | :--- |
| **Dividend Logic** | ✅ **Working** | Correctly calculates shares and deducts fees. |
| **Compliance** | ✅ **Working** | Fail-Closed logic prevents illegal distributions. |
| **Merkle Tree** | ✅ **Working** | Validated against Solidity `MerkleProof.sol`. |
| **Input Validation** | 🔴 **Critical** | `DistributeRequest` uses `f64` (floating point) for currency inputs. This risks precision loss before conversion to `Decimal`. |
| **Database** | 🟡 **Warning** | Migrations are messy; need squashing. |

### B. The Brain (Python) — AI & ZK

| Feature | Status | Notes |
| :--- | :--- | :--- |
| **ZKP Circuit** | 🟡 **Scaffold** | `novelty.circom` exists but only proves knowledge of a preimage. It does not yet prove "novelty" against a dataset. |
| **Proof Generation** | 🔴 **Mocked** | The service currently returns dummy proofs unless configured otherwise. Real `snarkjs` integration is pending. |
| **AI Analysis** | ✅ **Working** | Integration with Vertex AI (Gemini) is functional. |

### C. The Face (Flutter) — User Interface

| Feature | Status | Notes |
| :--- | :--- | :--- |
| **Wallet Connect** | ✅ **Working** | successfully connects to MetaMask/Rainbow. |
| **Investment UI** | 🟡 **Fragile** | `InvestScreen.dart` contains hardcoded contract addresses (`0x3c4...`). These must be moved to environment configuration. |
| **Vib3 Identity** | ✅ **Working** | Performant and visually distinct. |
| **State Mgmt** | ✅ **Working** | Riverpod providers are well-structured. |

### D. The Ledger (Solidity) — Smart Contracts

| Feature | Status | Notes |
| :--- | :--- | :--- |
| **IP-NFT** | ✅ **Working** | Mints correctly and sets Token URI. |
| **Story Protocol** | ✅ **Working** | `StoryProtocolAdapter` registers assets upon minting. |
| **Governance** | 🟡 **Untested** | Liquid Democracy logic exists but lacks comprehensive unit tests for edge cases (delegation loops). |

---

## 3. Critical Issues (P0)

1.  **Floating Point Risk:** The Vault's API accepts `f64`. If a client sends `0.1` + `0.2`, the Vault might receive `0.30000000000000004`, causing strict equality checks to fail or penny-shaving errors.
    *   *Fix:* Change API DTOs to use `String` or `Decimal` directly.
2.  **Hardcoded Contracts:** The Frontend will break if deployed to a new network without a code change.
    *   *Fix:* Inject addresses via `flutter_dotenv` or a config provider.
3.  **ZKP Reality Gap:** The "Novelty Proof" is currently just a "Hash Preimage Proof."
    *   *Fix:* Expand the circuit to include a Merkle inclusion proof against a "Prior Art" tree.

## 4. Roadmap to v0.6.0 (Alpha)

The following items must be completed before the Alpha release:

1.  **Refactor Vault API:** Switch all currency inputs to `String` (parsed as `Decimal`).
2.  **Activate ZKP:** Compile the circuit and generate valid SNARKs in the Python service.
3.  **Config Injection:** Remove hardcoded addresses from Flutter.
4.  **Integration Test:** Run a full end-to-end test on the Polygon Amoy testnet.
