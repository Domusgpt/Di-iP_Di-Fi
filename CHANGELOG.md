# Changelog

All notable changes to the IdeaCapital project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.3.0] - 2026-02-01

### Added

- **Brain:** Pub/Sub callback wired to agent endpoints (`/analyze`, `/chat`) with httpx internal HTTP calls for message routing.
- **Brain:** LLM conversation history loaded from Firestore (`inventions/{id}/conversation_history`), with context-aware prompts built from the last 20 turns.
- **Vault:** Investment verification with on-chain transaction receipt validation via ethers-rs.
- **Vault:** Dividend distribution endpoint with Merkle tree calculation and PostgreSQL storage of roots and individual claims.
- **Backend:** Blockchain indexer fetches transaction receipts via ethers.js and publishes `investment.confirmed` or `investment.failed` to Pub/Sub.
- **Backend:** Invention events notify followers and update creator reputation scores via Firestore triggers.
- **Backend:** Feed following filter implemented via Firestore subcollection query on `following/{uid}/user_following`.
- **Frontend:** Profile screen with tabbed Inventions/Investments views, follow/unfollow button, and user stats display.
- **Frontend:** Invention detail screen with `LikeButton` widget and `CommentSection` widget for social engagement.
- **Infra:** Firestore security rules for `notifications`, `following`/`followers`, and `conversation_history` subcollections.

---

## [0.2.0] - 2026-02-01

### Added

- **Contracts:** Comprehensive Solidity test suites for `Crowdsale.sol`, `RoyaltyToken.sol`, and `DividendVault.sol` covering edge cases, access control, and financial precision.
- **Infra:** GitHub Actions CI pipeline running build and test for all five services (Flutter, TypeScript, Python, Rust, Solidity).
- **Vault:** Rust Pub/Sub client service for subscribing to `investment.pending` and publishing `investment.confirmed`.
- **Vault:** Transaction verifier service for on-chain receipt validation.
- **Brain:** Python test suites for invention agent endpoints (8 tests), LLM service mock mode (6 tests), and patent search (4 tests).
- **Backend:** TypeScript social-service with comments and likes CRUD endpoints.
- **Backend:** TypeScript notification-service with Firebase Cloud Messaging (FCM) push delivery and in-app feed writes.
- **Frontend:** Flutter search screen with query input and result list.
- **Frontend:** Flutter `CommentSection` widget and `LikeButton` widget for invention detail.
- **Frontend:** Flutter `NotificationProvider` for real-time notification badge and feed.
- **Backend:** Wired notification dispatching into `investment-events` and `ai-events` Pub/Sub handlers.

---

## [0.1.0] - 2026-02-01

### Added

- **Project:** Full project scaffold across 5 services and infrastructure (77 files total).
- **Frontend:** Flutter application with models (`Invention`, `User`, `Investment`), Riverpod providers (`AuthProvider`, `FeedProvider`, `WalletProvider`), screens (`FeedScreen`, `AuthScreen`, `CreateInventionScreen`, `InvestmentScreen`, `ProfileScreen`), widgets (`InventionCard`, `FundingProgressBar`), and services (`ApiService`).
- **Backend:** TypeScript Firebase Cloud Functions with Express API routes, Pub/Sub event handlers (`ai-events`, `investment-events`, `invention-events`), Firebase Auth middleware, and shared type definitions.
- **Vault:** Rust Axum service with investment and dividend API routes, token calculator service, Merkle tree crypto module, Pydantic-equivalent struct models, and PostgreSQL migration scripts.
- **Brain:** Python FastAPI service with invention analysis agent, LLM service (Vertex AI Gemini 1.5 Pro with mock fallback), patent search service, Pydantic models mirroring `InventionSchema.json`, and prompt templates for all interview phases.
- **Contracts:** Solidity smart contracts -- `IPNFT.sol` (ERC-721 patent NFT), `RoyaltyToken.sol` (ERC-20 revenue shares), `Crowdsale.sol` (USDC-to-token exchange), `DividendVault.sol` (Merkle-based dividend claims) -- with Hardhat configuration and deployment scripts.
- **Infra:** `docker-compose.yml` orchestrating all services (Vault, Brain, Firebase emulators, Hardhat, PostgreSQL, Redis), Firebase configuration (`firebase.json`), Firestore security rules and composite indexes, and Pub/Sub topic definitions (`ai.processing`, `ai.processing.complete`, `invention.created`, `investment.pending`, `investment.confirmed`, `patent.status.updated`).
- **Schemas:** Canonical `InventionSchema.json` defining the shared data contract across all services with mirrors in Dart, TypeScript, Python, and Rust.
- **Docs:** `ARCHITECTURE.md` with system overview diagram, four development tracks (Face, Vault, Brain, Infrastructure), non-parallel integration gate tasks, folder structure, Docker Compose configuration, development roadmap, and API contracts.
