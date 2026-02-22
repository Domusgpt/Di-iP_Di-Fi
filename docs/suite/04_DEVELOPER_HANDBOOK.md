# IdeaCapital Developer Handbook

**Version 2.0 — March 2026**
**Welcome, Engineer.**

This handbook is your definitive guide to contributing to the IdeaCapital protocol. We are building a complex system that spans mobile apps (Flutter), cloud functions (TypeScript), high-performance finance (Rust), AI (Python), and blockchain (Solidity).

---

## 1. Getting Started

### 1.1 Prerequisites
You will need the following tools installed:
*   **Node.js 18+** (for TypeScript & Hardhat)
*   **Rust 1.76+** (for The Vault)
*   **Python 3.11+** (for The Brain)
*   **Flutter 3.16+** (for The Face)
*   **Docker & Docker Compose** (for local infra)
*   **Foundry / Hardhat** (for smart contracts)

### 1.2 Quick Start
The fastest way to spin up the entire stack is via Docker Compose:

```bash
git clone https://github.com/Domusgpt/Di-iP_Di-Fi.git
cd Di-iP_Di-Fi
cp .env.example .env   # Configure your secrets
docker compose up -d   # Starts Postgres, Firebase Emulators, Local Node
```

### 1.3 Service Health
Once running, verify services are healthy:
*   **Frontend:** `http://localhost:3000` (Web) or Emulator
*   **Firebase UI:** `http://localhost:4000`
*   **Vault API:** `http://localhost:8080/health`
*   **Brain API:** `http://localhost:8081/docs`

---

## 2. Architecture Decisions

### Why Rust for The Vault?
We chose Rust for the financial engine because:
1.  **Memory Safety:** Prevents buffer overflows and data races without a GC.
2.  **Type System:** Using `rust_decimal::Decimal` and strict types prevents financial bugs (e.g., floating point errors) at compile time.
3.  **Concurrency:** Tokio allows us to handle thousands of concurrent dividend calculations efficiently.

### Why Merkle Trees?
Directly transferring tokens to 10,000 holders on-chain costs thousands of dollars in gas.
*   **Solution:** We use a Merkle Distributor pattern. The Vault calculates shares off-chain, posts a single 32-byte root on-chain, and users claim individually.
*   **Compatibility:** Our Rust implementation matches OpenZeppelin's Solidity implementation exactly. See `vault/src/crypto/merkle.rs`.

### Why "Deep Mock" for ZKP?
Running a full ZK-SNARK proof generation (snarkjs) is slow and requires large setup files (`.zkey`).
*   **Dev Experience:** In local development, the `zkp_service` uses a "Deep Mock" that simulates the constraint checking logic in Python without the cryptographic overhead. This allows you to iterate on the flow instantly.

---

## 3. Testing Strategy

We employ a "Swiss Cheese" testing model:

1.  **Unit Tests:**
    *   **Rust:** `cargo test` (Logic, Math, Merkle)
    *   **TypeScript:** `npm test` (Cloud Functions, Firestore Rules)
    *   **Python:** `pytest` (AI Prompts, ZKP Logic)
2.  **Integration Tests:**
    *   **Solidity:** `npx hardhat test` (Contract interactions, Time travel)
    *   **Specific:** `contracts/test/MerkleCompatibility.test.ts` verifies Rust <-> Solidity compatibility using test vectors.
3.  **End-to-End (E2E):**
    *   **Script:** `scripts/run_integration_test.sh` spins up the Docker stack and runs a full investment flow simulation.

---

## 4. Deployment

### 4.1 Environments
*   **Local:** Docker Compose + Hardhat Network
*   **Testnet:** Polygon Amoy + Cloud Run (Staging)
*   **Mainnet:** Polygon Mainnet + Cloud Run (Prod)

### 4.2 CI/CD
GitHub Actions handles:
*   Linting (clippy, eslint, black)
*   Testing (cargo test, npm test, pytest)
*   Build (Docker images)
*   Deploy (Terraform -> Google Cloud)

---

## 5. Contribution Guidelines

1.  **Fork & Branch:** Create a feature branch `feat/my-feature`.
2.  **Conventional Commits:** Use `feat:`, `fix:`, `docs:`, `chore:` prefixes.
3.  **Tests:** New features must include tests.
4.  **Draft PR:** Open a draft PR early for feedback.
5.  **Review:** Requires 1 approval from a code owner.

**Join our Discord for dev chat!**
