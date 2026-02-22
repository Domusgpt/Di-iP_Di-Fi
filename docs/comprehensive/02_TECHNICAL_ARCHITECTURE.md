# IdeaCapital: Technical Architecture

This document details the system design, components, and data flow of the IdeaCapital platform (v0.6.0-alpha). The system uses an **Event-Driven Microservices Architecture** orchestrated via Google Cloud Pub/Sub.

## 1. High-Level Architecture

The platform is composed of four primary services:

1.  **The Face (Flutter):** User interface for inventors and investors.
2.  **The Vault (Rust):** High-security financial engine and off-chain indexer.
3.  **The Brain (Python):** AI agent for analysis and Zero-Knowledge Proof (ZKP) generation.
4.  **The Ledger (EVM):** Smart contracts on Polygon (Amoy Testnet).

### Communication Flow
*   **User Action:** Investment -> Blockchain Transaction (Frontend -> Ledger).
*   **Event:** `InvestmentEvent` -> Vault (via RPC/listener) -> Pub/Sub `investment.confirmed` -> Backend.
*   **Analysis:** Backend -> Pub/Sub `invention.analyze` -> Brain (AI/ZKP) -> Firestore.
*   **Dividend:** Revenue -> Vault (API) -> Merkle Tree -> Ledger (Claim).

---

## 2. The Vault (Rust) — Financial Engine

The Vault is the "Trust Layer," responsible for handling all fiat-to-crypto and crypto-to-crypto logic that requires high precision and security.

### Key Components
*   **Dividend Distribution (`vault/src/routes/dividends.rs`):**
    *   Calculates pro-rata shares for token holders.
    *   **Fail-Closed Compliance:** Before distribution, it queries the `compliance_fee_splits` table. If this query fails or returns invalid data, the entire transaction aborts. This ensures strict adherence to Arizona ABS legal structures (e.g., mandatory lawyer fees).
    *   **Audit Logging:** Every distribution event is recorded in the `audit_logs` table with immutable inputs/outputs.
*   **Merkle Compatibility (`vault/src/crypto/merkle.rs`):**
    *   Implements a custom Merkle Tree using `tiny-keccak`.
    *   **Critical Fix:** Solidity's `keccak256` behaves differently than standard SHA-3. The Rust implementation uses a "Double Hash" strategy (`keccak(keccak(abi.encode(address, amount)))`) to ensure the Merkle Root generated off-chain matches the on-chain verification in `MerkleProof.sol`.
*   **Database:**
    *   Uses PostgreSQL with `sqlx` for compile-time checked queries.
    *   Stores `investments`, `dividend_distributions`, and `dividend_claims`.

### Dependencies
*   `rust_decimal`: For precise financial calculations (avoiding floating-point errors).
*   `tiny-keccak`: For EVM-compatible hashing.
*   `axum`: High-performance async web framework.

---

## 3. The Brain (Python) — AI & ZK Agent

The Brain handles heavy computational tasks, including Large Language Model (LLM) analysis and Zero-Knowledge Proof generation.

### Key Components
*   **ZKP Circuit (`brain/src/zkp/novelty.circom`):**
    *   A Circom 2.0 circuit that proves knowledge of a "preimage" (the invention text) that hashes to a public commitment, without revealing the text itself.
    *   Currently scaffolded to use `Poseidon(4)` hash function.
*   **Proof Generation (`brain/src/services/zkp_service.py`):**
    *   Wraps the `snarkjs` command-line tool to generate `.zkey` and `.wasm` artifacts.
    *   Exposes a `POST /prove_novelty` endpoint.
*   **AI Analysis (`brain/src/agents/invention_agent.py`):**
    *   Uses Vertex AI (Gemini Pro) to analyze invention descriptions for novelty, market fit, and technical feasibility.

### Dependencies
*   `fastapi`: Web framework.
*   `circom`/`snarkjs`: ZK toolchain.
*   `google-cloud-aiplatform`: Vertex AI SDK.

---

## 4. The Ledger (Solidity) — Smart Contracts

The "Source of Truth" for ownership and governance.

### Key Contracts
*   **IP-NFT (`contracts/contracts/IPNFT.sol`):**
    *   ERC-721 token representing the patent/invention.
    *   **Story Protocol Integration:** Automatically registers the invention as an IP Asset on Story Protocol via `StoryProtocolAdapter.sol` upon minting.
*   **Governance (`contracts/contracts/Governance.sol`):**
    *   Implements "Liquid Democracy."
    *   Uses a **Reputation Token** (Soulbound ERC-20) for voting weight.
    *   Allows delegation of votes to domain experts.

---

## 5. The Face (Flutter) — User Experience

A cross-platform (iOS, Android, Web) application built with Flutter.

### Key Features
*   **Vib3 Identity (`frontend/ideacapital/lib/widgets/vib3_watermark.dart`):**
    *   Generates a unique, deterministic visual identity for each invention based on its UUID.
    *   **Performance:** Uses `CustomPainter` on mobile and WebGL shaders on web (via `@vib3code/sdk`).
*   **Wallet Integration:**
    *   Uses `WalletConnect` (via `reown_appkit`) to connect to mobile wallets (MetaMask, Rainbow).
    *   **Mock Mode:** If the environment is `dev`, it simulates wallet connections for UI testing without real funds.
*   **Investment Flow (`lib/screens/invest/invest_screen.dart`):**
    *   Directly interacts with the `Crowdsale` smart contract.
    *   Monitors transaction status via the Vault's indexing service.

---

## 6. Infrastructure

*   **Hosting:** Google Cloud Run (Serverless containers).
*   **Database:** Cloud SQL (PostgreSQL).
*   **Messaging:** Cloud Pub/Sub.
*   **IaC:** Terraform configurations in `infra/terraform/` manage the entire stack.
