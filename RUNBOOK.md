# IdeaCapital Deployment & Testing Runbook

This document provides a comprehensive guide to setting up, launching, and testing the IdeaCapital platform. It addresses the requirement for automated setup using Google Service Account keys and other secrets.

## 1. Repository Overview

The repository consists of four main components:
*   **Frontend:** Flutter mobile/web app (`frontend/ideacapital`).
*   **Backend:** TypeScript Cloud Functions (`backend/functions`).
*   **Brain:** Python AI Agent (`brain/`).
*   **Vault:** Rust Financial Engine (`vault/`).
*   **Contracts:** Solidity Smart Contracts (`contracts/`).

All components communicate via **Google Cloud Pub/Sub** and use **PostgreSQL** (Vault) and **Firestore** (Social) for data storage.

## 2. Prerequisites

Ensure the following tools are installed on your machine or CI/CD environment:
*   **Docker & Docker Compose** (Essential for local infrastructure)
*   **Node.js 18+ & npm** (For Backend & Contracts)
*   **Rust 1.76+** (For Vault)
*   **Python 3.11+** (For Brain)
*   **Flutter 3.16+** (For Frontend)

## 3. Environment Variables & Secrets

To run the system, you must provide the following secrets. These are managed via the `.env` file in the root directory.

### Google Cloud Platform (GCP)
*   `GOOGLE_CLOUD_PROJECT`: Your GCP Project ID (e.g., `ideacapital-dev`).
*   `FIREBASE_PROJECT_ID`: Your Firebase Project ID.
*   `GCLOUD_SERVICE_ACCOUNT_KEY`: **Critical**. Path to your JSON key file (e.g., `./service-account.json`). Ensure this account has Pub/Sub Editor and Firestore User roles.

### Blockchain (Polygon/Base)
*   `RPC_URL`: Alchemy/Infura endpoint.
*   `CHAIN_ID`: Chain ID (e.g., 80001 for Mumbai).
*   `DEPLOYER_PRIVATE_KEY`: Private key of the deployer wallet (0x...).
*   `USDC_CONTRACT_ADDRESS`: Address of the USDC token on the target chain.

### AI Services
*   `VERTEX_AI_PROJECT`: GCP Project for Vertex AI.
*   `VERTEX_AI_LOCATION`: Region (e.g., `us-central1`).
*   `GOOGLE_PATENTS_API_KEY`: API Key for patent search.
*   `SERPAPI_KEY`: API Key for Google Search results.
*   `PINECONE_API_KEY`: Vector DB API Key.
*   `PINECONE_INDEX`: Name of the Pinecone index.

### Other
*   `WALLETCONNECT_PROJECT_ID`: For frontend wallet connection.
*   `PINATA_API_KEY` & `SECRET`: For IPFS storage.

## 4. Automated Setup & Testing

We have provided a script to automate the setup process using your Service Account key.

### Usage

1.  **Place your Google Service Account JSON key** in a secure location (e.g., `./secrets/sa-key.json`).
2.  **Run the automation script:**

```bash
python3 scripts/automate_setup.py --key-file ./secrets/sa-key.json
```

**What this script does:**
1.  Verifies the Service Account Key exists.
2.  Generates a `.env` file from `.env.example` if it doesn't exist.
3.  Updates the `GCLOUD_SERVICE_ACCOUNT_KEY` path in `.env`.
4.  Checks for required tools (Docker, npm, etc.).
5.  **Launches the Integration Test Suite** (`scripts/run_integration_test.sh`).

### Manual Step: Editing Secrets
The script creates the `.env` file, but you **must** manually populate the API keys (Vertex, Pinecone, RPC URL) if they are not already set in your environment variables. Open `.env` and fill in the placeholders.

## 5. Branch Status Analysis

We analyzed the repository branches to identify unmerged work.

*   **`main`**: The primary branch.
*   **`fix/merkle-hashing-mismatch-...`**: This branch contains a critical fix for Merkle Tree hashing to match Solidity's double-hashing standard.
    *   **Status:** ✅ **Already Merged/Present in Main.** We inspected `vault/src/crypto/merkle.rs` on `main` and confirmed it contains the double-hashing logic (`keccak256(keccak256(...))`). No action is needed.
*   **`claude/ideacapital-platform-design...`**: Contains the Vib3 SDK 2.0 integration.
    *   **Status:** ✅ **Already Merged/Present in Main.** We inspected `frontend/ideacapital/web/vib3-loader.js` and confirmed it is using version 2.0.1 of the SDK.
*   **Other branches**: Appear to be stale or documentation updates.

## 6. Launching the Full Stack

To run the entire system locally for development:

1.  **Start Infrastructure:**
    ```bash
    docker compose up -d
    ```

2.  **Run Services:**
    *   **Contracts:** `cd contracts && npx hardhat compile`
    *   **Backend:** `cd backend/functions && npm run serve`
    *   **Brain:** `cd brain && uvicorn src.main:app --reload`
    *   **Vault:** `cd vault && cargo run`
    *   **Frontend:** `cd frontend/ideacapital && flutter run`

Refer to `docs/getting-started.md` for more detailed instructions.
