# IdeaCapital — Architecture & Development Track

> **Decentralized Invention Capital Platform**
> "GoFundMe with ROI" — A social-first hybrid where users fund inventions in exchange for future commercial royalties.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Phase 1: Task Decomposition (The "Lashing")](#phase-1-task-decomposition)
3. [Phase 2: Sub-Agent Assignments](#phase-2-sub-agent-assignments)
4. [Phase 3: Non-Parallel Integration Gate](#phase-3-non-parallel-integration-gate)
5. [Phase 4: Folder Structure & Docker Setup](#phase-4-folder-structure--docker-setup)
6. [Development Roadmap](#development-roadmap)
7. [API Contracts & Integration Points](#api-contracts--integration-points)

---

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        USER (Mobile/Web)                         │
│                     Flutter + Riverpod + Reown                   │
└─────────────────────────┬────────────────────────────────────────┘
                          │ HTTPS / WebSocket
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│              FIREBASE CLOUD FUNCTIONS (Gen 2)                    │
│              TypeScript — "The Nervous System"                    │
│                                                                  │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐    │
│  │  API Router  │  │ Pub/Sub Bus  │  │  Firestore Triggers │    │
│  │  (Express)   │  │  (Events)    │  │  (User/Invention)   │    │
│  └──────┬──────┘  └──────┬───────┘  └─────────────────────┘    │
└─────────┼────────────────┼──────────────────────────────────────┘
          │                │
    ┌─────┴─────┐    ┌────┴────┐
    ▼           ▼    ▼         ▼
┌────────┐ ┌────────────┐ ┌────────────┐
│FIRESTORE│ │  THE VAULT │ │ THE BRAIN  │
│(Cache)  │ │  (Rust)    │ │ (Python)   │
│         │ │            │ │            │
│Profiles │ │ Axum API   │ │ FastAPI    │
│Feed     │ │ PostgreSQL │ │ Vertex AI  │
│Comments │ │ Blockchain │ │ LangChain  │
│Likes    │ │ Merkle     │ │ Patents    │
└─────────┘ └─────┬──────┘ └────────────┘
                   │
                   ▼
          ┌────────────────┐
          │  EVM BLOCKCHAIN │
          │  (Polygon/Base) │
          │                 │
          │  IPNFT.sol      │
          │  RoyaltyToken   │
          │  Crowdsale      │
          │  DividendVault  │
          └────────────────┘
```

---

## Phase 1: Task Decomposition

### Track A: "The Face" (Flutter + Firebase Social)
**Parallel Safe** — Can be built entirely independently until the Pub/Sub integration point.

| # | Task | Blocker? | Depends On |
|---|------|----------|------------|
| A1 | Flutter project scaffold + navigation (GoRouter) | No | — |
| A2 | Firebase Auth (email/Google sign-in) | No | — |
| A3 | Firestore user profile CRUD | No | A2 |
| A4 | Discovery Feed UI (infinite scroll, filter chips) | No | A1 |
| A5 | Invention detail screen | No | A4 |
| A6 | "Agent Composer" creation flow (text/voice/sketch input) | No | A2 |
| A7 | Invention card widget + funding progress bar | No | A4 |
| A8 | Profile screen (stats, badges, wallet display) | No | A3 |
| A9 | WalletConnect/Reown integration | **BLOCKER** | B3 (contracts deployed) |
| A10 | Investment flow screen (USDC amounts, tx signing) | **BLOCKER** | A9, B4 |

### Track B: "The Vault" (Rust + Solidity)
**Sequential dependency chain** — Contracts must deploy before Rust can watch them.

| # | Task | Blocker? | Depends On |
|---|------|----------|------------|
| B1 | Rust Axum scaffold + PostgreSQL schema | No | — |
| B2 | Token calculation logic + unit tests | No | — |
| B3 | Solidity contracts (IPNFT, RoyaltyToken, Crowdsale, DividendVault) | No | — |
| B4 | Contract deployment scripts + local Hardhat tests | No | B3 |
| B5 | Chain watcher (ethers-rs event listener) | **BLOCKER** | B4 (deployed contracts) |
| B6 | Pub/Sub integration (subscribe `investment.pending`, publish `investment.confirmed`) | **BLOCKER** | B5, Integration Gate |
| B7 | Merkle tree for dividend distribution | No | — |
| B8 | Dividend claim API endpoints | **BLOCKER** | B7, B4 |

### Track C: "The Brain" (Python AI)
**Parallel Safe** — Fully independent until Pub/Sub integration.

| # | Task | Blocker? | Depends On |
|---|------|----------|------------|
| C1 | FastAPI scaffold + health check | No | — |
| C2 | LLM service (Vertex AI / Gemini wrapper) | No | — |
| C3 | Invention structuring prompt + JSON output parsing | No | C2 |
| C4 | Patent search service (Google Patents API) | No | — |
| C5 | Agent conversation flow (multi-turn refinement) | No | C3 |
| C6 | Pub/Sub listener (subscribe `ai.processing`, publish `ai.processing.complete`) | **BLOCKER** | Integration Gate |
| C7 | Concept art generation (Imagen 3) | No | C2 |

### Track D: Infrastructure
**Must be done first or in parallel.**

| # | Task | Blocker? | Depends On |
|---|------|----------|------------|
| D1 | docker-compose.yml (all services) | No | — |
| D2 | Firebase emulator config | No | — |
| D3 | Firestore security rules | No | — |
| D4 | Pub/Sub topic definitions | No | — |
| D5 | PostgreSQL migration scripts | No | — |
| D6 | CI/CD pipeline (GitHub Actions) | No | D1 |

---

## Phase 2: Sub-Agent Assignments

### Sub-Agent A: "The Face"
**Assigned:** Flutter/Dart Frontend & Firebase Social Graph

**Immediate Tasks (build now):**
1. Wire up `FeedScreen` with real Firestore queries (filter by trending/newest/near-goal)
2. Complete `CreateInventionScreen` with file upload to Firebase Storage
3. Implement `LoginScreen` with Google Sign-In provider
4. Build comment/like system on invention detail screen
5. Add shimmer loading states and pull-to-refresh

**Integration Point:** STOPS at the HTTP boundary.
- Calls `POST /api/inventions/analyze` → does NOT call Brain directly
- Calls `POST /api/investments/:id/invest` → does NOT talk to blockchain
- Reads Firestore documents → does NOT query blockchain state
- All backend communication goes through the TypeScript Cloud Functions API

**Pub/Sub boundary:** `invention.created` (published by TypeScript when user hits "Publish")

---

### Sub-Agent B: "The Vault"
**Assigned:** Rust Financial Backend & Solidity Smart Contracts

**Immediate Tasks (build now):**
1. Complete `token_calculator.rs` — all formulas with comprehensive tests
2. Complete `merkle.rs` — Merkle tree generation matching Solidity's `MerkleProof.verify()`
3. Deploy contracts to local Hardhat node and verify all tests pass
4. Implement `verify_transaction()` in `chain_watcher.rs` with ethers-rs
5. Write PostgreSQL queries for investment recording and dividend claims

**Integration Point:** STOPS at the Pub/Sub boundary.
- Subscribes to: `investment.pending` topic
- Publishes to: `investment.confirmed` topic
- Does NOT write to Firestore directly (that's TypeScript's job)
- Does NOT serve the Flutter app directly (goes through Cloud Functions)

**Critical constraint:** The Merkle proof format in `merkle.rs` MUST match the leaf encoding in `DividendVault.sol`:
```
leaf = keccak256(abi.encodePacked(keccak256(abi.encode(address, amount))))
```

---

### Sub-Agent C: "The Brain"
**Assigned:** Python AI Agent & Patent Analysis

**Immediate Tasks (build now):**
1. Implement `structure_invention()` with real Gemini Pro prompt + JSON output parsing
2. Build the multi-turn conversation flow with state persistence in Firestore
3. Implement `search_prior_art()` with Google Patents API integration
4. Add mock responses for all endpoints (enables frontend testing without Vertex AI)
5. Write prompt templates for each phase (Ingest → Drill Down → Validate)

**Integration Point:** STOPS at the Pub/Sub boundary.
- Subscribes to: `ai.processing` topic
- Publishes to: `ai.processing.complete` topic
- Reads/writes conversation state in Firestore
- Does NOT serve the Flutter app directly

---

## Phase 3: Non-Parallel Integration Gate

### NON-PARALLEL INTEGRATION TASKS

These tasks **MUST be done by the Chief Architect** after all sub-agents deliver their work. Running these in parallel across teams would cause schema drift, security holes, or runtime failures.

| # | Task | Why Non-Parallel | Risk if Parallelized |
|---|------|-----------------|---------------------|
| I1 | **Finalize `InventionSchema.json`** — the canonical data contract that Python writes, Rust reads, TypeScript caches, and Flutter displays | All 4 services depend on this shape. Any drift = runtime crashes | Schema mismatch between services |
| I2 | **Pub/Sub message format contracts** — exact JSON shape for each topic | Publisher and subscriber must agree on format | Silent data loss or parsing errors |
| I3 | **Merkle proof encoding alignment** — Rust's `merkle.rs` must produce proofs that Solidity's `MerkleProof.verify()` accepts | Crypto mismatch = locked funds | Users unable to claim dividends |
| I4 | **Firebase security rules audit** — verify rules match actual data access patterns | Rules written before code may not match reality | Data exposed or writes blocked |
| I5 | **Environment variable contract** — single `.env.example` that all services agree on | Different services need different vars from the same source | Services fail to start |
| I6 | **Docker network configuration** — ensure all services can reach each other by hostname | Service discovery must be deterministic | Inter-service calls fail |
| I7 | **USDC decimal handling alignment** — Solidity uses 6 decimals, Rust uses `Decimal`, TypeScript uses `number`, Python uses `float` | Precision mismatch = money bugs | Financial calculation errors |
| I8 | **End-to-end investment flow test** — Flutter → TypeScript → Pub/Sub → Rust → Blockchain → Pub/Sub → TypeScript → Firestore → Flutter | Crosses every service boundary | Untested integration = production failures |

---

## Phase 4: Folder Structure & Docker Setup

### Repository Layout

```
ideacapital/
├── ARCHITECTURE.md              ← You are here
├── docker-compose.yml           ← Lashes all services together
├── .env.example                 ← All environment variables
├── .gitignore
│
├── schemas/
│   └── InventionSchema.json     ← THE canonical data contract
│
├── frontend/ideacapital/        ← SUB-AGENT A: The Face
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── app.dart             ← GoRouter navigation
│       ├── models/              ← Dart mirrors of InventionSchema
│       ├── providers/           ← Riverpod state (auth, feed, wallet)
│       ├── screens/             ← Feed, Auth, Invention, Invest, Profile
│       ├── widgets/             ← InventionCard, FundingProgress
│       └── services/            ← ApiService (HTTP to Cloud Functions)
│
├── backend/functions/           ← THE NERVOUS SYSTEM (TypeScript)
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── index.ts             ← Function exports
│       ├── api.ts               ← Express router
│       ├── middleware/auth.ts   ← Firebase Auth verification
│       ├── services/            ← Invention, Investment, Profile APIs
│       ├── events/              ← Pub/Sub handlers + chain indexer
│       └── models/types.ts      ← TypeScript interfaces
│
├── vault/                       ← SUB-AGENT B: The Vault (Rust)
│   ├── Cargo.toml
│   ├── Dockerfile
│   ├── migrations/              ← PostgreSQL schema
│   └── src/
│       ├── main.rs              ← Axum server
│       ├── routes/              ← Investments, Dividends API
│       ├── services/            ← Chain watcher, token calculator
│       ├── crypto/              ← Merkle tree implementation
│       └── models/              ← Investment, Dividend structs
│
├── brain/                       ← SUB-AGENT C: The Brain (Python)
│   ├── pyproject.toml
│   ├── requirements.txt
│   ├── Dockerfile
│   └── src/
│       ├── main.py              ← FastAPI server
│       ├── agents/              ← Invention analysis agent
│       ├── services/            ← LLM, Patent search, Pub/Sub
│       ├── models/              ← Pydantic models (mirrors schema)
│       └── prompts/             ← LLM prompt templates
│
├── contracts/                   ← SOLIDITY SMART CONTRACTS
│   ├── package.json
│   ├── hardhat.config.ts
│   ├── contracts/
│   │   ├── IPNFT.sol            ← ERC-721 patent NFT
│   │   ├── RoyaltyToken.sol     ← ERC-20 revenue shares
│   │   ├── Crowdsale.sol        ← USDC → Token exchange
│   │   └── DividendVault.sol    ← Merkle-based dividend claims
│   ├── scripts/deploy.ts
│   └── test/IPNFT.test.ts
│
└── infra/                       ← INFRASTRUCTURE
    ├── firebase.json            ← Emulator configuration
    ├── firestore/
    │   ├── firestore.rules      ← Security rules
    │   └── firestore.indexes.json
    └── pubsub/
        └── topics.yaml          ← All Pub/Sub topic definitions
```

### Docker Compose Services

| Service | Port | Role |
|---------|------|------|
| `vault` | 8080 | Rust financial backend |
| `brain` | 8081 | Python AI agent |
| `firebase` | 4000 (UI), 5001 (Functions), 8082 (Firestore), 9099 (Auth), 8085 (Pub/Sub) | Firebase emulator suite |
| `hardhat` | 8545 | Local EVM blockchain |
| `postgres` | 5432 | Financial ledger |
| `redis` | 6379 | Cache / rate limiting |

**Start everything:** `docker compose up`
**Start one service:** `docker compose up vault`

---

## Development Roadmap

### Phase 1: Social MVP (Months 1-2)
**Goal:** Prove people want to share and browse inventions.

- [x] Flutter UI scaffold (Feed, Auth, Create, Profile)
- [x] Firebase Functions API (CRUD, Auth middleware)
- [x] AI Agent mock responses (Brain with fallback data)
- [ ] Wire Flutter to real Firestore queries
- [ ] Implement Google Sign-In in Flutter
- [ ] Complete Agent Composer with file upload
- [ ] Mock "Pledge" investment (non-binding)
- [ ] Deploy to Firebase hosting + TestFlight

### Phase 2: Web3 Integration (Months 3-4)
**Goal:** Connect real money and ownership.

- [x] Solidity contracts (IPNFT, RoyaltyToken, Crowdsale, DividendVault)
- [x] Rust Vault scaffold (API, PostgreSQL, Merkle)
- [ ] Deploy contracts to Polygon Mumbai testnet
- [ ] Integrate WalletConnect/Reown in Flutter
- [ ] Implement chain watcher in Rust
- [ ] End-to-end investment flow (USDC → Tokens)
- [ ] Build the blockchain indexer (chain → Firestore sync)

### Phase 3: Market & Dividends (Months 5+)
**Goal:** Liquidity and commercialization.

- [ ] Dividend distribution (Merkle proofs + on-chain claims)
- [ ] Secondary market for RoyaltyToken trading
- [ ] Governance voting (token-weighted)
- [ ] Legal wrapper integration
- [ ] Production deployment (Polygon mainnet)

---

## API Contracts & Integration Points

### Pub/Sub Event Flow

```
FLUTTER                TYPESCRIPT              RUST VAULT           PYTHON BRAIN
  │                       │                       │                      │
  │──POST /analyze───────▶│                       │                      │
  │                       │──ai.processing───────────────────────────────▶│
  │                       │                       │                      │
  │                       │◀──ai.processing.complete─────────────────────│
  │◀──Firestore update───│                       │                      │
  │                       │                       │                      │
  │──POST /invest────────▶│                       │                      │
  │                       │──investment.pending──▶│                      │
  │                       │                       │──watch chain──┐      │
  │                       │                       │               │      │
  │                       │                       │◀──confirmed───┘      │
  │                       │◀─investment.confirmed─│                      │
  │◀──Firestore update───│                       │                      │
```

### Service-to-Service Boundaries

| From | To | Protocol | Boundary |
|------|----|----------|----------|
| Flutter | TypeScript | HTTPS | `/api/*` endpoints |
| TypeScript | Brain | Pub/Sub | `ai.processing` topic |
| Brain | TypeScript | Pub/Sub | `ai.processing.complete` topic |
| TypeScript | Vault | Pub/Sub | `investment.pending` topic |
| Vault | TypeScript | Pub/Sub | `investment.confirmed` topic |
| Vault | PostgreSQL | TCP | Direct SQL connection |
| Vault | Blockchain | JSON-RPC | ethers-rs provider |
| TypeScript | Firestore | gRPC | Firebase Admin SDK |
| Flutter | Firestore | gRPC | Firebase client SDK (reads) |
