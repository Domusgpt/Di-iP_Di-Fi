# IdeaCapital

**Decentralized Invention Capital Platform — Where Ideas Get Funded, Protected, and Paid.**

IdeaCapital is a social funding platform that connects inventors with investors. Inventors post ideas, an AI agent structures them into patent-ready briefs, investors fund legal and prototyping costs in exchange for Royalty Tokens, and smart contracts distribute licensing revenue automatically.

```
Inventor posts idea → AI structures it → Community funds it → Smart contracts pay royalties
```

---

## How It Works

| Step | What Happens | Who Benefits |
|------|-------------|--------------|
| **1. Submit** | Inventor describes an idea (text, voice, or sketch) | Inventor gets a structured patent brief |
| **2. AI Structures** | The Brain (AI agent) generates a patent-ready document | Invention becomes investable |
| **3. Fund** | Investors back the invention with USDC via Crowdsale contract | Investors receive Royalty Tokens |
| **4. Protect** | Legal costs are covered, patent is filed | Invention is protected on-chain as IP-NFT |
| **5. Earn** | Licensing revenue is distributed via Merkle-proof dividends | Token holders receive proportional payouts |

---

## Architecture

IdeaCapital uses an **Event-Driven Architecture** with blockchain as **Source of Truth** and Firebase as **Fast Cache**. All services communicate through Google Cloud Pub/Sub.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENTS                                     │
│                    Flutter Mobile/Web                                │
│           (Social Feed · Wallet · AI Chat · Invest)                 │
└────────────────────────┬────────────────────────────────────────────┘
                         │ HTTPS / Firebase SDK
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    THE FACE — TypeScript Backend                     │
│              Firebase Cloud Functions (Gen 2) + Express              │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────────┐   │
│  │Invention │  │Investment│  │ Social   │  │  Notification     │   │
│  │ Service  │  │ Service  │  │ Service  │  │    Service        │   │
│  └────┬─────┘  └────┬─────┘  └──────────┘  └───────────────────┘   │
│       │              │                                              │
└───────┼──────────────┼──────────────────────────────────────────────┘
        │              │
        ▼              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  GOOGLE CLOUD PUB/SUB                                │
│                                                                     │
│   ai.processing ──► ai.processing.complete                          │
│   invention.created                                                 │
│   investment.pending ──► investment.confirmed                       │
│   patent.status.updated                                             │
└──────┬───────────────────────┬──────────────────────────────────────┘
       │                       │
       ▼                       ▼
┌──────────────┐      ┌──────────────┐      ┌─────────────────────┐
│  THE BRAIN   │      │  THE VAULT   │      │    EVM BLOCKCHAIN   │
│  Python/     │      │  Rust/Axum   │      │  Polygon / Base     │
│  FastAPI     │      │              │      │                     │
│              │      │  Investment  │      │  ┌───────────────┐  │
│  Gemini Pro  │      │  Verifier    │◄────►│  │   IP-NFT      │  │
│  Patent      │      │  Dividend    │      │  │ (ERC-721)     │  │
│  Search      │      │  Calculator  │      │  ├───────────────┤  │
│  LangChain   │      │  Merkle Tree │      │  │ RoyaltyToken  │  │
│              │      │  PostgreSQL  │      │  │ (ERC-20)      │  │
└──────────────┘      └──────────────┘      │  ├───────────────┤  │
                                            │  │  Crowdsale    │  │
                                            │  ├───────────────┤  │
                                            │  │ DividendVault │  │
                                            │  └───────────────┘  │
                                            └─────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter (Dart) | Cross-platform mobile/web UI |
| **Backend** | TypeScript, Firebase Functions Gen 2 | API gateway, event handlers, social logic |
| **AI Engine** | Python, FastAPI, Vertex AI (Gemini Pro) | Invention structuring, patent analysis |
| **Financial Engine** | Rust, Axum, PostgreSQL | Transaction verification, dividend distribution |
| **Smart Contracts** | Solidity, Hardhat, OpenZeppelin | IP-NFT, Royalty Tokens, Crowdsale, Dividends |
| **Blockchain** | Polygon / Base (EVM) | Source of truth for ownership and payments |
| **Event Bus** | Google Cloud Pub/Sub | Async communication between all services |
| **Database** | Firestore (social) + PostgreSQL (financial) | Hybrid storage optimized per use case |

---

## Quick Start

### Prerequisites

- Node.js 18+, npm
- Rust 1.76+
- Python 3.11+
- Flutter 3.16+
- Docker & Docker Compose

### Local Development

```bash
# 1. Clone and configure
git clone https://github.com/Domusgpt/Di-iP_Di-Fi.git
cd Di-iP_Di-Fi
cp .env.example .env   # Edit with your keys

# 2. Start infrastructure
docker compose up -d

# 3. Install dependencies (run in parallel)
cd contracts && npm install && cd ..
cd backend/functions && npm install && cd ../..
cd brain && pip install -r requirements.txt && cd ..
cd frontend/ideacapital && flutter pub get && cd ../..

# 4. Compile contracts
cd contracts && npx hardhat compile && cd ..

# 5. Run services
# Terminal 1: Firebase emulators
cd backend/functions && npm run build && firebase emulators:start

# Terminal 2: Brain (AI agent)
cd brain && uvicorn src.main:app --port 8081

# Terminal 3: Vault (financial engine)
cd vault && cargo run

# Terminal 4: Flutter app
cd frontend/ideacapital && flutter run
```

