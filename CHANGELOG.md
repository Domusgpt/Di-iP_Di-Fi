# Changelog

All notable changes to the IdeaCapital project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.5.1] - 2026-02-01 (DeSci & Compliance Update)

### Strategic Features
- **Zero-Knowledge Novelty:** Added `brain/src/zkp/novelty.circom` circuit and `POST /prove_novelty` endpoint. Allows proving knowledge of invention content without revealing it.
- **Story Protocol Adapter:** Added `StoryProtocolAdapter.sol` to register IdeaCapital assets with the global on-chain IP registry.
- **Arizona ABS Compliance:** Implemented fee-sharing logic in the Vault (`dividends.rs`) and database (`compliance_fee_splits`), enabling legal revenue sharing between lawyers and DAO members.
- **Visual Identity Pivot:** Replaced full-screen shaders with **Vib3 Watermark** — a performant, procedurally generated geometric seal unique to each invention ID. Supports Web (WebGL) and Mobile (Canvas).

### Added
- **Vault:** Wired up `PubSubClient` and `ChainWatcher` in `main.rs` to run concurrently.
- **Backend:** Reactive Indexing — `onInvestmentConfirmed` handler now updates Firestore immediately after blockchain confirmation.
- **Frontend:** Completed `InvestScreen` with real wallet integration (Mock Mode included for dev).
- **Frontend:** Added "Verifiable Novelty" badge to `InventionDetailScreen`.
- **Infrastructure:** `scripts/run_integration_test.sh` for full-stack dockerized testing.
- **Docs:** `docs/zkp-integration.md` and `docs/compliance-abs.md`.

### Fixed
- **Critical:** Fixed Merkle Tree hashing mismatch (Rust `tiny-keccak` vs Solidity `keccak256`) — added cross-language regression test.
- **Reliability:** Refactored Vault Merkle logic to return `Result` instead of panicking.
- **Mobile Build:** Fixed `dart:ui_web` import crash on mobile by using conditional imports in `vib3_watermark.dart`.

### Test Results
- Smart Contracts: 51/51 passing (added Merkle compatibility tests)
- Backend (Jest): 27/27 passing (strict types enforced)
- Brain (pytest): 17/17 passing (ZKP service mocked)
- Rust Vault: 9/9 passing
- **Total: 104/104 all passing**

---

## [0.5.0] - 2026-02-01

---

## [0.4.0] - 2026-02-01

### Added

- **Frontend:** WalletConnect v2 integration in `wallet_provider.dart` — full session management, `connect()`, `disconnect()`, `sendTransaction()` via `Web3App` with EIP155/Polygon (chainId 137) support.
- **Frontend:** Real investment transaction flow in `invest_screen.dart` — USDC approve + Crowdsale invest contract calls, backend POST to record pending investment, optimistic UI with real tx hash.
- **Frontend:** Voice recording in `create_invention_screen.dart` via `record` package with start/stop toggle and duration indicator.
- **Frontend:** Sketch upload to Firebase Storage with preview thumbnail in create invention flow.
- **Frontend:** Brain API submission — POSTs to `/api/inventions/analyze` with text, voice URL, and sketch URL; navigates to invention detail on success.
- **Frontend:** Vib3+ 4D shader SDK integration — `Vib3Background` widget (WebGL on web, gradient fallback on native), `Vib3Card` widget with per-invention procedural shader backgrounds, `Vib3Provider` Riverpod state management.
- **Frontend:** `vib3-loader.js` — Web entrypoint script that registers Flutter platform views and renders procedural 4D geometry shaders via WebGL2 fullscreen quads with ray marching.
- **Vault:** Production Pub/Sub client — `start_investment_listener()` uses `google_cloud_pubsub::Client` to subscribe to `investment-pending-vault-sub`, verify transactions, record to PostgreSQL, and publish confirmations.
- **Vault:** Chain watcher completed — full Investment event log decoding with `ethers::abi::decode`, amount extraction (USDC 6 decimals / tokens 18 decimals), PostgreSQL recording, and Pub/Sub publishing.
- **Vault:** Service-to-service HMAC-SHA256 authentication middleware — timestamp-signed `X-Vault-Auth` header verification with 5-minute drift tolerance, dev-mode bypass.
- **Brain:** Voice transcription via Vertex AI Speech-to-Text (`google.cloud.speech_v2`) in invention agent `/analyze` endpoint with graceful mock fallback.
- **Brain:** Sketch analysis via Gemini 1.5 Flash Vision API in invention agent — sends image URL with technical description prompt.
- **Brain:** `continue_chat()` fully wired — loads Firestore draft, conversation history, identifies empty schema fields, passes full context to LLM.
- **Brain:** Patent search via SerpAPI Google Patents endpoint — real API integration with keyword overlap similarity scoring, top-5 results, mock fallback.
- **Backend:** Unit test suite — `invention-service.test.ts`, `investment-service.test.ts`, `notification-service.test.ts` with Jest mocks for Firestore, Pub/Sub, and uuid.

### Changed

- **Vault:** `pubsub.rs` upgraded from stub mode to production Google Cloud Pub/Sub with graceful fallback.
- **Vault:** `chain_watcher.rs` event handler now decodes logs, verifies amounts with 1% slippage tolerance, and records to DB.
- **Vault:** Added `hmac` dependency to `Cargo.toml` for auth middleware.

### Documentation

- **New:** `docs/vib3-integration.md` — Vib3+ shader SDK integration guide with architecture overview, widget API, web loader reference, and customization instructions.
- **Updated:** `CHANGELOG.md` — Sprint 4 entry.
- **Updated:** `Readme.md` — Added Vib3+ to tech stack, shader SDK section, and updated project structure.
- **Updated:** `CLAUDE.md` — Added Vib3+ integration context and widget reference.

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
