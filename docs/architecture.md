# IdeaCapital -- System Architecture

A comprehensive system design document covering the design philosophy, data flow, service responsibilities, integration points, technology trade-offs, and scaling considerations for the IdeaCapital platform.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Design Philosophy: Async Social-Hybrid](#design-philosophy-async-social-hybrid)
3. [CQRS: Blockchain as Source of Truth, Firestore as Fast Cache](#cqrs-blockchain-as-source-of-truth-firestore-as-fast-cache)
4. [The Optimistic Update Flow](#the-optimistic-update-flow)
5. [Service Responsibilities](#service-responsibilities)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [Database Strategy](#database-strategy)
8. [Technology Trade-offs](#technology-trade-offs)
9. [Integration Points and Pub/Sub Topics](#integration-points-and-pubsub-topics)
10. [Scaling Considerations](#scaling-considerations)
11. [Further Reading](#further-reading)

---

## System Overview

IdeaCapital is a decentralized invention capital platform. Inventors submit ideas, an AI agent structures them into patent-ready briefs, investors fund legal and prototyping costs with USDC in exchange for Royalty Tokens, and smart contracts distribute licensing revenue automatically via Merkle-proof dividend claims.

The platform is composed of five distinct services, each written in the language best suited to its domain:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENTS                                     │
│                    Flutter Mobile/Web                                │
│           (Social Feed  -  Wallet  -  AI Chat  -  Invest)           │
└────────────────────────┬────────────────────────────────────────────┘
                         | HTTPS / Firebase SDK
                         v
┌─────────────────────────────────────────────────────────────────────┐
│                    THE FACE -- TypeScript Backend                    │
│              Firebase Cloud Functions (Gen 2) + Express              │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────────┐   │
│  │Invention │  │Investment│  │ Social   │  │  Notification     │   │
│  │ Service  │  │ Service  │  │ Service  │  │    Service        │   │
│  └────┬─────┘  └────┬─────┘  └──────────┘  └───────────────────┘   │
│       |              |                                              │
└───────┼──────────────┼──────────────────────────────────────────────┘
        |              |
        v              v
┌─────────────────────────────────────────────────────────────────────┐
│                  GOOGLE CLOUD PUB/SUB                                │
│                                                                     │
│   ai.processing ──> ai.processing.complete                          │
│   invention.created                                                 │
│   investment.pending ──> investment.confirmed                       │
│   patent.status.updated                                             │
└──────┬───────────────────────┬──────────────────────────────────────┘
       |                       |
       v                       v
┌──────────────┐      ┌──────────────┐      ┌─────────────────────┐
│  THE BRAIN   │      │  THE VAULT   │      │    EVM BLOCKCHAIN   │
│  Python/     │      │  Rust/Axum   │      │  Polygon / Base     │
│  FastAPI     │      │              │      │                     │
│              │      │  Investment  │      │  ┌───────────────┐  │
│  Gemini Pro  │      │  Verifier    │<────>│  │   IP-NFT      │  │
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

## Design Philosophy: Async Social-Hybrid

IdeaCapital follows an **Async Social-Hybrid** architecture. This term captures three core design decisions:

### Async (Event-Driven)

No service calls another service synchronously. All cross-service communication flows through Google Cloud Pub/Sub. This means:

- **Services are independently deployable.** The Brain can be redeployed without affecting the Vault.
- **Services are independently scalable.** Pub/Sub acts as a buffer during traffic spikes.
- **Failures are isolated.** If the Brain goes down, investments still process. If the Vault goes down, AI analysis still runs.
- **Operations are auditable.** Every event is a durable message that can be replayed.

### Social (Firestore-First UX)

The user-facing experience is built on Firestore's real-time capabilities. Users see instant feed updates, live comment streams, and push notifications, all powered by Firestore's native real-time listeners. The platform feels like a social network, not a blockchain dApp.

### Hybrid (Web2 + Web3)

The platform bridges traditional web technology with blockchain infrastructure:

- **Web2 layer** (Firestore, Cloud Functions, Flutter) handles everything a user sees and touches -- profiles, feeds, comments, likes, notifications.
- **Web3 layer** (Solidity, Rust, PostgreSQL) handles everything involving money and ownership -- token issuance, investment verification, dividend distribution, IP-NFT minting.

Users interact with a familiar social UI. Blockchain operations happen behind the scenes, surfaced only when the user explicitly engages their wallet.

---

## CQRS: Blockchain as Source of Truth, Firestore as Fast Cache

IdeaCapital employs a CQRS (Command Query Responsibility Segregation) pattern adapted for blockchain:

```
                WRITES (Commands)                    READS (Queries)
                     |                                    |
                     v                                    v
         ┌───────────────────────┐           ┌───────────────────────┐
         │   EVM Blockchain      │           │      Firestore        │
         │   (Polygon / Base)    │           │    (Real-time Cache)  │
         │                       │           │                       │
         │  - IP-NFT ownership   │           │  - Invention feed     │
         │  - Token balances     │ ──sync──> │  - Funding progress   │
         │  - Investment txns    │           │  - User profiles      │
         │  - Dividend claims    │           │  - Comments & likes   │
         │                       │           │  - Investment status   │
         └───────────────────────┘           └───────────────────────┘
                                  \         /
                                   \       /
                            ┌───────────────────┐
                            │    PostgreSQL      │
                            │  (Financial Ledger)│
                            │                    │
                            │  - Investment log  │
                            │  - Merkle roots    │
                            │  - Dividend claims │
                            │  - Token supply    │
                            └───────────────────┘
```

### Why Three Storage Layers?

| Concern | Storage | Reason |
|---------|---------|--------|
| **Ownership and payments** | Blockchain | Immutable, trustless, legally binding |
| **Social data and UX** | Firestore | Real-time listeners, offline support, sub-50ms reads |
| **Financial computation** | PostgreSQL | Complex queries, decimal precision, ACID transactions |

### The Sync Mechanism

A **Chain Indexer** (running as a TypeScript Cloud Function) watches blockchain events and mirrors confirmed state into Firestore. This creates eventual consistency between the authoritative blockchain state and the fast-read Firestore cache.

```
Blockchain Event (InvestmentConfirmed)
    |
    v
Chain Indexer (TypeScript Cloud Function)
    |
    v
Firestore Update (inventions/{id}.funding.raised_usdc += amount)
    |
    v
Flutter UI (real-time listener picks up the change instantly)
```

### Consistency Guarantee

- **Blockchain** is the ultimate authority. If there is ever a discrepancy between Firestore and the chain, the chain wins.
- **Firestore** is eventually consistent with the chain. Lag is typically 1-3 block confirmations (seconds on Polygon/Base).
- **PostgreSQL** maintains the Vault's own verified record of financial events. It agrees with the chain but is structured for relational queries the chain cannot efficiently perform (e.g., "sum all investments for invention X grouped by month").

---

## The Optimistic Update Flow

IdeaCapital uses an **Optimistic Update** pattern to give users instant feedback while blockchain transactions confirm in the background. Here is the step-by-step walkthrough for an investment:

### Step-by-Step: User Invests in an Invention

```
 FLUTTER              TYPESCRIPT            PUB/SUB           RUST VAULT          BLOCKCHAIN
    |                     |                    |                   |                    |
    |  1. POST /invest    |                    |                   |                    |
    |────────────────────>|                    |                   |                    |
    |                     |                    |                   |                    |
    |  2. 202 Accepted    |                    |                   |                    |
    |<────────────────────|                    |                   |                    |
    |                     |                    |                   |                    |
    |  3. OPTIMISTIC      | 4. Publish         |                   |                    |
    |     UPDATE          |   investment       |                   |                    |
    |  (UI shows          |   .pending         |                   |                    |
    |   "Processing")     |───────────────────>|                   |                    |
    |                     |                    |                   |                    |
    |                     | 5. Write to        | 6. Deliver to     |                    |
    |                     |    Firestore       |    Vault          |                    |
    |                     |  (status:pending)  |──────────────────>|                    |
    |                     |                    |                   |                    |
    |  7. Firestore       |                    |                   | 8. Watch for       |
    |     listener        |                    |                   |    tx_hash on      |
    |     updates UI      |                    |                   |    chain           |
    |  (shows pending)    |                    |                   |───────────────────>|
    |                     |                    |                   |                    |
    |                     |                    |                   | 9. Tx confirmed    |
    |                     |                    |                   |<───────────────────|
    |                     |                    |                   |                    |
    |                     |                    | 10. Publish       |                    |
    |                     |                    |    investment     |                    |
    |                     |                    |<──────────────────|                    |
    |                     |                    |    .confirmed     |                    |
    |                     |                    |                   |                    |
    |                     | 11. Receive        |                   |                    |
    |                     |     confirmed      |                   |                    |
    |                     |<───────────────────|                   |                    |
    |                     |                    |                   |                    |
    |                     | 12. Update         |                   |                    |
    |                     |     Firestore      |                   |                    |
    |                     |  (status:confirmed,|                   |                    |
    |                     |   raised_usdc +=N) |                   |                    |
    |                     |                    |                   |                    |
    |  13. Firestore      |                    |                   |                    |
    |      listener       |                    |                   |                    |
    |      updates UI     |                    |                   |                    |
    |  (shows confirmed,  |                    |                   |                    |
    |   progress bar      |                    |                   |                    |
    |   moves)            |                    |                   |                    |
    |                     |                    |                   |                    |
```

### Key Properties of This Flow

1. **Instant feedback (Step 2-3).** The user sees a "Processing" state immediately. No waiting for blockchain confirmation.
2. **Pub/Sub decoupling (Step 4-6).** TypeScript does not call the Vault directly. It publishes a message and moves on.
3. **Real verification (Step 8-9).** The Vault watches the actual blockchain for the transaction hash. No trust assumptions.
4. **Eventual consistency (Step 12-13).** Firestore is updated only after real confirmation. The UI transitions from "pending" to "confirmed."
5. **Failure handling.** If the transaction fails on-chain, the Vault publishes `investment.failed`, and Firestore reverts the optimistic update.

---

## Service Responsibilities

### The Face: Flutter + TypeScript

**Role:** Everything the user sees and touches.

The Face is split into two layers:

#### Flutter (Dart) -- Client Application

| Responsibility | Details |
|---------------|---------|
| UI/UX | Feed screen, invention detail, creation flow, investment flow, profile |
| State management | Riverpod providers for auth, feed, wallet, and invention state |
| Real-time data | Firestore listeners for live updates (comments, likes, funding progress) |
| Wallet integration | WalletConnect/Reown for signing blockchain transactions |
| Offline support | Firestore persistence cache for offline browsing |
| Code generation | `json_serializable` and `freezed` for type-safe models |

#### TypeScript (Firebase Cloud Functions Gen 2) -- API Gateway

| Responsibility | Details |
|---------------|---------|
| REST API | Express router serving `/api/inventions`, `/api/investments`, `/api/users`, etc. |
| Authentication | Firebase Auth middleware verifying ID tokens |
| Event orchestration | Pub/Sub publisher for `ai.processing`, `investment.pending`, `invention.created` |
| Chain indexer | Watches blockchain events and syncs confirmed state to Firestore |
| Firestore triggers | Reacts to document changes (e.g., new invention triggers feed indexing) |
| Notification dispatch | FCM push notifications on investment confirmations, comments, follows |

**Boundary rule:** The TypeScript layer is the ONLY service that writes to Firestore (via the Admin SDK). Flutter reads Firestore directly but writes go through Cloud Functions. Neither the Brain nor the Vault touches Firestore directly.

### The Brain: Python

**Role:** AI-powered invention analysis and patent structuring.

| Responsibility | Details |
|---------------|---------|
| Invention structuring | Takes raw text/voice/sketch input and produces a structured `technical_brief` |
| Multi-turn conversation | Guides the inventor through Ingest, Drill Down, and Validate phases |
| Prior art search | Queries Google Patents API to find similar existing patents |
| Risk assessment | Generates feasibility scores and identifies missing information |
| Concept art generation | Uses Imagen 3 to create visual representations of inventions |
| Pub/Sub integration | Subscribes to `ai.processing`, publishes `ai.processing.complete` |

**Technology stack:** FastAPI, LangChain, Vertex AI (Gemini Pro), Pydantic models, Google Cloud Pub/Sub client.

**Boundary rule:** The Brain reads and writes conversation state to Firestore (via the Admin SDK for conversation history), but all other Firestore writes (updating the invention document with AI results) are done by the TypeScript backend in response to the `ai.processing.complete` event.

### The Vault: Rust

**Role:** Financial operations, blockchain interaction, and dividend distribution.

| Responsibility | Details |
|---------------|---------|
| Transaction verification | Watches the blockchain for pending investment transaction hashes and verifies on-chain confirmation |
| Token calculation | Computes how many Royalty Tokens an investor receives per USDC invested |
| Merkle tree generation | Builds Merkle trees for gas-efficient dividend distribution claims |
| Dividend API | Serves Merkle proofs to users so they can claim dividends on-chain |
| Financial ledger | Maintains PostgreSQL records of all investments, distributions, and claims |
| Pub/Sub integration | Subscribes to `investment.pending`, publishes `investment.confirmed` |

**Technology stack:** Axum 0.7, SQLx (PostgreSQL), ethers-rs, custom Merkle tree implementation, Google Cloud Pub/Sub client.

**Boundary rule:** The Vault NEVER writes to Firestore. It publishes events to Pub/Sub, and the TypeScript backend handles all Firestore synchronization.

**Critical constraint:** The Merkle proof encoding in `vault/src/crypto/merkle.rs` MUST match the leaf encoding in `contracts/contracts/DividendVault.sol`:

```
leaf = keccak256(abi.encodePacked(keccak256(abi.encode(address, amount))))
```

A mismatch here means users cannot claim dividends, and funds would be locked in the contract.

### Smart Contracts: Solidity

**Role:** On-chain ownership, token economics, and trustless payments.

| Contract | Standard | Purpose |
|----------|----------|---------|
| `IPNFT.sol` | ERC-721 | Represents ownership of the patent/IP asset. One NFT per invention. |
| `RoyaltyToken.sol` | ERC-20 | Fungible revenue-share tokens. Holders receive proportional dividends. |
| `Crowdsale.sol` | Custom | Accepts USDC and mints RoyaltyTokens at a fixed rate during the funding period. |
| `DividendVault.sol` | Custom (Merkle) | Accepts revenue deposits and allows token holders to claim their share via Merkle proofs. |

**Technology stack:** Solidity 0.8.24, OpenZeppelin v5, Hardhat, ethers.js v6.

---

## Data Flow Diagrams

### Investment Flow

```
   INVENTOR                    INVESTOR                    PLATFORM
      |                           |                           |
      |  1. Create invention      |                           |
      |──────────────────────────────────────────────────────>|
      |                           |                           |
      |                           |    2. View invention      |
      |                           |       on feed             |
      |                           |<──────────────────────────|
      |                           |                           |
      |                           |    3. Click "Invest"      |
      |                           |       Enter USDC amount   |
      |                           |──────────────────────────>|
      |                           |                           |
      |                           |    4. Sign tx with        |
      |                           |       WalletConnect       |  ┌──────────────┐
      |                           |──────────────────────────>|──| Crowdsale.sol|
      |                           |                           |  | buyTokens()  |
      |                           |    5. Tx submitted        |  └──────┬───────┘
      |                           |<──────────────────────────|         |
      |                           |    (optimistic: pending)  |         |
      |                           |                           |         |
      |                           |                           |  6. Block confirmed
      |                           |                           |         |
      |                           |                           |  ┌──────v───────┐
      |                           |                           |  | Vault watches|
      |                           |                           |  | chain, writes|
      |                           |                           |  | to PostgreSQL|
      |                           |                           |  └──────┬───────┘
      |                           |                           |         |
      |                           |                           |  7. Pub/Sub: confirmed
      |                           |                           |         |
      |                           |                           |  ┌──────v───────┐
      |                           |    8. Firestore updated   |  | TypeScript   |
      |                           |<──────────────────────────|  | syncs to     |
      |                           |    (confirmed, tokens     |  | Firestore    |
      |                           |     credited)             |  └──────────────┘
      |                           |                           |
```

### Invention Creation Flow

```
   INVENTOR               FLUTTER           TYPESCRIPT         BRAIN (AI)         FIRESTORE
      |                      |                   |                  |                  |
      | 1. Describe idea     |                   |                  |                  |
      |   (text/voice/sketch)|                   |                  |                  |
      |─────────────────────>|                   |                  |                  |
      |                      |                   |                  |                  |
      |                      | 2. POST           |                  |                  |
      |                      |  /api/inventions  |                  |                  |
      |                      |  /analyze         |                  |                  |
      |                      |──────────────────>|                  |                  |
      |                      |                   |                  |                  |
      |                      |                   | 3. Save draft    |                  |
      |                      |                   |──────────────────────────────────── >|
      |                      |                   |   (status: DRAFT)|                  |
      |                      |                   |                  |                  |
      |                      |                   | 4. Publish       |                  |
      |                      |                   |   ai.processing  |                  |
      |                      |                   |─────────────────>|                  |
      |                      |                   |                  |                  |
      |                      | 5. 202 Accepted   |                  |                  |
      |                      |<──────────────────|                  |                  |
      |                      |                   |                  |                  |
      | 6. See "AI           |                   |                  |                  |
      |    Processing"       |                   |                  |                  |
      |<─────────────────────|                   |                  |                  |
      |                      |                   | 7. Brain runs    |                  |
      |                      |                   |    Gemini Pro    |                  |
      |                      |                   |    + patent      |                  |
      |                      |                   |    search        |                  |
      |                      |                   |                  |                  |
      |                      |                   |                  | 8. Save          |
      |                      |                   |                  |   conversation   |
      |                      |                   |                  |   history        |
      |                      |                   |                  |────────────────> |
      |                      |                   |                  |                  |
      |                      |                   |                  | 9. Publish       |
      |                      |                   |                  |   ai.processing  |
      |                      |                   |<─────────────────|   .complete      |
      |                      |                   |                  |   (with          |
      |                      |                   |                  |   structured     |
      |                      |                   |                  |   brief)         |
      |                      |                   |                  |                  |
      |                      |                   | 10. Update       |                  |
      |                      |                   |   Firestore      |                  |
      |                      |                   |   invention doc  |                  |
      |                      |                   |  (status:        |                  |
      |                      |                   |   REVIEW_READY,  |                  |
      |                      |                   |   technical_     |                  |
      |                      |                   |   brief filled)  |                  |
      |                      |                   |──────────────────────────────────── >|
      |                      |                   |                  |                  |
      | 11. Real-time        |                   |                  |                  |
      |     listener fires   |                   |                  |                  |
      |     UI shows         |                   |                  |                  |
      |     structured       |                   |                  |                  |
      |     patent brief     |                   |                  |                  |
      |<─────────────────────|                   |                  |                  |
      |                      |                   |                  |                  |
```

### Dividend Distribution Flow

```
   LICENSING            VAULT               BLOCKCHAIN          INVESTOR
   REVENUE              (Rust)              (DividendVault.sol)     |
      |                    |                      |                  |
      | 1. Revenue         |                      |                  |
      |    received        |                      |                  |
      |───────────────────>|                      |                  |
      |                    |                      |                  |
      |                    | 2. Query all token   |                  |
      |                    |    holders +          |                  |
      |                    |    balances           |                  |
      |                    |─────────────────────>|                  |
      |                    |<─────────────────────|                  |
      |                    |                      |                  |
      |                    | 3. Calculate          |                  |
      |                    |    proportional       |                  |
      |                    |    shares             |                  |
      |                    |    (per token ratio)  |                  |
      |                    |                      |                  |
      |                    | 4. Build Merkle tree  |                  |
      |                    |    leaves:            |                  |
      |                    |    keccak256(         |                  |
      |                    |      abi.encode(      |                  |
      |                    |        addr, amount)) |                  |
      |                    |                      |                  |
      |                    | 5. Submit Merkle root |                  |
      |                    |    + total amount     |                  |
      |                    |───────────────────── >|                  |
      |                    |    depositDividend()  |                  |
      |                    |                      |                  |
      |                    | 6. Store proofs in    |                  |
      |                    |    PostgreSQL         |                  |
      |                    |    (per-holder)       |                  |
      |                    |                      |                  |
      |                    | 7. Pub/Sub:           |                  |
      |                    |    dividend.ready     |                  |
      |                    |    (notifies users)   |                  |
      |                    |                      |                  |
      |                    |                      |                  |
      |                    |    8. GET /dividends  |                  |
      |                    |       /claims/{addr}  |                  |
      |                    |<──────────────────────────────────────── |
      |                    |                      |                  |
      |                    |    9. Return Merkle   |                  |
      |                    |       proof + amount  |                  |
      |                    |───────────────────────────────────────── >|
      |                    |                      |                  |
      |                    |                      | 10. claimDividend|
      |                    |                      |    (proof, amt)  |
      |                    |                      |<─────────────────|
      |                    |                      |                  |
      |                    |                      | 11. Verify proof |
      |                    |                      |    Transfer USDC |
      |                    |                      |───────────────── >|
      |                    |                      |                  |
```

---

## Database Strategy

IdeaCapital uses three storage systems, each chosen for a specific class of data:

### Firestore: Social and UX Data

**Role:** Fast cache for everything users see in the app. Real-time listeners power the live-updating UI.

| Collection | Data | Access Pattern |
|-----------|------|----------------|
| `users/{uid}` | Profiles, bios, avatars, stats | Public read, owner write |
| `inventions/{id}` | Published inventions with full schema | Public read, creator write |
| `inventions/{id}/comments/{id}` | Comments on inventions | Public read, auth create |
| `inventions/{id}/likes/{uid}` | Like records (one doc per user) | Public read, owner toggle |
| `inventions/{id}/conversation_history/{id}` | AI chat history | Auth read, admin write |
| `investments/{id}` | Investment records (synced from chain) | Auth read, admin write |
| `following/{uid}/user_following/{target}` | Who a user follows | Public read, owner write |
| `followers/{uid}/user_followers/{follower}` | Who follows a user | Public read, admin write |
| `feed_index/{inventionId}` | Feed ranking metadata | Public read, admin write |
| `pledges/{id}` | Phase 1 mock pledges (pre-Web3) | Auth read/create |

**Why Firestore?**
- Sub-50ms reads globally via automatic multi-region replication.
- Real-time listeners eliminate polling. The feed updates live.
- Offline persistence for mobile -- users can browse without connectivity.
- Firestore security rules enforce authorization at the database level.

### PostgreSQL: Financial Ledger

**Role:** The Vault's private, ACID-compliant record of all financial events. Optimized for relational queries and decimal precision.

| Table | Data | Purpose |
|-------|------|---------|
| `investments` | Every verified investment transaction | Tracks wallet, amount, tx hash, status, block number |
| `dividend_distributions` | Each distribution event | Stores Merkle root, total revenue, claim count |
| `dividend_claims` | Individual claim records | Stores Merkle proof, amount, claimed status, claim tx hash |
| `invention_ledger` | Per-invention financial summary | Aggregates total raised, distributed, backer count, contract addresses |

**Why PostgreSQL?**
- ACID transactions for financial correctness (no partial writes).
- `NUMERIC(18, 6)` for exact USDC decimal handling (no floating-point errors).
- Complex aggregation queries (e.g., "total revenue distributed per quarter") that would be expensive on Firestore.
- Compile-time checked queries via SQLx in Rust.

### Blockchain: Ownership and Payments

**Role:** The immutable, trustless source of truth for all ownership and financial commitments.

| Contract | On-Chain Data | Purpose |
|----------|--------------|---------|
| `IPNFT` (ERC-721) | NFT ownership, metadata URI | Proves who owns the IP asset |
| `RoyaltyToken` (ERC-20) | Token balances, total supply | Defines revenue-share percentages |
| `Crowdsale` | Funding state, exchange rate | Trustless USDC-to-token swap |
| `DividendVault` | Merkle roots, claim bitmaps | Gas-efficient dividend distribution |

**Why blockchain?**
- Trustless ownership: no central authority can revoke tokens or alter ownership.
- Composability: RoyaltyTokens can be traded on any DEX without platform involvement.
- Legal standing: on-chain records serve as evidence of investment and ownership.
- Censorship resistance: dividend claims cannot be blocked by the platform.

### Decimal Precision Alignment

A critical cross-cutting concern is decimal handling across all four languages:

| Layer | USDC Representation | Token Representation |
|-------|--------------------|--------------------|
| Solidity | `uint256` with 6 decimals (1 USDC = `1000000`) | `uint256` with 18 decimals |
| Rust (PostgreSQL) | `NUMERIC(18, 6)` via `rust_decimal::Decimal` | `NUMERIC(18, 6)` |
| TypeScript | `bigint` or `string` (never `number` for financial values) | `bigint` or `string` |
| Dart (Flutter) | Display only -- formatted from string values | Display only |

**Rule:** Financial amounts are NEVER stored as floating-point numbers. All services pass amounts as strings or fixed-point integers to prevent rounding errors.

---

## Technology Trade-offs

### Why Rust for the Vault?

| Considered | Chosen | Rationale |
|-----------|--------|-----------|
| TypeScript (Node.js) | **Rust** | Financial code demands memory safety and deterministic performance. Rust's ownership model prevents data races in concurrent blockchain watchers. The `rust_decimal` crate provides exact decimal arithmetic. Compilation catches entire classes of bugs before deployment. |
| Go | **Rust** | Go lacks generics-powered type safety (prior to 1.18) and has garbage collection pauses that could affect latency-sensitive financial computations. Rust's zero-cost abstractions and no-GC runtime provide predictable performance. |

**Trade-off accepted:** Slower development velocity and steeper learning curve, in exchange for correctness guarantees in the most financially sensitive component.

### Why Python for the Brain?

| Considered | Chosen | Rationale |
|-----------|--------|-----------|
| TypeScript | **Python** | The AI/ML ecosystem is Python-native. LangChain, Vertex AI SDK, and every major LLM library has first-class Python support. Using TypeScript would mean working with immature or wrapper libraries. |
| Rust | **Python** | AI agent development is inherently experimental. Prompts change frequently. Python's rapid iteration speed is critical when tuning LLM behavior. |

**Trade-off accepted:** Slower runtime performance, in exchange for access to the best AI tooling and fastest iteration on prompts and agent logic.

### Why TypeScript for the Backend?

| Considered | Chosen | Rationale |
|-----------|--------|-----------|
| Python | **TypeScript** | Firebase Cloud Functions Gen 2 has first-class TypeScript support. The Firebase Admin SDK, Pub/Sub client, and Firestore triggers are all TypeScript-native. Strict type checking catches schema drift at compile time. |
| Rust | **TypeScript** | The backend is primarily an orchestration layer (route requests, publish events, sync data). Rust's safety guarantees add little value here but would significantly slow development. |

**Trade-off accepted:** Less runtime performance than Rust, in exchange for native Firebase integration and faster feature development.

### Why Flutter for the Frontend?

| Considered | Chosen | Rationale |
|-----------|--------|-----------|
| React Native | **Flutter** | Flutter's rendering engine bypasses platform UI entirely, delivering pixel-identical experiences on iOS, Android, and web from a single codebase. Riverpod provides a clean state management pattern. Firebase SDKs have mature Flutter plugins. |
| Native (Swift + Kotlin) | **Flutter** | A 5-person team cannot maintain two native codebases. Flutter's single codebase covers mobile and web with near-native performance. |

**Trade-off accepted:** Smaller talent pool and less native platform integration, in exchange for true cross-platform delivery from one codebase.

### Why Firestore Over a Traditional SQL Database for Social Data?

| Considered | Chosen | Rationale |
|-----------|--------|-----------|
| PostgreSQL (for everything) | **Firestore** (social) + **PostgreSQL** (financial) | Social features demand real-time listeners, offline support, and horizontal scaling without schema management. Firestore provides all three natively. PostgreSQL excels at financial queries requiring joins, aggregations, and ACID transactions. Splitting by use case avoids forcing either database into a role it was not designed for. |

**Trade-off accepted:** Increased operational complexity (two databases), in exchange for each database being used optimally for its workload.

### Why Pub/Sub Over Direct HTTP Between Services?

| Considered | Chosen | Rationale |
|-----------|--------|-----------|
| REST calls between services | **Pub/Sub** | Direct HTTP creates temporal coupling: if the Brain is down, invention creation fails. Pub/Sub decouples producers from consumers. Messages are durable, retried automatically, and can fan out to multiple subscribers. This also enables replay for debugging and auditing. |

**Trade-off accepted:** Added latency (message delivery is not instant) and operational complexity (topic management), in exchange for fault tolerance, independent scaling, and auditability.

---

## Integration Points and Pub/Sub Topics

All cross-service communication flows through Google Cloud Pub/Sub. The following table defines every topic, its publishers, its subscribers, and the message format.

### Topic Registry

| Topic | Publisher | Subscriber | Trigger |
|-------|----------|------------|---------|
| `invention.created` | TypeScript (invention-service) | TypeScript (invention-events) | Inventor publishes an invention to the live feed |
| `ai.processing` | TypeScript (invention-service) | Brain (pubsub_listener) | Inventor requests AI analysis of their idea |
| `ai.processing.complete` | Brain (pubsub_listener) | TypeScript (ai-events) | Brain finishes structuring the invention |
| `investment.pending` | TypeScript (investment-service) | Vault (chain_watcher), TypeScript (investment-events) | Investor submits a blockchain transaction |
| `investment.confirmed` | Vault (chain_watcher), TypeScript (chain-indexer) | TypeScript (investment-events) | Blockchain transaction is confirmed |
| `patent.status.updated` | Legal backend (future) | TypeScript, Brain | Patent filing status changes |

### Message Flow Diagram

```
┌────────────┐                                           ┌────────────┐
│  FLUTTER   │──POST /api/inventions/analyze────────────>│ TYPESCRIPT │
│  (Client)  │                                           │ (Backend)  │
│            │<──────────Firestore real-time──────────────│            │
└────────────┘                                           └─────┬──────┘
                                                               |
                                            ┌──────────────────┼──────────────────┐
                                            |                  |                  |
                                            v                  v                  v
                                   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
                                   │ai.processing│   │ investment  │   │ invention   │
                                   │             │   │  .pending   │   │  .created   │
                                   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
                                          |                  |                  |
                                          v                  v                  v
                                   ┌────────────┐   ┌────────────┐   ┌────────────┐
                                   │   BRAIN    │   │   VAULT    │   │ TYPESCRIPT │
                                   │  (Python)  │   │  (Rust)    │   │  (Events)  │
                                   └──────┬─────┘   └──────┬─────┘   └────────────┘
                                          |                  |
                                          v                  v
                                   ┌─────────────┐   ┌─────────────┐
                                   │ai.processing│   │ investment  │
                                   │  .complete  │   │  .confirmed │
                                   └──────┬──────┘   └──────┬──────┘
                                          |                  |
                                          v                  v
                                   ┌─────────────────────────────┐
                                   │        TYPESCRIPT           │
                                   │  (Updates Firestore, sends  │
                                   │   notifications to Flutter) │
                                   └─────────────────────────────┘
```

### Service-to-Service Boundaries

| From | To | Protocol | Boundary |
|------|----|----------|----------|
| Flutter | TypeScript | HTTPS | `/api/*` REST endpoints |
| Flutter | Firestore | gRPC (Firebase SDK) | Real-time listeners (reads only) |
| TypeScript | Brain | Pub/Sub | `ai.processing` topic |
| Brain | TypeScript | Pub/Sub | `ai.processing.complete` topic |
| TypeScript | Vault | Pub/Sub | `investment.pending` topic |
| Vault | TypeScript | Pub/Sub | `investment.confirmed` topic |
| Vault | PostgreSQL | TCP (SQLx) | Direct SQL connection |
| Vault | Blockchain | JSON-RPC | ethers-rs provider |
| TypeScript | Firestore | gRPC (Admin SDK) | Direct read/write (privileged) |
| Brain | Firestore | gRPC (Admin SDK) | Conversation history read/write |
| TypeScript | Blockchain | JSON-RPC | Chain indexer (event watching) |

### Boundary Enforcement Rules

These rules prevent service coupling and maintain clear ownership:

1. **Flutter never calls the Brain or Vault directly.** All requests go through TypeScript Cloud Functions.
2. **The Brain never writes invention documents to Firestore.** It publishes `ai.processing.complete` and lets TypeScript handle the Firestore update.
3. **The Vault never writes to Firestore.** It publishes `investment.confirmed` and lets TypeScript handle the sync.
4. **Only TypeScript writes to Firestore** (with the exception of the Brain writing conversation history).
5. **Only the Vault interacts with PostgreSQL.** No other service has access to the financial ledger.
6. **Only the Vault and the Chain Indexer read blockchain state.** Flutter displays blockchain data from Firestore, not from the chain directly.

---

## Scaling Considerations

### Current Architecture (Startup Scale)

The current design handles the initial growth phase:

- **Firebase Cloud Functions** auto-scale to zero and scale up per request. No servers to manage.
- **Pub/Sub** scales horizontally with no configuration. Message throughput is effectively unlimited for this use case.
- **Firestore** scales automatically. Reads are distributed across replicas.
- **PostgreSQL** runs as a single instance. Sufficient for early financial volume.
- **The Vault** runs as a single Rust binary. Sufficient for moderate transaction watching.

### Scaling Bottlenecks and Mitigations

| Bottleneck | Trigger | Mitigation |
|-----------|---------|------------|
| **PostgreSQL single instance** | High investment volume (thousands of concurrent transactions) | Migrate to Cloud SQL with read replicas, or CockroachDB for horizontal scaling |
| **Vault chain watcher** | Multiple chains or high event volume | Shard the chain watcher by invention ID or chain. Each shard watches a subset of contracts. |
| **Brain LLM latency** | Many simultaneous invention analyses | Pub/Sub naturally buffers requests. Add more Brain instances behind a load balancer. Vertex AI auto-scales inference. |
| **Firestore hot documents** | Viral invention with thousands of simultaneous likes/comments | Use Firestore distributed counters for like/comment counts. Shard the `feed_index` collection. |
| **Blockchain RPC rate limits** | Too many `eth_call` or event filter requests | Use a dedicated RPC provider (Alchemy/Infura with growth plan). Cache block data in Redis. Batch multiple queries. |

### Future Architecture Considerations

- **Multi-chain support:** The Vault's chain watcher is designed to be chain-agnostic. Adding Base, Arbitrum, or other EVM chains requires a new RPC endpoint and chain ID configuration, not architectural changes.
- **Secondary token market:** RoyaltyTokens are standard ERC-20 tokens. They can be listed on Uniswap or any DEX without platform changes.
- **Governance:** Token-weighted voting can be added as a new smart contract that reads RoyaltyToken balances. No changes to existing contracts.
- **Horizontal Brain scaling:** Deploy multiple Brain instances behind a load balancer. Each subscribes to the same Pub/Sub subscription (Pub/Sub handles delivery to exactly one subscriber per message).

---

## Further Reading

| Document | Path | Description |
|----------|------|-------------|
| Getting Started | [docs/getting-started.md](getting-started.md) | Developer onboarding and local setup |
| API Reference | [docs/api-reference.md](api-reference.md) | Full REST endpoint documentation |
| Data Model | [docs/data-model.md](data-model.md) | Firestore and PostgreSQL schema reference |
| Smart Contracts | [docs/smart-contracts.md](smart-contracts.md) | Solidity contract interfaces and deployment |
| Event Architecture | [docs/event-driven-architecture.md](event-driven-architecture.md) | Pub/Sub topics, message formats, flow diagrams |
| AI Agent Guide | [docs/ai-agent-guide.md](ai-agent-guide.md) | The Brain: prompts, conversation flow, integration |
| Deployment | [docs/deployment.md](deployment.md) | Production deployment playbook |
| Security Model | [docs/security-model.md](security-model.md) | Authentication, authorization, Firestore rules |
| Canonical Schema | [schemas/InventionSchema.json](../schemas/InventionSchema.json) | The data contract shared across all services |
| Development Track | [ARCHITECTURE.md](../ARCHITECTURE.md) | Phase-by-phase development roadmap and task decomposition |

### Sub-Agent Specifications

| Agent | Path | Description |
|-------|------|-------------|
| Agent Overview | [docs/agents/overview.md](agents/overview.md) | Architecture of the sub-agent system |
| The Face | [docs/agents/the-face.md](agents/the-face.md) | Flutter UI and TypeScript backend specification |
| The Vault | [docs/agents/the-vault.md](agents/the-vault.md) | Rust financial engine specification |
| The Brain | [docs/agents/the-brain.md](agents/the-brain.md) | Python AI agent specification |
