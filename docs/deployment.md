# IdeaCapital -- Production Deployment Playbook

> This document covers infrastructure requirements, step-by-step deployment procedures, environment configuration, CI/CD, and monitoring for the IdeaCapital platform.

---

## Table of Contents

1. [Infrastructure Requirements](#infrastructure-requirements)
2. [Deployment Steps](#deployment-steps)
3. [Environment Variables](#environment-variables)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Monitoring](#monitoring)
6. [Local Development with Docker Compose](#local-development-with-docker-compose)

---

## Infrastructure Requirements

### Google Cloud Platform

The following GCP services are required:

| Service | Purpose |
|---|---|
| **Cloud Functions (Gen 2)** | TypeScript backend -- "The Nervous System." API routing, Firestore triggers, Pub/Sub event handlers. |
| **Firestore** | Primary data store for user profiles, invention documents, feed data, comments, likes, and conversation history. |
| **Cloud Pub/Sub** | Asynchronous event bus connecting all services. Six topics defined in `infra/pubsub/topics.yaml`. |
| **Cloud Storage** | User-uploaded files: voice notes, sketches, images, concept art. |
| **Vertex AI** | Gemini 1.5 Pro model access for the Brain agent. Requires the Vertex AI API enabled on the project. |
| **Cloud Run** | Container hosting for the Brain (Python/FastAPI) and Vault (Rust/Axum) services. |
| **Artifact Registry** | Docker image storage for Brain and Vault container images. |
| **Cloud SQL (PostgreSQL 16)** | Vault's financial ledger -- the source of truth for investment records, dividend distributions, and transaction verification. |

### Blockchain

| Requirement | Details |
|---|---|
| **Target Chain** | EVM-compatible chain: Polygon PoS (production) or Base (alternative). Polygon Mumbai for testnet. |
| **Smart Contracts** | Four Solidity contracts: `IPNFT.sol` (ERC-721), `RoyaltyToken.sol` (ERC-20), `Crowdsale.sol`, `DividendVault.sol` |
| **RPC Provider** | Alchemy, Infura, or equivalent JSON-RPC endpoint for the target chain |
| **USDC** | The platform's settlement currency. Requires the USDC contract address on the target chain. |

### Firebase

| Component | Purpose |
|---|---|
| **Firebase Auth** | User authentication (email, Google Sign-In) |
| **Firestore Security Rules** | Access control for client-side reads/writes (`infra/firestore/firestore.rules`) |
| **Firebase Hosting** | Optional: hosting for Flutter web build |

---

## Deployment Steps

### Prerequisites

- Google Cloud CLI (`gcloud`) authenticated and configured
- Firebase CLI (`firebase`) authenticated
- Node.js 20+ and npm
- Python 3.11+
- Rust 1.76+ with `cargo`
- Docker and Docker Compose
- Hardhat (`npx hardhat`) for contract deployment
- Flutter SDK for mobile/web builds

---

### Step 1: Smart Contracts

Deploy the four Solidity contracts to the target chain. Contracts must be deployed before the Vault can watch for on-chain events.

```bash
cd contracts
npm ci
```

Configure the deployment in `hardhat.config.ts` with the target network RPC URL and deployer private key. Then deploy:

```bash
npx hardhat compile
npx hardhat test                          # Verify all tests pass first
npx hardhat run scripts/deploy.ts --network <target-network>
```

After deployment, record the following contract addresses in your `.env` file:

- `IPNFT_ADDRESS` -- The ERC-721 patent NFT contract
- `CROWDSALE_ADDRESS` -- The USDC-to-token exchange contract
- `DIVIDEND_VAULT_ADDRESS` -- The Merkle-based dividend claims contract
- `USDC_CONTRACT_ADDRESS` -- The USDC token address on the target chain

Verify contracts on the block explorer for the target chain (Polygonscan, Basescan, etc.).

---

### Step 2: Firebase

Deploy Cloud Functions, Firestore rules, Firestore indexes, and Storage rules:

```bash
cd backend/functions
npm ci
cd ../..

firebase deploy --only functions,firestore,storage --project <project-id>
```

This deploys:
- **Cloud Functions** from `backend/functions/src/` -- the TypeScript API router, Pub/Sub event handlers, and Firestore triggers.
- **Firestore security rules** from `infra/firestore/firestore.rules`.
- **Firestore indexes** from `infra/firestore/firestore.indexes.json`.

---

### Step 3: Pub/Sub Topics and Subscriptions

Create all Pub/Sub topics defined in `infra/pubsub/topics.yaml`:

```bash
# Create topics
gcloud pubsub topics create invention.created --project=<project-id>
gcloud pubsub topics create ai.processing --project=<project-id>
gcloud pubsub topics create ai.processing.complete --project=<project-id>
gcloud pubsub topics create investment.pending --project=<project-id>
gcloud pubsub topics create investment.confirmed --project=<project-id>
gcloud pubsub topics create patent.status.updated --project=<project-id>
```

Create the required subscriptions:

```bash
# Brain subscribes to AI processing requests
gcloud pubsub subscriptions create ai-processing-brain-sub \
  --topic=ai.processing \
  --ack-deadline=120 \
  --project=<project-id>

# Vault subscribes to investment pending events
gcloud pubsub subscriptions create investment-pending-vault-sub \
  --topic=investment.pending \
  --ack-deadline=120 \
  --project=<project-id>

# TypeScript backend subscriptions (handled by Cloud Functions Pub/Sub triggers)
# These are automatically created by Firebase when Cloud Functions are deployed
# with onMessagePublished triggers for:
#   - ai.processing.complete
#   - investment.confirmed
#   - invention.created
#   - patent.status.updated
```

---

### Step 4: The Brain (Python/FastAPI on Cloud Run)

Build and deploy the Brain container to Cloud Run.

```bash
# Build the Docker image
cd brain
docker build -t <region>-docker.pkg.dev/<project-id>/ideacapital/brain:latest .

# Push to Artifact Registry
docker push <region>-docker.pkg.dev/<project-id>/ideacapital/brain:latest

# Deploy to Cloud Run
gcloud run deploy ideacapital-brain \
  --image=<region>-docker.pkg.dev/<project-id>/ideacapital/brain:latest \
  --port=8081 \
  --region=<region> \
  --project=<project-id> \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=<project-id>,VERTEX_AI_PROJECT=<project-id>,VERTEX_AI_LOCATION=us-central1" \
  --memory=1Gi \
  --timeout=120s \
  --min-instances=0 \
  --max-instances=10 \
  --allow-unauthenticated
```

**Key configuration:**
- **Port:** 8081 (set via `BRAIN_PORT` env var and Dockerfile `EXPOSE`)
- **Timeout:** 120 seconds to allow for LLM response generation
- **Memory:** At least 1Gi recommended for LLM processing
- The service account must have `Vertex AI User` and `Pub/Sub Publisher` IAM roles

---

### Step 5: The Vault (Rust/Axum on Cloud Run)

Build and deploy the Vault container to Cloud Run.

```bash
# Build the Docker image
cd vault
docker build -t <region>-docker.pkg.dev/<project-id>/ideacapital/vault:latest .

# Push to Artifact Registry
docker push <region>-docker.pkg.dev/<project-id>/ideacapital/vault:latest

# Deploy to Cloud Run
gcloud run deploy ideacapital-vault \
  --image=<region>-docker.pkg.dev/<project-id>/ideacapital/vault:latest \
  --port=8080 \
  --region=<region> \
  --project=<project-id> \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=<project-id>,RPC_URL=<blockchain-rpc-url>,DATABASE_URL=<cloud-sql-connection-string>" \
  --add-cloudsql-instances=<project-id>:<region>:<instance-name> \
  --memory=512Mi \
  --timeout=60s \
  --min-instances=0 \
  --max-instances=10 \
  --allow-unauthenticated
```

**Key configuration:**
- **Port:** 8080 (set via `VAULT_PORT` env var and Dockerfile `EXPOSE`)
- **Cloud SQL:** Use the `--add-cloudsql-instances` flag to connect via the Cloud SQL Auth Proxy
- **DATABASE_URL format:** `postgres://user:password@/ideacapital?host=/cloudsql/<project-id>:<region>:<instance-name>`
- The service account must have `Cloud SQL Client` and `Pub/Sub Publisher` IAM roles

**Cloud SQL Setup:**

```bash
# Create PostgreSQL instance
gcloud sql instances create ideacapital-vault \
  --database-version=POSTGRES_16 \
  --tier=db-f1-micro \
  --region=<region> \
  --project=<project-id>

# Create database
gcloud sql databases create ideacapital \
  --instance=ideacapital-vault \
  --project=<project-id>

# Set user password
gcloud sql users set-password postgres \
  --instance=ideacapital-vault \
  --password=<secure-password> \
  --project=<project-id>
```

Run the migration scripts from `vault/migrations/` against the Cloud SQL database to create the required schema.

---

### Step 6: Flutter Client

#### Web

```bash
cd frontend/ideacapital
flutter build web --release
```

Deploy the output from `build/web/` to Firebase Hosting, a CDN, or any static hosting provider:

```bash
firebase deploy --only hosting --project <project-id>
```

#### Android

```bash
cd frontend/ideacapital
flutter build apk --release
# or for app bundle:
flutter build appbundle --release
```

Upload the APK or AAB to Google Play Console.

#### iOS

```bash
cd frontend/ideacapital
flutter build ipa --release
```

Upload the IPA via Xcode or Transporter to App Store Connect.

---

## Environment Variables

All environment variables are documented in `.env.example` at the repository root. Copy this file to `.env` and fill in values for your target environment.

### Complete Variable Reference

#### Firebase / GCP

| Variable | Description | Example |
|---|---|---|
| `GOOGLE_CLOUD_PROJECT` | GCP project ID used by all services | `ideacapital-prod` |
| `FIREBASE_PROJECT_ID` | Firebase project ID (usually same as GCP) | `ideacapital-prod` |
| `GCLOUD_SERVICE_ACCOUNT_KEY` | Path to service account JSON (local dev only) | `./service-account.json` |

#### Blockchain

| Variable | Description | Example |
|---|---|---|
| `RPC_URL` | JSON-RPC endpoint for the target chain | `https://polygon-mainnet.g.alchemy.com/v2/KEY` |
| `CHAIN_ID` | EVM chain ID | `137` (Polygon), `8453` (Base) |
| `DEPLOYER_PRIVATE_KEY` | Private key for contract deployment (never commit) | `0x...` |
| `USDC_CONTRACT_ADDRESS` | USDC token address on target chain | `0x...` |

#### The Vault (Rust)

| Variable | Description | Example |
|---|---|---|
| `VAULT_PORT` | HTTP port for the Vault service | `8080` |
| `VAULT_DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host:5432/ideacapital` |
| `VAULT_REDIS_URL` | Redis connection string (caching/rate limiting) | `redis://localhost:6379` |

#### The Brain (Python)

| Variable | Description | Example |
|---|---|---|
| `BRAIN_PORT` | HTTP port for the Brain service | `8081` |
| `VERTEX_AI_PROJECT` | GCP project with Vertex AI enabled | `ideacapital-prod` |
| `VERTEX_AI_LOCATION` | Vertex AI region | `us-central1` |
| `GOOGLE_PATENTS_API_KEY` | Google Patents API key (optional, mock without) | `AIza...` |
| `PINECONE_API_KEY` | Pinecone vector DB key (future use) | `...` |
| `PINECONE_INDEX` | Pinecone index name (future use) | `inventions` |

#### Pub/Sub Topics

| Variable | Description | Default |
|---|---|---|
| `PUBSUB_TOPIC_INVENTION_CREATED` | Topic for new inventions | `invention.created` |
| `PUBSUB_TOPIC_INVESTMENT_PENDING` | Topic for pending investments | `investment.pending` |
| `PUBSUB_TOPIC_INVESTMENT_CONFIRMED` | Topic for confirmed investments | `investment.confirmed` |
| `PUBSUB_TOPIC_AI_PROCESSING` | Topic for AI processing requests | `ai.processing` |
| `PUBSUB_TOPIC_PATENT_STATUS` | Topic for patent status updates | `patent.status.updated` |

#### IPFS

| Variable | Description | Example |
|---|---|---|
| `PINATA_API_KEY` | Pinata IPFS pinning API key | `...` |
| `PINATA_SECRET_KEY` | Pinata IPFS pinning secret | `...` |

### Security Notes

- Never commit `.env` files or private keys to version control.
- `DEPLOYER_PRIVATE_KEY` should only be set in secure CI/CD secrets or a local `.env` file.
- In production, use GCP Secret Manager for sensitive values and reference them in Cloud Run configurations.
- The `GCLOUD_SERVICE_ACCOUNT_KEY` path is for local development only. In Cloud Run, use the default service account with appropriate IAM roles.

---

## CI/CD Pipeline

The CI/CD pipeline is defined in `.github/workflows/ci.yml` and runs on every push to `main` or `claude/**` branches, as well as on pull requests targeting `main`.

### Pipeline Jobs

The pipeline consists of six independent jobs that run in parallel:

#### 1. Contracts (Solidity)

```
Working directory: contracts/
Steps: npm ci -> npx hardhat compile -> npx hardhat test
```

Compiles all four Solidity contracts and runs the Hardhat test suite. Verifies that contract changes do not break compilation or existing tests.

#### 2. Backend (TypeScript)

```
Working directory: backend/functions/
Steps: npm ci -> npx tsc --noEmit -> npm test --if-present
```

Type-checks the TypeScript Cloud Functions code. Runs tests if a test script is defined in `package.json`.

#### 3. Vault (Rust)

```
Working directory: vault/
Steps: cargo check -> cargo test -> cargo clippy -- -D warnings
```

Checks that the Rust code compiles, runs the test suite, and enforces lint-free code via Clippy with warnings treated as errors. Uses `Swatinem/rust-cache` for dependency caching.

#### 4. Brain (Python)

```
Working directory: brain/
Steps: pip install -r requirements.txt -> pip install pytest pytest-asyncio mypy ruff -> ruff check src/ -> python -m pytest tests/ -v --tb=short
```

Installs dependencies, runs the Ruff linter against all source code, and executes the pytest test suite. Tests run in mock mode (no GCP credentials required).

#### 5. Docker Build Check

```
Steps: docker build -t ideacapital-vault ./vault -> docker build -t ideacapital-brain ./brain
```

Validates that both Dockerfiles build successfully. Catches issues with missing files, broken COPY instructions, or dependency installation failures.

#### 6. Schema Consistency

```
Steps: npx ajv-cli validate -s schemas/InventionSchema.json --valid
```

Validates that `schemas/InventionSchema.json` is a syntactically valid JSON Schema. This schema is the canonical data contract shared across all four services (Python, Rust, TypeScript, Dart).

### Adding Deployment Steps

The current CI pipeline handles validation only. To add continuous deployment, extend the workflow with deployment jobs that depend on the validation jobs:

```yaml
deploy-brain:
  needs: [brain, docker]
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    - uses: google-github-actions/setup-gcloud@v2
    - run: |
        gcloud builds submit ./brain \
          --tag ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/ideacapital/brain:${{ github.sha }}
        gcloud run deploy ideacapital-brain \
          --image ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/ideacapital/brain:${{ github.sha }} \
          --region ${{ env.REGION }}
```

---

## Monitoring

### Firebase Console

- **Cloud Functions logs:** Monitor invocations, errors, and latency for the TypeScript backend functions.
- **Firestore usage:** Track read/write operations, document counts, and storage consumption.
- **Authentication:** Monitor active users, sign-in providers, and authentication errors.
- **Cloud Storage:** Track file uploads and bandwidth.

Access at: `https://console.firebase.google.com/project/<project-id>/overview`

### Cloud Run (Brain and Vault)

- **Request logs:** Each HTTP request to Brain or Vault is logged with status code, latency, and request path.
- **Application logs:** The Brain logs LLM processing events, Pub/Sub message handling, and errors. The Vault logs blockchain operations and financial transactions.
- **Metrics:** Monitor request count, latency percentiles (p50, p95, p99), error rate, memory utilization, and instance count.
- **Alerts:** Set up alerting policies for error rate spikes, high latency, or memory pressure.

Access at: `https://console.cloud.google.com/run?project=<project-id>`

### Cloud SQL (PostgreSQL -- Vault)

- **Query insights:** Monitor slow queries, active connections, and query throughput.
- **Storage:** Track database size growth, especially the investment and dividend tables.
- **Connections:** Monitor connection pool usage from Cloud Run instances.
- **Backups:** Verify automated backups are running and test restoration procedures regularly.

Access at: `https://console.cloud.google.com/sql/instances?project=<project-id>`

### Cloud Pub/Sub

- **Topic metrics:** Monitor published message count and size for each topic.
- **Subscription metrics:** Track acknowledged vs. unacknowledged messages, delivery latency, and dead-letter queue size.
- **Key subscriptions to monitor:**
  - `ai-processing-brain-sub` -- Backlog indicates the Brain is falling behind on AI processing requests.
  - `investment-pending-vault-sub` -- Backlog indicates the Vault is not processing investment verifications.

Access at: `https://console.cloud.google.com/cloudpubsub?project=<project-id>`

### Blockchain

- **Contract interactions:** Monitor contract calls, events, and gas usage through the block explorer for the target chain.
  - Polygon: `https://polygonscan.com/address/<contract-address>`
  - Base: `https://basescan.org/address/<contract-address>`
- **Key events to monitor:**
  - `IPNFT`: Minting events (new patent NFTs)
  - `Crowdsale`: Investment transactions (USDC inflows)
  - `DividendVault`: Claim events (dividend distributions)
- **RPC health:** Monitor RPC endpoint latency and error rates. Set up a fallback RPC provider if the primary becomes unreliable.

### Recommended Alert Policies

| Condition | Severity | Action |
|---|---|---|
| Brain Cloud Run error rate > 5% for 5 minutes | High | Page on-call engineer |
| Vault Cloud Run error rate > 1% for 5 minutes | Critical | Page on-call engineer (financial service) |
| Pub/Sub subscription backlog > 100 messages | Medium | Investigate processing bottleneck |
| Cloud SQL connection count > 80% of limit | Medium | Scale connection pool or instance |
| Cloud SQL storage > 80% capacity | Low | Plan capacity increase |
| Blockchain RPC errors > 10 in 5 minutes | High | Switch to fallback RPC provider |

---

## Local Development with Docker Compose

For local development, all services can be run together using `docker-compose.yml` at the repository root:

```bash
docker compose up            # Start all services
docker compose up vault      # Start only the Vault and its dependencies (PostgreSQL, Redis)
docker compose up brain      # Start only the Brain
docker compose logs -f vault # Follow Vault logs
```

### Local Service Map

| Service | Port | Description |
|---|---|---|
| `vault` | 8080 | Rust financial backend |
| `brain` | 8081 | Python AI agent (mock mode by default) |
| `firebase` | 4000 (UI), 5001 (Functions), 8082 (Firestore), 9099 (Auth), 8085 (Pub/Sub) | Firebase emulator suite |
| `hardhat` | 8545 | Local EVM blockchain |
| `postgres` | 5432 | PostgreSQL (user: `ideacapital`, password: `ideacapital`, db: `ideacapital`) |
| `redis` | 6379 | Redis cache |

### Notes

- The Brain runs in **mock mode** by default in Docker Compose (no Vertex AI credentials). Set `VERTEX_AI_PROJECT` and mount a service account key to enable real LLM calls.
- The Firebase emulator's Firestore port is remapped to **8082** to avoid conflict with the Vault on port 8080.
- PostgreSQL initializes its schema from migration files mounted from `vault/migrations/`.
- The Hardhat node provides a local EVM blockchain for contract testing at `http://localhost:8545`.
