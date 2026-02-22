# IdeaCapital Developer Portal

Welcome to the IdeaCapital Developer Portal. This documentation covers the technical integration points for the platform's smart contracts, backend services, and cryptographic systems.

## Index

1.  [**Smart Contracts**](./SMART_CONTRACTS.md) - Solidity API Reference.
2.  [**Backend API**](./API_REFERENCE.md) - Rust Vault & Python Brain endpoints.
3.  [**Zero-Knowledge Proofs**](./ZKP_SPEC.md) - Circuit specifications and proving key setup.

## Architecture Overview

The IdeaCapital platform consists of three main services:

*   **The Vault (Rust):** Financial engine and off-chain indexer.
*   **The Brain (Python):** AI analysis and ZKP generation.
*   **The Ledger (EVM):** Smart contracts on Polygon (Amoy Testnet).

## Getting Started

### Prerequisites

*   **Node.js** v18+
*   **Rust** (latest stable)
*   **Python** 3.10+
*   **Circom** 2.0+
*   **Docker**

### Local Development

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/ideacapital/ideacapital.git
    cd ideacapital
    ```

2.  **Start the local environment:**
    ```bash
    docker-compose up -d
    ```

3.  **Run the integration tests:**
    ```bash
    ./scripts/run_integration_test.sh
    ```
