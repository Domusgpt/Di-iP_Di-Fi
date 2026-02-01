# Event-Driven Architecture

> IdeaCapital Pub/Sub System -- Google Cloud Pub/Sub, Firebase Cloud Functions, Rust Vault, Python Brain

This document provides a complete reference for the event-driven messaging system that connects all IdeaCapital services. Every cross-service communication in the platform flows through Google Cloud Pub/Sub topics, enforcing loose coupling and enabling each service to be developed, deployed, and scaled independently.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Topic Reference](#topic-reference)
   - [ai.processing](#1-aiprocessing)
   - [ai.processing.complete](#2-aiprocessingcomplete)
   - [invention.created](#3-inventioncreated)
   - [investment.pending](#4-investmentpending)
   - [investment.confirmed](#5-investmentconfirmed)
   - [patent.status.updated](#6-patentstatusupdated)
3. [Flow Diagrams](#flow-diagrams)
   - [Invention Creation Flow](#invention-creation-flow)
   - [Investment Flow](#investment-flow)
   - [Dividend Distribution Flow](#dividend-distribution-flow)
4. [Blockchain Indexer](#blockchain-indexer)
5. [Message Delivery Guarantees](#message-delivery-guarantees)
6. [Error Handling and Retry Policy](#error-handling-and-retry-policy)
7. [Local Development](#local-development)

---

## Architecture Overview

IdeaCapital uses a hub-and-spoke event architecture where the TypeScript Cloud Functions backend acts as the central nervous system. All user-facing requests enter through the TypeScript API layer, which then delegates work to specialized services via Pub/Sub messages.

```
                        +-----------------------+
                        |    Flutter Client      |
                        |   (Mobile / Web)       |
                        +----------+------------+
                                   |
                              HTTPS / Firebase SDK
                                   |
                                   v
+------------------------------------------------------------------+
|              TypeScript Cloud Functions (Gen 2)                    |
|                    "The Nervous System"                            |
|                                                                   |
|   Publishes:                       Subscribes:                    |
|     ai.processing                    ai.processing.complete       |
|     invention.created                investment.pending            |
|     investment.pending               investment.confirmed          |
|                                      patent.status.updated        |
+--------+-----------------+-----------------+---------------------+
         |                 |                 |
         v                 v                 v
+----------------+ +----------------+ +------------------+
| ai.processing  | | invention      | | investment       |
|                | | .created       | | .pending         |
+-------+--------+ +-------+--------+ +--------+---------+
        |                   |                   |
        v                   v                   v
+----------------+ +----------------+ +------------------+
|  Python Brain  | |  TypeScript    | |  Rust Vault      |
|  (FastAPI)     | |  (self)        | |  (Axum)          |
|                | |                | |                   |
| Subscribes:    | | Subscribes:    | | Subscribes:       |
|  ai.processing | |  invention     | |  investment       |
|                | |  .created      | |  .pending         |
| Publishes:     | |                | |                   |
|  ai.processing | | Actions:       | | Publishes:        |
|  .complete     | |  Feed indexing | |  investment       |
+----------------+ |  Notifications | |  .confirmed       |
                   |  Reputation    | +------------------+
                   +----------------+
```

### Design Principles

- **Single responsibility:** Each topic carries messages for one domain action.
- **At-least-once delivery:** All subscribers must be idempotent. Messages may be delivered more than once.
- **Schema contract:** Publisher and subscriber agree on the exact JSON payload shape. Mismatched schemas cause silent failures.
- **No direct service calls:** Services never call each other directly. All inter-service communication goes through Pub/Sub (except the Flutter-to-TypeScript HTTPS boundary).

### Topic Naming Convention

Topics follow the pattern `<domain>.<action>`:

| Domain | Description |
|--------|-------------|
| `ai` | AI processing pipeline |
| `invention` | Invention lifecycle events |
| `investment` | Financial transaction events |
| `patent` | Legal/patent filing events |

---

## Topic Reference

All topics are defined in `infra/pubsub/topics.yaml`. Each topic section below documents the publisher, subscriber(s), message schema, and subscriber behavior.

---

### 1. ai.processing

**Description:** Request for the AI Brain to analyze or refine an invention.

| Field | Value |
|-------|-------|
| **Publisher** | TypeScript Cloud Functions (`invention-service`) |
| **Subscriber** | Python Brain (`pubsub_listener`) |
| **Trigger** | User submits a new invention or sends a follow-up message in the AI chat |

#### Message Schema

```json
{
  "action": "INITIAL_ANALYSIS | CHAT_MESSAGE",
  "invention_id": "uuid-v4",
  "creator_id": "firebase-uid",
  "raw_text": "User's description of their invention (optional)",
  "voice_url": "gs://bucket/path/to/audio.webm (optional)",
  "sketch_url": "gs://bucket/path/to/sketch.png (optional)",
  "message": "Follow-up question or refinement from the user (optional)"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action` | string | Yes | `INITIAL_ANALYSIS` for new submissions, `CHAT_MESSAGE` for follow-up conversation turns |
| `invention_id` | string (UUID) | Yes | The invention being analyzed |
| `creator_id` | string | Yes | Firebase UID of the inventor |
| `raw_text` | string | No | Freeform text description of the invention (used for initial analysis) |
| `voice_url` | string (GCS URI) | No | Cloud Storage path to a voice recording (transcribed by the Brain) |
| `sketch_url` | string (GCS URI) | No | Cloud Storage path to a sketch or diagram (analyzed by the Brain) |
| `message` | string | No | Follow-up message for the AI chat conversation (used for `CHAT_MESSAGE` action) |

#### Subscriber Behavior (Python Brain)

1. Receives the message via the Pub/Sub listener.
2. Based on `action`:
   - **INITIAL_ANALYSIS:** Runs the full invention structuring pipeline:
     - Transcribes voice input (if provided) using Vertex AI.
     - Analyzes sketches (if provided) using multimodal Gemini Pro.
     - Structures raw text into the canonical `InventionSchema` format.
     - Generates `social_metadata` (display title, short pitch, virality tags).
     - Generates `technical_brief` (field, problem, solution, mechanics, novelty claims).
     - Generates `risk_assessment` (prior art search, feasibility score, missing info).
   - **CHAT_MESSAGE:** Runs a conversational refinement turn:
     - Loads conversation history from Firestore.
     - Sends the user's message along with existing structured data to Gemini Pro.
     - Returns updated fields (any combination of social_metadata, technical_brief, risk_assessment).
3. Publishes the result to `ai.processing.complete`.

---

### 2. ai.processing.complete

**Description:** The AI Brain has finished processing. Structured data is ready for storage.

| Field | Value |
|-------|-------|
| **Publisher** | Python Brain (`pubsub_listener`) |
| **Subscriber** | TypeScript Cloud Functions (`ai-events`) |
| **Trigger** | Brain completes an analysis or chat response |

#### Message Schema

```json
{
  "invention_id": "uuid-v4",
  "action": "INITIAL_ANALYSIS_COMPLETE | CHAT_RESPONSE",
  "structured_data": {
    "social_metadata": {
      "display_title": "SolarPaint: Photovoltaic Coating",
      "short_pitch": "Turn any surface into a solar panel with sprayable photovoltaic paint",
      "virality_tags": ["GreenTech", "Solar", "Materials"]
    },
    "technical_brief": {
      "technical_field": "Renewable Energy - Photovoltaic Materials",
      "background_problem": "Traditional solar panels are rigid, expensive, and limited to rooftops...",
      "solution_summary": "A sprayable photovoltaic coating that converts any surface...",
      "core_mechanics": [
        { "step": 1, "description": "Quantum dot suspension in polymer base..." },
        { "step": 2, "description": "Application via standard spray equipment..." }
      ],
      "novelty_claims": ["Novel quantum dot formulation...", "Self-leveling polymer matrix..."],
      "hardware_requirements": ["Spray equipment", "UV curing lamp"],
      "software_logic": "N/A for this hardware invention"
    },
    "risk_assessment": {
      "potential_prior_art": [
        {
          "source": "Google Patents",
          "patent_id": "US20190280134A1",
          "similarity_score": 0.72,
          "notes": "Similar quantum dot approach but different polymer base"
        }
      ],
      "feasibility_score": 7,
      "missing_info": ["Estimated production cost per liter", "Expected conversion efficiency"]
    }
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string (UUID) | Yes | The invention that was analyzed |
| `action` | string | Yes | `INITIAL_ANALYSIS_COMPLETE` or `CHAT_RESPONSE` |
| `structured_data` | object | Yes | Contains one or more of the sub-objects below |
| `structured_data.social_metadata` | object | Conditional | Present for initial analysis; may be present for chat responses if the Brain updated it |
| `structured_data.technical_brief` | object | Conditional | Present for initial analysis; may be present for chat responses |
| `structured_data.risk_assessment` | object | Conditional | Present for initial analysis; may be present for chat responses |

#### Subscriber Behavior (TypeScript `ai-events`)

**Source:** `backend/functions/src/events/ai-events.ts`

1. Receives the message via `onMessagePublished`.
2. Based on `action`:
   - **INITIAL_ANALYSIS_COMPLETE:**
     - Updates the Firestore `inventions/{invention_id}` document with all three structured data sections.
     - Sets the invention `status` to `REVIEW_READY`.
     - Sends a push notification to the inventor: "Your draft is ready for review."
   - **CHAT_RESPONSE:**
     - Selectively updates only the fields present in `structured_data` (partial update).
     - Does not change the invention status.
3. Sets `updated_at` timestamp on the Firestore document.

---

### 3. invention.created

**Description:** Fired when an invention is published to the live feed.

| Field | Value |
|-------|-------|
| **Publisher** | TypeScript Cloud Functions (`invention-service`) |
| **Subscriber** | TypeScript Cloud Functions (`invention-events`) |
| **Trigger** | User reviews their AI-structured draft and clicks "Publish" |

#### Message Schema

```json
{
  "invention_id": "uuid-v4",
  "creator_id": "firebase-uid",
  "action": "PUBLISHED"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string (UUID) | Yes | The invention being published |
| `creator_id` | string | Yes | Firebase UID of the inventor |
| `action` | string | Yes | Currently always `PUBLISHED` (future: `ARCHIVED`, `UPDATED`) |

#### Subscriber Behavior (TypeScript `invention-events`)

**Source:** `backend/functions/src/events/invention-events.ts`

1. Receives the message via `onMessagePublished`.
2. When `action` is `PUBLISHED`:
   - **Feed indexing:** Creates a document in `feed_index/{invention_id}` with initial engagement metrics (score: 0, views: 0).
   - **Reputation update:** Increments the creator's `inventions_count` by 1 and `reputation_score` by 10 in `users/{creator_id}`.
   - **Follower notifications:** Queries `followers/{creator_id}/user_followers` (limited to 500) and sends a push notification to each follower: "{Creator} posted a new invention: {Title}".
   - Uses `Promise.allSettled` for notification fan-out so individual notification failures do not block other notifications.

---

### 4. investment.pending

**Description:** User has submitted a blockchain investment transaction.

| Field | Value |
|-------|-------|
| **Publisher** | TypeScript Cloud Functions (`investment-service`) |
| **Subscribers** | TypeScript Cloud Functions (`investment-events`), Rust Vault (`chain_watcher`) |
| **Trigger** | User signs and submits a USDC investment transaction through the Flutter wallet UI |

#### Message Schema

```json
{
  "investment_id": "firestore-doc-id",
  "invention_id": "uuid-v4",
  "tx_hash": "0xabc123...def456",
  "wallet_address": "0x1234...5678",
  "amount_usdc": 5000.00
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `investment_id` | string | Yes | Firestore document ID for this investment record |
| `invention_id` | string (UUID) | Yes | The invention being invested in |
| `tx_hash` | string (hex) | Yes | Blockchain transaction hash |
| `wallet_address` | string (hex) | Yes | Investor's wallet address (lowercased) |
| `amount_usdc` | number | Yes | USDC amount invested (human-readable, not raw 6-decimal) |

#### Subscriber Behavior

**TypeScript `investment-events` (optimistic UI update):**

**Source:** `backend/functions/src/events/investment-events.ts`

1. Receives the message and logs the pending investment.
2. Increments `funding.pending_investments` on the `inventions/{invention_id}` Firestore document.
3. This enables the Flutter UI to show a "pending" investment indicator immediately, before blockchain confirmation.

**Rust Vault `chain_watcher` (blockchain verification):**

1. Receives the message and begins polling the blockchain for the transaction receipt.
2. Uses ethers-rs to call `getTransactionReceipt(tx_hash)`.
3. Once the transaction is confirmed (receipt found with `status == 1`):
   - Parses the `Investment` event from the Crowdsale contract logs.
   - Extracts the `tokenAmount` from the event.
   - Records the verified investment in PostgreSQL.
   - Publishes to `investment.confirmed`.
4. If the transaction is reverted (`status == 0`), records the failure.

---

### 5. investment.confirmed

**Description:** Blockchain transaction confirmed. The investment is verified on-chain.

| Field | Value |
|-------|-------|
| **Publishers** | Rust Vault (`chain_watcher`), TypeScript Cloud Functions (`chain-indexer`) as fallback |
| **Subscriber** | TypeScript Cloud Functions (`investment-events`) |
| **Trigger** | Blockchain transaction receipt shows successful execution |

#### Message Schema

```json
{
  "investment_id": "firestore-doc-id",
  "invention_id": "uuid-v4",
  "wallet_address": "0x1234...5678",
  "amount_usdc": 5000.00,
  "token_amount": 250000.0,
  "block_number": 48293741
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `investment_id` | string | Yes | Firestore document ID |
| `invention_id` | string (UUID) | Yes | The invention that received the investment |
| `wallet_address` | string (hex) | Yes | Investor's wallet address |
| `amount_usdc` | number | Yes | USDC amount invested |
| `token_amount` | number | Yes | RoyaltyTokens minted to the investor |
| `block_number` | integer | Yes | Block number where the transaction was confirmed |

#### Subscriber Behavior (TypeScript `investment-events`)

**Source:** `backend/functions/src/events/investment-events.ts`

1. Receives the message via `onMessagePublished`.
2. Executes a Firestore batch write:
   - Updates `investments/{investment_id}`: sets `status` to `CONFIRMED`, records `block_number`, `token_amount`, and `confirmed_at` timestamp.
   - Updates `inventions/{invention_id}`: increments `funding.raised_usdc` by `amount_usdc`, increments `funding.backer_count` by 1, decrements `funding.pending_investments` by 1.
3. Sends a push notification to the investor: "Your investment of {amount} USDC in {title} is confirmed! You own {percent}%."
4. Checks if the funding goal has been reached (`raised_usdc >= goal_usdc`):
   - If yes, sends a push notification to the inventor: "Your invention {title} is fully funded!"

---

### 6. patent.status.updated

**Description:** Patent filing status has changed (filed, pending, granted, rejected).

| Field | Value |
|-------|-------|
| **Publisher** | Legal Backend (future integration) |
| **Subscribers** | TypeScript Cloud Functions (updates Firestore), Python Brain (may trigger follow-up analysis) |
| **Trigger** | External patent filing system reports a status change |

#### Message Schema

```json
{
  "invention_id": "uuid-v4",
  "status": "PROVISIONAL_FILED | PENDING | GRANTED | REJECTED",
  "application_number": "US2026/0012345",
  "examiner_notes": "Examiner requested additional claims clarification..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string (UUID) | Yes | The invention whose patent status changed |
| `status` | string (enum) | Yes | One of: `PROVISIONAL_FILED`, `PENDING`, `GRANTED`, `REJECTED` |
| `application_number` | string | No | Patent office application/filing number |
| `examiner_notes` | string | No | Notes from the patent examiner (if any) |

#### Subscriber Behavior

**TypeScript Cloud Functions:**

1. Updates `inventions/{invention_id}.patent_status` in Firestore with the new status, application number, and examiner notes.
2. Sends a push notification to the inventor and investors about the status change.

**Python Brain (conditional):**

1. If `status` is `REJECTED` and `examiner_notes` are provided, the Brain may trigger a follow-up analysis to suggest claim amendments.
2. This is a Phase 3+ feature and is not yet implemented.

---

## Flow Diagrams

### Invention Creation Flow

This flow covers the complete path from a user submitting a raw idea to it appearing on the public feed.

```
 User (Flutter)          TypeScript Backend        Pub/Sub           Python Brain         Firestore
      |                        |                      |                    |                   |
      |  POST /inventions      |                      |                    |                   |
      |  {raw_text, voice,     |                      |                    |                   |
      |   sketch}              |                      |                    |                   |
      |----------------------->|                      |                    |                   |
      |                        |                      |                    |                   |
      |                        |  Create invention    |                    |                   |
      |                        |  doc (status: DRAFT) |                    |                   |
      |                        |----------------------------------------------------->------->|
      |                        |                      |                    |                   |
      |                        |  Publish to          |                    |                   |
      |                        |  ai.processing       |                    |                   |
      |                        |--------------------->|                    |                   |
      |                        |                      |                    |                   |
      |                        |  Update status:      |                    |                   |
      |                        |  AI_PROCESSING       |                    |                   |
      |                        |----------------------------------------------------->------->|
      |                        |                      |                    |                   |
      |  200 OK {invention_id} |                      |                    |                   |
      |<-----------------------|                      |                    |                   |
      |                        |                      |                    |                   |
      |                        |                      |  ai.processing     |                   |
      |                        |                      |  message delivered  |                   |
      |                        |                      |------------------->|                   |
      |                        |                      |                    |                   |
      |                        |                      |                    |  Run LLM pipeline |
      |                        |                      |                    |  - Transcribe     |
      |                        |                      |                    |  - Analyze sketch |
      |                        |                      |                    |  - Structure idea |
      |                        |                      |                    |  - Search patents |
      |                        |                      |                    |  - Score risk     |
      |                        |                      |                    |                   |
      |                        |                      |  ai.processing     |                   |
      |                        |                      |  .complete         |                   |
      |                        |                      |<-------------------|                   |
      |                        |                      |                    |                   |
      |                        |  ai.processing       |                    |                   |
      |                        |  .complete delivered  |                    |                   |
      |                        |<---------------------|                    |                   |
      |                        |                      |                    |                   |
      |                        |  Update Firestore:   |                    |                   |
      |                        |  - social_metadata   |                    |                   |
      |                        |  - technical_brief   |                    |                   |
      |                        |  - risk_assessment   |                    |                   |
      |                        |  - status:           |                    |                   |
      |                        |    REVIEW_READY      |                    |                   |
      |                        |----------------------------------------------------->------->|
      |                        |                      |                    |                   |
      |  Push notification:    |                      |                    |                   |
      |  "Draft ready"         |                      |                    |                   |
      |<-----------------------|                      |                    |                   |
      |                        |                      |                    |                   |
      |  User reviews draft    |                      |                    |                   |
      |  and clicks "Publish"  |                      |                    |                   |
      |                        |                      |                    |                   |
      |  POST /inventions      |                      |                    |                   |
      |  /{id}/publish         |                      |                    |                   |
      |----------------------->|                      |                    |                   |
      |                        |                      |                    |                   |
      |                        |  Update status: LIVE |                    |                   |
      |                        |----------------------------------------------------->------->|
      |                        |                      |                    |                   |
      |                        |  Publish to          |                    |                   |
      |                        |  invention.created   |                    |                   |
      |                        |--------------------->|                    |                   |
      |                        |                      |                    |                   |
      |                        |  invention.created   |                    |                   |
      |                        |  delivered (self)    |                    |                   |
      |                        |<---------------------|                    |                   |
      |                        |                      |                    |                   |
      |                        |  - Index in feed     |                    |                   |
      |                        |  - Update reputation |                    |                   |
      |                        |  - Notify followers  |                    |                   |
      |                        |----------------------------------------------------->------->|
      |                        |                      |                    |                   |
 Followers                     |                      |                    |                   |
      |  Push: "X posted       |                      |                    |                   |
      |   a new invention"     |                      |                    |                   |
      |<-----------------------|                      |                    |                   |
```

**Invention Status Transitions:**

```
DRAFT --> AI_PROCESSING --> REVIEW_READY --> LIVE --> FUNDING --> FUNDED --> MINTED
```

---

### Investment Flow

This flow covers the complete path from a user investing USDC to the Firestore state being updated with the confirmed investment.

```
 Investor (Flutter)     TypeScript Backend     Pub/Sub        Rust Vault       Blockchain      Firestore
      |                       |                   |               |                |               |
      |  POST /investments    |                   |               |                |               |
      |  /{invention_id}      |                   |               |                |               |
      |  /invest              |                   |               |                |               |
      |  {amount, wallet}     |                   |               |                |               |
      |---------------------->|                   |               |                |               |
      |                       |                   |               |                |               |
      |                       |  Create investment|               |                |               |
      |                       |  doc (PENDING)    |               |                |               |
      |                       |--------------------------------------------------------------->|
      |                       |                   |               |                |               |
      |  Tx data to sign      |                   |               |                |               |
      |<----------------------|                   |               |                |               |
      |                       |                   |               |                |               |
      |  User signs tx        |                   |               |                |               |
      |  in wallet (Reown)    |                   |               |                |               |
      |                       |                   |               |                |               |
      |  Submit signed tx     |                   |               |                |               |
      |---------------------------------------------------------------------->---->|               |
      |                       |                   |               |                |               |
      |  tx_hash returned     |                   |               |                |               |
      |<----------------------------------------------------------------------<----|               |
      |                       |                   |               |                |               |
      |  POST /investments    |                   |               |                |               |
      |  /{id}/submitted      |                   |               |                |               |
      |  {tx_hash}            |                   |               |                |               |
      |---------------------->|                   |               |                |               |
      |                       |                   |               |                |               |
      |                       |  Update doc with  |               |                |               |
      |                       |  tx_hash          |               |                |               |
      |                       |--------------------------------------------------------------->|
      |                       |                   |               |                |               |
      |                       |  Publish to       |               |                |               |
      |                       |  investment       |               |                |               |
      |                       |  .pending         |               |                |               |
      |                       |------------------>|               |                |               |
      |                       |                   |               |                |               |
      |  200 OK               |                   |               |                |               |
      |<----------------------|                   |               |                |               |
      |                       |                   |               |                |               |
      |                       |  investment       |               |                |               |
      |                       |  .pending         |               |                |               |
      |                       |  (self-sub)       |               |                |               |
      |                       |<------------------|               |                |               |
      |                       |                   |               |                |               |
      |                       |  Optimistic UI:   |               |                |               |
      |                       |  increment        |               |                |               |
      |                       |  pending count    |               |                |               |
      |                       |--------------------------------------------------------------->|
      |                       |                   |               |                |               |
      |                       |                   |  investment   |                |               |
      |                       |                   |  .pending     |                |               |
      |                       |                   |  delivered    |                |               |
      |                       |                   |-------------->|                |               |
      |                       |                   |               |                |               |
      |                       |                   |               |  Poll for      |               |
      |                       |                   |               |  tx receipt    |               |
      |                       |                   |               |--------------->|               |
      |                       |                   |               |                |               |
      |                       |                   |               |  Receipt found |               |
      |                       |                   |               |  status: 1     |               |
      |                       |                   |               |<---------------|               |
      |                       |                   |               |                |               |
      |                       |                   |               |  Parse         |               |
      |                       |                   |               |  Investment    |               |
      |                       |                   |               |  event from    |               |
      |                       |                   |               |  tx logs       |               |
      |                       |                   |               |                |               |
      |                       |                   |               |  Record in     |               |
      |                       |                   |               |  PostgreSQL    |               |
      |                       |                   |               |                |               |
      |                       |                   |  investment   |                |               |
      |                       |                   |  .confirmed   |                |               |
      |                       |                   |<--------------|                |               |
      |                       |                   |               |                |               |
      |                       |  investment       |               |                |               |
      |                       |  .confirmed       |               |                |               |
      |                       |  delivered        |               |                |               |
      |                       |<------------------|               |                |               |
      |                       |                   |               |                |               |
      |                       |  Batch write:     |               |                |               |
      |                       |  - investment:    |               |                |               |
      |                       |    CONFIRMED      |               |                |               |
      |                       |  - invention:     |               |                |               |
      |                       |    raised_usdc++  |               |                |               |
      |                       |    backer_count++ |               |                |               |
      |                       |    pending--      |               |                |               |
      |                       |--------------------------------------------------------------->|
      |                       |                   |               |                |               |
      |  Push notification:   |                   |               |                |               |
      |  "Investment          |                   |               |                |               |
      |   confirmed!"         |                   |               |                |               |
      |<----------------------|                   |               |                |               |
      |                       |                   |               |                |               |
      |                       |  Check: raised    |               |                |               |
      |                       |  >= goal?         |               |                |               |
      |                       |  If yes: notify   |               |                |               |
      |                       |  inventor "Fully  |               |                |               |
      |                       |  funded!"         |               |                |               |
```

**Investment Status Transitions:**

```
PENDING --> CONFIRMED (success)
PENDING --> FAILED    (tx reverted)
```

---

### Dividend Distribution Flow

This flow covers the complete path from licensing revenue arriving to a token holder claiming their dividend on-chain.

```
 Revenue Source       Platform         Rust Vault          DividendVault       Token Holder
      |                  |                  |               (On-Chain)              |
      |  USDC revenue    |                  |                   |                   |
      |  received        |                  |                   |                   |
      |----------------->|                  |                   |                   |
      |                  |                  |                   |                   |
      |                  |  Trigger         |                   |                   |
      |                  |  distribution    |                   |                   |
      |                  |----------------->|                   |                   |
      |                  |                  |                   |                   |
      |                  |                  |  1. Query all     |                   |
      |                  |                  |  RoyaltyToken     |                   |
      |                  |                  |  holders from     |                   |
      |                  |                  |  PostgreSQL       |                   |
      |                  |                  |                   |                   |
      |                  |                  |  2. Calculate     |                   |
      |                  |                  |  each holder's    |                   |
      |                  |                  |  proportional     |                   |
      |                  |                  |  share:           |                   |
      |                  |                  |  share = revenue  |                   |
      |                  |                  |  * (balance /     |                   |
      |                  |                  |    totalSupply)   |                   |
      |                  |                  |                   |                   |
      |                  |                  |  3. Build Merkle  |                   |
      |                  |                  |  tree:            |                   |
      |                  |                  |  leaf = keccak256 |                   |
      |                  |                  |  (bytes.concat(   |                   |
      |                  |                  |   keccak256(      |                   |
      |                  |                  |    abi.encode(    |                   |
      |                  |                  |     addr,amt)))) |                   |
      |                  |                  |                   |                   |
      |                  |                  |  4. Store proofs  |                   |
      |                  |                  |  in PostgreSQL    |                   |
      |                  |                  |  (dividend_claims)|                   |
      |                  |                  |                   |                   |
      |                  |                  |  5. Call          |                   |
      |                  |                  |  createDistribution                   |
      |                  |                  |  (merkleRoot,     |                   |
      |                  |                  |   totalAmount)    |                   |
      |                  |                  |------------------>|                   |
      |                  |                  |                   |                   |
      |                  |                  |                   |  USDC transferred |
      |                  |                  |                   |  into vault       |
      |                  |                  |                   |  Epoch incremented|
      |                  |                  |                   |  Root stored      |
      |                  |                  |                   |                   |
      |                  |                  |                   |  emit             |
      |                  |                  |                   |  NewDistribution  |
      |                  |                  |                   |  (epoch, root,    |
      |                  |                  |                   |   totalAmount)    |
      |                  |                  |                   |                   |
      |                  |  Notify holders  |                   |                   |
      |                  |  "Dividend       |                   |                   |
      |                  |   available"     |                   |                   |
      |                  |------------------------------------------------>------->|
      |                  |                  |                   |                   |
      |                  |                  |                   |                   |
      |                  |                  |  6. Holder        |                   |
      |                  |                  |  requests proof   |                   |
      |                  |                  |  via API          |                   |
      |                  |                  |<-----------------------------------------|
      |                  |                  |                   |                   |
      |                  |                  |  Return:          |                   |
      |                  |                  |  {epoch, amount,  |                   |
      |                  |                  |   proof[]}        |                   |
      |                  |                  |----------------------------------------->|
      |                  |                  |                   |                   |
      |                  |                  |                   |  7. Call          |
      |                  |                  |                   |  claimDividend    |
      |                  |                  |                   |  (epoch, amount,  |
      |                  |                  |                   |   proof[])        |
      |                  |                  |                   |<------------------|
      |                  |                  |                   |                   |
      |                  |                  |                   |  Verify proof     |
      |                  |                  |                   |  Mark claimed     |
      |                  |                  |                   |  Transfer USDC    |
      |                  |                  |                   |                   |
      |                  |                  |                   |  emit             |
      |                  |                  |                   |  DividendClaimed  |
      |                  |                  |                   |  (epoch, addr,    |
      |                  |                  |                   |   amount)         |
      |                  |                  |                   |                   |
      |                  |                  |                   |  USDC sent to     |
      |                  |                  |                   |  holder           |
      |                  |                  |                   |------------------>|
```

**Key Steps Summary:**

1. **Revenue arrives** at the platform (USDC from licensing deals).
2. **Vault calculates shares** by querying all RoyaltyToken holder balances and computing proportional amounts.
3. **Vault builds Merkle tree** with leaves encoded as `keccak256(bytes.concat(keccak256(abi.encode(address, amount))))`.
4. **Vault stores individual proofs** in PostgreSQL `dividend_claims` table for API retrieval.
5. **Vault posts Merkle root** on-chain via `DividendVault.createDistribution()`, depositing the total USDC.
6. **Holders request their proof** from the Vault API (`GET /dividends/{epoch}/claim`).
7. **Holders submit on-chain claim** by calling `DividendVault.claimDividend(epoch, amount, proof)`.

---

## Blockchain Indexer

**Source:** `backend/functions/src/events/chain-indexer.ts`

The blockchain indexer is a scheduled Cloud Function that serves as a fallback mechanism for confirming investment transactions. In production, the Rust Vault's `chain_watcher` is the primary confirmation path, but the indexer provides redundancy.

### Configuration

| Setting | Value |
|---------|-------|
| **Schedule** | Every 1 minute |
| **Region** | `us-central1` |
| **Memory** | 256 MiB |
| **Timeout** | 60 seconds |
| **Batch size** | 50 pending investments per run |

### Behavior

1. **Query pending investments:** Reads up to 50 documents from `investments` collection where `status == "PENDING"`.
2. **Check each transaction:** For each pending investment, calls `provider.getTransactionReceipt(tx_hash)` against the configured RPC endpoint.
3. **If no receipt:** The transaction has not been mined yet. Skip and check again next cycle.
4. **If receipt with status 1 (success):**
   - Parses the Crowdsale `Investment` event from the transaction logs to extract the `tokenAmount`.
   - Publishes an `investment.confirmed` message to Pub/Sub with the full confirmation payload.
5. **If receipt with status 0 (reverted):**
   - Updates the Firestore investment document to `status: "FAILED"` with a `failed_at` timestamp.
6. **Error handling:** Individual transaction check failures are logged but do not halt the batch. The failed transaction will be retried on the next cycle.

### Why Both the Vault and the Indexer Exist

| Aspect | Rust Vault (chain_watcher) | TypeScript Indexer |
|--------|----------------------------|---------------------|
| **Latency** | Near real-time (event-driven) | Up to 60-second delay (polling) |
| **Reliability** | Depends on Vault uptime | Runs as managed Cloud Function (auto-restart) |
| **Purpose** | Primary confirmation path | Fallback / catch-up mechanism |
| **Phase** | Phase 2+ (requires Vault deployment) | Phase 2 MVP (works without Vault) |

Both systems publish to the same `investment.confirmed` topic. The TypeScript subscriber is idempotent -- processing the same confirmation twice has no adverse effect because the Firestore batch write uses absolute values for status and timestamps.

---

## Message Delivery Guarantees

Google Cloud Pub/Sub provides **at-least-once delivery**. This means:

- A message may be delivered more than once to a subscriber.
- A message will not be lost (unless the topic or subscription is deleted).
- Message ordering is not guaranteed across different messages (but is guaranteed for messages with the same ordering key, if configured).

### Idempotency Requirements

All subscribers MUST be idempotent. Specific strategies used in IdeaCapital:

| Subscriber | Idempotency Strategy |
|------------|---------------------|
| `ai-events` (ai.processing.complete) | Firestore `update` is idempotent -- writing the same structured_data twice produces the same result |
| `invention-events` (invention.created) | `feed_index` doc uses `set` (not `create`), so duplicate publishes overwrite with the same data. `FieldValue.increment` is NOT idempotent, but duplicate invention creation events are rare and the impact (extra reputation points) is minor |
| `investment-events` (investment.pending) | `FieldValue.increment(1)` on `pending_investments` is not strictly idempotent, but pending counts are corrected when the investment is confirmed |
| `investment-events` (investment.confirmed) | Status is set to `CONFIRMED` (absolute, not incremental), and `raised_usdc` uses `FieldValue.increment`. Duplicate processing could over-count raised amounts; in production, a deduplication check on `investment_id` should be added |

---

## Error Handling and Retry Policy

### Pub/Sub Retry Behavior

Firebase Cloud Functions with Pub/Sub triggers use the following retry policy:

- **Default:** Retry on failure with exponential backoff (up to 7 days).
- **Recommendation:** Functions should throw an error to trigger a retry, or return successfully to acknowledge the message.
- **Dead-letter topic:** Not currently configured. Failed messages will retry until the 7-day retention expires.

### Per-Subscriber Error Handling

| Subscriber | Error Behavior |
|------------|---------------|
| `ai-events` | If Firestore write fails, the function throws and the message is retried. If the Brain sends malformed data, the function logs an error and acknowledges (no retry). |
| `invention-events` | Notification failures use `Promise.allSettled` -- individual push notification failures do not block others or cause retries. Firestore write failures trigger retry. |
| `investment-events` (pending) | Firestore increment failure triggers retry. |
| `investment-events` (confirmed) | Batch write failure triggers retry. Notification failure after batch write is logged but does not cause retry (the critical Firestore update already succeeded). |
| `chain-indexer` | RPC errors for individual transactions are caught and logged. The function does not throw, so the schedule continues. Failed checks are retried on the next 1-minute cycle. |

---

## Local Development

### Firebase Emulator Pub/Sub

The Firebase emulator suite includes a Pub/Sub emulator running on port 8085. All topics defined in `infra/pubsub/topics.yaml` are available locally.

```bash
# Start the full stack (includes Pub/Sub emulator)
docker compose up

# Or start just Firebase emulators
cd backend/functions && npm run build && firebase emulators:start
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUBSUB_EMULATOR_HOST` | Pub/Sub emulator endpoint | `localhost:8085` |
| `FIRESTORE_EMULATOR_HOST` | Firestore emulator endpoint | `localhost:8082` |
| `RPC_URL` | Blockchain JSON-RPC endpoint | `http://localhost:8545` (Hardhat) |

### Testing Pub/Sub Locally

Messages can be published manually using the `gcloud` CLI or the Pub/Sub emulator API:

```bash
# Publish a test message to ai.processing
gcloud pubsub topics publish ai.processing \
  --message='{"action":"INITIAL_ANALYSIS","invention_id":"test-123","creator_id":"user-abc","raw_text":"A solar-powered water purifier"}' \
  --project=ideacapital-dev
```

### Monitoring

The Firebase Emulator UI (port 4000) provides visibility into:

- Messages published to each topic
- Function invocations triggered by Pub/Sub messages
- Function execution logs and errors
- Firestore document changes resulting from event processing
