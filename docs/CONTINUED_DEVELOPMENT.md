# IdeaCapital — Continued Development Guide

> **Status:** v0.5.1 (Beta)
> **Last Updated:** 2024

This document outlines the current state of the IdeaCapital ecosystem, recent architectural wins, and the strategic roadmap for the next development sprints.

---

## 1. System Status Overview

| Service | Status | Description |
|---------|--------|-------------|
| **The Face** (Flutter) | 🟡 **Beta** | UI functional. "Vib3 Watermark" implemented. Investment flow UI pending. |
| **The Nervous System** (TS) | 🟢 **Stable** | Pub/Sub event bus wired. Reactive Indexing (Vault -> UI) active. Tests hardened. |
| **The Vault** (Rust) | 🟢 **Stable** | Merkle trees fixed (Keccak256). Chain Watcher & Pub/Sub listener active. ABS Schema ready. |
| **The Brain** (Python) | 🟡 **Alpha** | Mocked endpoints. Needs full Vertex AI / Gemini integration. |
| **Contracts** (Solidity) | 🟢 **Audit-Ready** | ERC-721/20 standard. Crowdsale logic verified. |

---

## 2. Recent Wins (v0.5.x)

### 🚀 Reactive Indexing
We successfully closed the feedback loop between the Blockchain and the UI.
- **Flow:** User Invests → Blockchain Event → Vault Listener → Pub/Sub `investment.confirmed` → Cloud Function → Firestore Update → Flutter Stream.
- **Impact:** Zero-polling latency for investment confirmations.

### 🎨 Vib3 Identity Protocol
Pivoted from heavy full-screen shaders to a performant **Procedural Watermark**.
- **Logic:** `Vib3Identity` maps `invention_id` → 23 geometry types, rotation, color.
- **Tech:** Uses `CustomPainter` on Mobile (fast) and `@vib3code/sdk` (WebGL) on Web.
- **Benefit:** Unique visual fingerprint for every patent without stalling the UI thread.

### ⚖️ Arizona ABS Compliance
Laid the groundwork for "Fee Sharing" between lawyers and DAO members.
- **Schema:** Added `compliance_fee_splits` table to the Vault.
- **Docs:** See [docs/compliance-abs.md](docs/compliance-abs.md) for the legal-technical spec.

### 🔒 Reliability Fixes
- **Merkle Trees:** Switched Rust implementation to `tiny-keccak` to match Solidity's double-hash requirement (`keccak(keccak(abi.encode(...)))`).
- **Safety:** Refactored Vault to return `Result` types instead of panicking on invalid inputs.
- **Type Safety:** Removed `any` casts from Backend unit tests.

---

## 3. Immediate Next Steps (Tactical)

### A. Finish the Investment Flow (The Face)
Currently, the backend supports investments, but the Flutter UI for it is stubbed.
- **Task:** Implement `InvestmentScreen` in Flutter.
- **Features:** Connect Wallet (Reown), Input USDC Amount, Call `Crowdsale.invest()`.

### B. Implement ABS Logic (The Vault)
The schema exists, but the Rust logic (`token_calculator.rs`) ignores it.
- **Task:** Update `token_calculator.rs` to query `compliance_fee_splits`.
- **Logic:** Deduct Lawyer % -> Deduct Platform % -> Distribute remainder to Token Holders.

### C. ZKP Novelty Verification (Strategic)
To solve the "Inventor's Dilemma" (proving novelty without disclosure).
- **Task:** Sketch a Circom circuit that proves "Document Hash X existed at Time T" without revealing Document Content.

---

## 4. Developer Experience

### Integration Testing ("The Lashing")
We created `scripts/run_integration_test.sh` to spin up the full stack.
```bash
# Runs Postgres + Pub/Sub + Vault + Python Test Script
./scripts/run_integration_test.sh
```

### Mobile vs Web
- **Mobile:** Uses `vib3_watermark_stub.dart` to avoid `dart:ui_web` crashes.
- **Web:** Uses `vib3_watermark_web.dart` to render WebGL.
- **Build:** Always run `dart run build_runner build` after model changes.

---

## 5. Known Issues
- **Vault:** `token_calculator.rs` does not yet read `compliance_fee_splits`.
- **Brain:** Voice/Sketch analysis is mocked. Needs real Gemini API keys in `.env`.