See [docs/getting-started.md](docs/getting-started.md) for the full onboarding guide.

---

## Project Structure

```
Di-iP_Di-Fi/
├── frontend/ideacapital/    # Flutter app (The Face - UI)
│   ├── lib/
│   │   ├── models/          # Dart data models (mirrors InventionSchema)
│   │   ├── providers/       # Riverpod state management
│   │   ├── screens/         # UI screens (feed, auth, invention, invest, profile)
│   │   ├── widgets/         # Reusable widgets (cards, comments, likes)
│   │   └── services/        # HTTP client for Cloud Functions API
│   └── pubspec.yaml
│
├── backend/functions/       # TypeScript Cloud Functions (The Face - API)
│   ├── src/
│   │   ├── services/        # REST endpoints (invention, investment, social, notification)
│   │   ├── events/          # Pub/Sub handlers (AI, investment, invention, chain indexer)
│   │   ├── middleware/      # Auth middleware
│   │   └── models/          # TypeScript interfaces
│   └── package.json
│
├── brain/                   # Python AI Agent (The Brain)
│   ├── src/
│   │   ├── agents/          # Invention analysis agent (FastAPI router)
│   │   ├── services/        # LLM, patent search, Pub/Sub listener
│   │   ├── models/          # Pydantic models (mirrors InventionSchema)
│   │   └── prompts/         # System prompts for Gemini
│   ├── tests/               # pytest test suite
│   └── pyproject.toml
│
├── vault/                   # Rust Financial Engine (The Vault)
│   ├── src/
│   │   ├── routes/          # Axum HTTP handlers (investments, dividends)
│   │   ├── services/        # Chain watcher, Pub/Sub, transaction verifier
│   │   ├── crypto/          # Merkle tree implementation
│   │   └── models/          # Structs for investments, dividends
│   ├── migrations/          # PostgreSQL schema
│   └── Cargo.toml
│
├── contracts/               # Solidity Smart Contracts
│   ├── contracts/           # IPNFT, RoyaltyToken, Crowdsale, DividendVault
│   ├── test/                # Hardhat test suites
│   ├── scripts/             # Deployment scripts
│   └── hardhat.config.ts
│
├── infra/                   # Infrastructure configuration
│   ├── firebase.json        # Firebase project config
│   ├── firestore/           # Security rules + indexes
│   └── pubsub/              # Topic definitions
│
├── schemas/                 # Canonical data contracts
│   └── InventionSchema.json # THE schema — mirrored in all 4 languages
│
├── docs/                    # Documentation suite
├── .github/workflows/       # CI pipeline
├── docker-compose.yml       # Local development stack
├── CLAUDE.md                # Claude Code project instructions
└── ARCHITECTURE.md          # Development track & integration plan
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/getting-started.md) | Developer onboarding and local setup |
| [Architecture](docs/architecture.md) | System design, data flow, trade-offs |
| [API Reference](docs/api-reference.md) | Full REST endpoint documentation |
| [Data Model](docs/data-model.md) | Firestore + PostgreSQL schema reference |
| [Smart Contracts](docs/smart-contracts.md) | Solidity contract interfaces and deployment |
| [Event Architecture](docs/event-driven-architecture.md) | Pub/Sub topics, message formats, flow diagrams |
| [AI Agent Guide](docs/ai-agent-guide.md) | The Brain: prompts, conversation flow, integration |
| [Deployment](docs/deployment.md) | Production deployment playbook |
| [Security Model](docs/security-model.md) | Authentication, authorization, Firestore rules |
| [Contributing](CONTRIBUTING.md) | How to contribute to the project |

### Sub-Agent Specifications

| Agent | Description |
|-------|-------------|
| [Agent Overview](docs/agents/overview.md) | Architecture of the sub-agent system |
| [The Face](docs/agents/the-face.md) | Flutter UI + TypeScript backend specification |
| [The Vault](docs/agents/the-vault.md) | Rust financial engine specification |
| [The Brain](docs/agents/the-brain.md) | Python AI agent specification |

---

## Testing

```bash
# Smart contracts
cd contracts && npx hardhat test

# Python Brain
cd brain && pytest tests/ -v

# TypeScript backend
cd backend/functions && npm run lint && npm run build

# Rust Vault
cd vault && cargo test
```

---

## License

Proprietary. All rights reserved.

---

## Links

- [Architecture Decision Records](ARCHITECTURE.md)
- [Canonical Schema](schemas/InventionSchema.json)
- [Docker Compose Stack](docker-compose.yml)
- [CI Pipeline](.github/workflows/ci.yml)
