# IdeaCapital -- Getting Started

A comprehensive onboarding guide for developers joining the IdeaCapital project. By the end of this document you will have all five services running locally and be able to execute the full test suite.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Setup](#repository-setup)
3. [Environment Variables](#environment-variables)
4. [Docker Compose Infrastructure](#docker-compose-infrastructure)
5. [Installing Dependencies](#installing-dependencies)
6. [Running Services Individually](#running-services-individually)
7. [Running Everything with Docker Compose](#running-everything-with-docker-compose)
8. [Running Tests](#running-tests)
9. [Flutter Code Generation](#flutter-code-generation)
10. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)
11. [Further Reading](#further-reading)

---

## Prerequisites

Ensure the following tools are installed and available on your `PATH` before proceeding.

| Tool | Minimum Version | Purpose | Install Guide |
|------|----------------|---------|---------------|
| **Node.js** | 18+ (20 recommended) | TypeScript backend, Hardhat, Firebase CLI | [nodejs.org](https://nodejs.org/) |
| **npm** | 9+ | Package management for Node projects | Ships with Node.js |
| **Rust** | 1.76+ | The Vault financial engine | [rustup.rs](https://rustup.rs/) |
| **Python** | 3.11+ | The Brain AI agent | [python.org](https://www.python.org/) |
| **Flutter** | 3.16+ (Dart SDK >= 3.2) | Cross-platform mobile/web frontend | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| **Docker** | 24+ | Container runtime for infrastructure services | [docker.com](https://docs.docker.com/get-docker/) |
| **Docker Compose** | v2 (plugin) | Multi-container orchestration | Included with Docker Desktop |
| **Firebase CLI** | 13+ | Firebase emulator suite | `npm install -g firebase-tools` |

### Verifying Your Environment

```bash
node --version          # v20.x.x
npm --version           # 10.x.x
rustc --version         # rustc 1.76+
python3 --version       # Python 3.11+
flutter --version       # Flutter 3.16+
docker --version        # Docker 24+
docker compose version  # Docker Compose v2.x.x
firebase --version      # 13.x.x
```

---

## Repository Setup

```bash
# 1. Clone the repository
git clone https://github.com/Domusgpt/Di-iP_Di-Fi.git
cd Di-iP_Di-Fi

# 2. Copy the environment template
cp .env.example .env
```

Open `.env` in your editor and fill in the required values. See the next section for details.

---

## Environment Variables

The `.env.example` file at the project root is the single source of truth for configuration. Every service reads from this file (or receives its values via Docker Compose environment injection).

### Required Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `GOOGLE_CLOUD_PROJECT` | All | GCP project ID (use `ideacapital-dev` for local) |
| `FIREBASE_PROJECT_ID` | Backend | Firebase project identifier |
| `GCLOUD_SERVICE_ACCOUNT_KEY` | Backend, Brain | Path to GCP service account JSON |
| `RPC_URL` | Vault, Contracts | Blockchain RPC endpoint. For local dev: `http://localhost:8545` |
| `CHAIN_ID` | Vault, Contracts | EVM chain ID. For local Hardhat: `31337` |
| `DEPLOYER_PRIVATE_KEY` | Contracts | Private key for contract deployment (Hardhat default is fine locally) |
| `USDC_CONTRACT_ADDRESS` | Vault, Contracts | USDC token contract address on target chain |
| `VAULT_PORT` | Vault | Port for the Rust Vault server (default: `8080`) |
| `VAULT_DATABASE_URL` | Vault | PostgreSQL connection string |
| `VAULT_REDIS_URL` | Vault | Redis connection string |
| `BRAIN_PORT` | Brain | Port for the Python Brain server (default: `8081`) |
| `VERTEX_AI_PROJECT` | Brain | Vertex AI project for Gemini Pro access |
| `VERTEX_AI_LOCATION` | Brain | Vertex AI region (e.g., `us-central1`) |

### Optional Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `GOOGLE_PATENTS_API_KEY` | Brain | Google Patents API key for prior art search |
| `PINECONE_API_KEY` | Brain | Pinecone vector DB key for semantic search |
| `PINECONE_INDEX` | Brain | Pinecone index name |
| `PINATA_API_KEY` | Backend | Pinata IPFS pinning service API key |
| `PINATA_SECRET_KEY` | Backend | Pinata IPFS pinning service secret |

### Minimal Local Development `.env`

For a quick local setup with Docker-managed infrastructure, the following is sufficient:

```bash
GOOGLE_CLOUD_PROJECT=ideacapital-dev
FIREBASE_PROJECT_ID=ideacapital-dev
RPC_URL=http://localhost:8545
CHAIN_ID=31337
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
VAULT_PORT=8080
VAULT_DATABASE_URL=postgres://ideacapital:ideacapital@localhost:5432/ideacapital
VAULT_REDIS_URL=redis://localhost:6379
BRAIN_PORT=8081
VERTEX_AI_PROJECT=ideacapital-dev
VERTEX_AI_LOCATION=us-central1
```

> **Note:** The deployer private key above is Hardhat's default Account #0. Never use it on a real network.

---

## Docker Compose Infrastructure

The `docker-compose.yml` at the project root defines all infrastructure services. Here is what each service provides:

| Service | Container Port | Host Port | Purpose |
|---------|---------------|-----------|---------|
| **vault** | 8080 | `8080` | Rust/Axum financial backend (blockchain ops, dividends, Merkle trees) |
| **brain** | 8081 | `8081` | Python/FastAPI AI agent (invention structuring, patent analysis) |
| **firebase** | 4000, 5001, 8080, 9099, 8085 | `4000` (Emulator UI), `5001` (Cloud Functions), `8082` (Firestore), `9099` (Auth), `8085` (Pub/Sub) | Firebase emulator suite running TypeScript Cloud Functions |
| **hardhat** | 8545 | `8545` | Local EVM blockchain node for smart contract development |
| **postgres** | 5432 | `5432` | PostgreSQL 16 -- the Vault's financial ledger |
| **redis** | 6379 | `6379` | Redis 7 -- caching and rate limiting for the Vault |

### Network

All services are connected via a shared Docker bridge network named `ideacapital`. Services reference each other by container name (e.g., `postgres:5432`, `redis:6379`, `hardhat:8545`).

### Volumes

- `pgdata` -- Persistent volume for PostgreSQL data. Survives container restarts.
- `./vault/migrations` is mounted into the PostgreSQL container at `/docker-entrypoint-initdb.d/`, so the database schema is applied automatically on first start.

### Port Conflict Note

The Firestore emulator internally runs on port `8080`, but it is remapped to host port `8082` to avoid a conflict with the Vault service, which also uses `8080`. If you run services outside Docker, keep this mapping in mind.

---

## Installing Dependencies

Run these commands from the project root. They are independent and can be executed in parallel across terminals:

```bash
# Smart Contracts (Node/npm)
cd contracts && npm install && cd ..

# TypeScript Backend (Node/npm)
cd backend/functions && npm install && cd ../..

# Python Brain (pip)
cd brain && pip install -r requirements.txt && cd ..
# Or with dev dependencies:
cd brain && pip install -e ".[dev]" && cd ..

# Flutter Frontend (Dart)
cd frontend/ideacapital && flutter pub get && cd ../..

# Rust Vault (Cargo -- fetches deps on first build)
cd vault && cargo build && cd ..
```

---

## Running Services Individually

Each service can be started independently for focused development. Open a separate terminal for each.

### Terminal 1: Infrastructure (Docker)

Start just the supporting infrastructure:

```bash
docker compose up -d postgres redis hardhat
```

### Terminal 2: Smart Contracts (compile and deploy to local Hardhat)

```bash
cd contracts
npx hardhat compile
npx hardhat run scripts/deploy.ts --network localhost
```

### Terminal 3: Firebase Emulators (TypeScript Backend)

```bash
cd backend/functions
npm run build
cd ../../infra
firebase emulators:start --project ideacapital-dev
```

The emulator UI will be available at `http://localhost:4000`. Cloud Functions run on port `5001`, Firestore on `8082` (when accessed from host), Auth on `9099`, and Pub/Sub on `8085`.

### Terminal 4: The Brain (Python AI Agent)

```bash
cd brain
uvicorn src.main:app --host 0.0.0.0 --port 8081 --reload
```

The Brain API will be available at `http://localhost:8081`. The `--reload` flag enables auto-reload on file changes.

### Terminal 5: The Vault (Rust Financial Engine)

```bash
cd vault
cargo run
```

The Vault API will be available at `http://localhost:8080`. Set `RUST_LOG=ideacapital_vault=debug,tower_http=info` for verbose logging.

### Terminal 6: Flutter Frontend

```bash
cd frontend/ideacapital
flutter run
```

Flutter will prompt you to choose a target device (Chrome for web, connected device for mobile, or an emulator).

---

## Running Everything with Docker Compose

To start all services at once:

```bash
# Start all services in the foreground (see all logs)
docker compose up

# Or start in the background (detached)
docker compose up -d

# View logs for a specific service
docker compose logs -f vault
docker compose logs -f brain

# Start only a specific service and its dependencies
docker compose up vault       # Starts vault + postgres + redis
docker compose up brain       # Starts brain + firebase

# Stop everything
docker compose down

# Stop and remove all data (including PostgreSQL volume)
docker compose down -v
```

> **Note:** The Flutter frontend is not included in Docker Compose because Flutter development is best done natively with hot reload. Run it separately with `flutter run`.

---

## Running Tests

### Smart Contracts (Hardhat + Mocha/Chai)

```bash
cd contracts
npx hardhat test
```

Tests cover all four contracts: IPNFT, RoyaltyToken, Crowdsale, and DividendVault. They run against an in-memory Hardhat network, so no external services are required.

### TypeScript Backend (Build Verification + Lint + Jest)

```bash
cd backend/functions

# Type-check and compile (strict mode catches most issues)
npm run build

# Lint
npm run lint

# Unit tests (if configured)
npm run test
```

### Python Brain (pytest)

```bash
cd brain

# Run all tests with verbose output
pytest tests/ -v

# Run with coverage (if pytest-cov is installed)
pytest tests/ -v --cov=src
```

Brain tests use mock LLM responses so they do not require Vertex AI credentials.

### Rust Vault (cargo test)

```bash
cd vault

# Run all unit and integration tests
cargo test

# Run with output for passing tests too
cargo test -- --nocapture
```

Vault unit tests cover the `token_calculator` and `merkle` modules. Integration tests may require a running PostgreSQL instance.

### Flutter Frontend

```bash
cd frontend/ideacapital

# Run unit and widget tests
flutter test

# Run a specific test file
flutter test test/models/invention_test.dart
```

---

## Flutter Code Generation

The Flutter project uses `json_serializable`, `freezed`, and `riverpod_generator`, all of which require code generation. After modifying any model class, provider, or file with `@JsonSerializable`, `@freezed`, or `@riverpod` annotations, you must regenerate the corresponding `.g.dart` and `.freezed.dart` files:

```bash
cd frontend/ideacapital

# One-time generation
dart run build_runner build

# Watch mode (auto-regenerates on save)
dart run build_runner watch

# If you encounter stale generated files, clean first
dart run build_runner build --delete-conflicting-outputs
```

> **Important:** Generated files (`*.g.dart`, `*.freezed.dart`) are git-ignored. Every developer must run `build_runner` after cloning the repo or pulling changes to models.

---

## Common Issues and Troubleshooting

### Port Already in Use

**Symptom:** `Error: listen EADDRINUSE: address already in use :::8080`

**Fix:** Another process is occupying the port. Find and stop it:

```bash
# Find the process using port 8080
lsof -i :8080

# Kill it
kill -9 <PID>
```

Or change the conflicting port in `docker-compose.yml` or your `.env` file.

### PostgreSQL Connection Refused

**Symptom:** The Vault cannot connect to PostgreSQL.

**Fix:** Ensure the `postgres` container is running and healthy:

```bash
docker compose ps postgres
docker compose logs postgres
```

If running the Vault outside Docker, make sure `VAULT_DATABASE_URL` points to `localhost:5432`, not `postgres:5432` (the latter is the Docker-internal hostname).

### Firebase Emulator Fails to Start

**Symptom:** `Could not start Firestore Emulator` or Java-related errors.

**Fix:** The Firebase emulator suite requires Java 11+. Verify:

```bash
java -version
```

If Java is missing, install it (e.g., `brew install openjdk@11` on macOS, or `sudo apt install openjdk-11-jdk` on Ubuntu).

### Hardhat Node Not Responding

**Symptom:** Contract deployment or the Vault's chain watcher cannot reach `http://localhost:8545`.

**Fix:** Ensure the Hardhat node is running:

```bash
# Via Docker
docker compose up hardhat

# Or natively
cd contracts && npx hardhat node
```

### Rust Compilation Errors on First Build

**Symptom:** Cargo fails to compile `ethers-rs` or `sqlx` dependencies.

**Fix:** Some Rust crates require system libraries:

```bash
# Ubuntu/Debian
sudo apt install pkg-config libssl-dev

# macOS
brew install openssl pkg-config
```

### Flutter `build_runner` Fails

**Symptom:** `Could not find a file named pubspec.yaml` or conflicting output errors.

**Fix:**

```bash
cd frontend/ideacapital
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Brain Cannot Reach Vertex AI

**Symptom:** `google.auth.exceptions.DefaultCredentialsError`

**Fix:** For local development, authenticate with GCP:

```bash
gcloud auth application-default login
```

Or set the `GCLOUD_SERVICE_ACCOUNT_KEY` environment variable to the path of a valid service account JSON file. For local development without real AI, the Brain falls back to mock responses.

### Docker Compose `vault` Exits Immediately

**Symptom:** The Vault container starts and then exits with code 1.

**Fix:** Check logs for the actual error:

```bash
docker compose logs vault
```

Common causes:
- PostgreSQL is not yet healthy (the `depends_on` health check should handle this, but verify).
- Missing or malformed environment variables in `.env`.

### Firestore Port Conflict (8080 vs 8082)

**Symptom:** Confusion about which port Firestore is on.

**Explanation:** The Firestore emulator runs internally on port `8080`, but `docker-compose.yml` remaps it to host port `8082` to avoid conflicting with the Vault (which also uses `8080`). When connecting to Firestore from outside Docker, use `localhost:8082`. Inside the Docker network, services use `firebase:8080`.

### USDC Decimal Precision Mismatch

**Symptom:** Investment amounts appear wrong (off by orders of magnitude).

**Explanation:** USDC uses 6 decimal places. Solidity stores raw amounts (e.g., `1000000` = 1.00 USDC). The Vault uses `NUMERIC(18, 6)` in PostgreSQL. TypeScript and Flutter should always convert before display. See the [Architecture document](architecture.md) for the full decimal handling strategy.

---

## Further Reading

| Document | Path | Description |
|----------|------|-------------|
| Architecture | [docs/architecture.md](architecture.md) | System design, data flow, technology trade-offs |
| API Reference | [docs/api-reference.md](api-reference.md) | Full REST endpoint documentation |
| Data Model | [docs/data-model.md](data-model.md) | Firestore and PostgreSQL schema reference |
| Smart Contracts | [docs/smart-contracts.md](smart-contracts.md) | Solidity contract interfaces and deployment |
| Event Architecture | [docs/event-driven-architecture.md](event-driven-architecture.md) | Pub/Sub topics, message formats, flow diagrams |
| AI Agent Guide | [docs/ai-agent-guide.md](ai-agent-guide.md) | The Brain: prompts, conversation flow, integration |
| Deployment | [docs/deployment.md](deployment.md) | Production deployment playbook |
| Security Model | [docs/security-model.md](security-model.md) | Authentication, authorization, Firestore rules |
| Canonical Schema | [schemas/InventionSchema.json](../schemas/InventionSchema.json) | The data contract shared across all services |
| Claude Code Guide | [CLAUDE.md](../CLAUDE.md) | Project conventions and quick-reference for Claude Code |
| Sub-Agent: The Face | [docs/agents/the-face.md](agents/the-face.md) | Flutter UI and TypeScript backend specification |
| Sub-Agent: The Vault | [docs/agents/the-vault.md](agents/the-vault.md) | Rust financial engine specification |
| Sub-Agent: The Brain | [docs/agents/the-brain.md](agents/the-brain.md) | Python AI agent specification |
