# IdeaCapital — Claude Code Project Guide

This file provides context for Claude Code when working on the IdeaCapital codebase.

## Project Overview

IdeaCapital is a decentralized invention capital platform. Inventors submit ideas, an AI agent structures them into patent-ready briefs, investors fund them with USDC, and smart contracts distribute licensing revenue via Royalty Tokens.

The system is composed of 5 services communicating via Google Cloud Pub/Sub:

1. **Flutter Frontend** (`frontend/ideacapital/`) — Dart, Riverpod, GoRouter, Firebase SDK
2. **TypeScript Backend** (`backend/functions/`) — Firebase Functions Gen 2, Express, Pub/Sub handlers
3. **Python Brain** (`brain/`) — FastAPI, LangChain, Vertex AI (Gemini Pro), patent search
4. **Rust Vault** (`vault/`) — Axum, SQLx (PostgreSQL), ethers-rs, Merkle tree
5. **Solidity Contracts** (`contracts/`) — Hardhat, OpenZeppelin, ERC-721/ERC-20

## Canonical Schema

`schemas/InventionSchema.json` is THE data contract. All 4 languages mirror this schema:
- Dart: `frontend/ideacapital/lib/models/invention.dart`
- TypeScript: `backend/functions/src/models/types.ts`
- Python: `brain/src/models/invention.py`
- Rust: no direct mirror (uses `serde_json::Value` for flexibility)

When modifying the schema, update all 4 language mirrors.

## Key Architectural Patterns

- **CQRS**: Blockchain is Source of Truth (writes), Firestore is Fast Cache (reads)
- **Optimistic UI**: Flutter updates immediately, Pub/Sub confirms asynchronously
- **Event-Driven**: All cross-service communication goes through Pub/Sub topics
- **Merkle Proofs**: Dividend distribution uses Merkle trees for gas-efficient on-chain claims

## Pub/Sub Topics

| Topic | Publisher | Subscriber |
|-------|----------|------------|
| `ai.processing` | TypeScript | Brain |
| `ai.processing.complete` | Brain | TypeScript |
| `invention.created` | TypeScript | TypeScript |
| `investment.pending` | TypeScript | Vault |
| `investment.confirmed` | Vault / Indexer | TypeScript |
| `patent.status.updated` | External | TypeScript |

## Common Commands

```bash
# Contracts
cd contracts && npx hardhat compile
cd contracts && npx hardhat test

# Backend
cd backend/functions && npm run build
cd backend/functions && npm run lint

# Brain
cd brain && uvicorn src.main:app --port 8081 --reload
cd brain && pytest tests/ -v

# Vault
cd vault && cargo build
cd vault && cargo test
cd vault && cargo run

# Flutter
cd frontend/ideacapital && flutter pub get
cd frontend/ideacapital && dart run build_runner build
cd frontend/ideacapital && flutter run

# Full stack (Docker)
docker compose up -d
```

## Code Conventions

### Dart (Flutter)
- State management: Riverpod (providers, not BLoC)
- Routing: GoRouter (declarative routes in `app.dart`)
- Models use `json_serializable` with `@JsonKey` annotations
- Generated files: run `dart run build_runner build` after model changes

### TypeScript (Backend)
- Firebase Functions Gen 2 (not Gen 1)
- Express router pattern: each service exports a `Router`
- Pub/Sub handlers use `onMessagePublished` from `firebase-functions/v2/pubsub`
- Validation via Zod schemas (where applicable)

### Python (Brain)
- FastAPI with Pydantic models
- Async everywhere (`async def`, `await`)
- LangChain for LLM orchestration
- Tests use pytest with httpx `AsyncClient`

### Rust (Vault)
- Axum 0.7 with `Router` and `State<PgPool>`
- SQLx for PostgreSQL queries (compile-time checked where possible)
- ethers-rs for blockchain interaction
- Error handling via `anyhow::Result`

### Solidity (Contracts)
- Solidity 0.8.24 with optimizer enabled
- OpenZeppelin v5 base contracts
- Hardhat toolbox for testing
- Deploy scripts in TypeScript

## Firestore Collections

| Collection | Purpose | Access |
|-----------|---------|--------|
| `users/{uid}` | User profiles | Public read, owner write |
| `users/{uid}/notifications/{id}` | Notification feed | Owner read, admin write |
| `inventions/{id}` | Published inventions | Public read, creator write |
| `inventions/{id}/comments/{id}` | Comments | Public read, auth create |
| `inventions/{id}/likes/{uid}` | Likes | Public read, owner write |
| `inventions/{id}/conversation_history/{id}` | AI chat history | Auth read, admin write |
| `investments/{id}` | Investment records | Auth read, admin write |
| `following/{uid}/user_following/{targetUid}` | Following list | Public read, owner write |
| `followers/{uid}/user_followers/{followerUid}` | Followers list | Public read, admin write |
| `feed_index/{inventionId}` | Feed ranking data | Public read, admin write |
| `pledges/{id}` | Phase 1 mock pledges | Auth read/create |

## PostgreSQL Tables (Vault)

| Table | Purpose |
|-------|---------|
| `investments` | Verified on-chain investment records |
| `dividend_distributions` | Merkle root + metadata per distribution |
| `dividend_claims` | Individual claims with Merkle proofs |
| `invention_ledger` | Token supply and contract addresses |

## File Naming

- Dart: `snake_case.dart`
- TypeScript: `kebab-case.ts`
- Python: `snake_case.py`
- Rust: `snake_case.rs`
- Solidity: `PascalCase.sol`

## Security Considerations

- Never commit `.env` files or private keys
- Firestore rules enforce auth — Cloud Functions use admin SDK for privileged writes
- Investment verification requires on-chain receipt confirmation
- Wallet addresses are always lowercased before comparison
- USDC amounts use 6 decimal precision, token amounts use 18 decimal precision

## Testing Strategy

- **Contracts**: Hardhat tests with ethers.js — test all financial edge cases
- **Brain**: pytest with mock LLM responses — test agent endpoints and output structure
- **Vault**: Rust unit tests for token_calculator and merkle modules
- **Backend**: Build verification (TypeScript strict mode catches most issues)
- **Flutter**: Model serialization tests (once build_runner generates `.g.dart` files)
