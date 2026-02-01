# Sub-Agent Architecture Overview

IdeaCapital is decomposed into **three autonomous sub-agents**, each owning a complete vertical slice of the platform. This separation enforces clear boundaries around data ownership, technology choice, and deployment lifecycle.

---

## Agent Summary

| Agent | Language | Responsibility | Data Store |
|---|---|---|---|
| **The Face** | Dart + TypeScript | UI, social features, API gateway, event routing | Firestore |
| **The Brain** | Python | AI analysis, patent search, invention structuring | Firestore (via Admin SDK) |
| **The Vault** | Rust | Blockchain verification, financial ledger, dividends | PostgreSQL + Blockchain |

---

## Integration Rules

The following rules govern how the three agents interact. Violations of these rules should be treated as architectural defects.

### 1. Pub/Sub Is the Only Communication Channel

Agents communicate **exclusively** through Google Cloud Pub/Sub in production. Direct HTTP calls between services are forbidden because they create tight coupling and make it impossible to reason about failure modes independently.

- **The Face** publishes events such as `invention.created` and `investment.pending`.
- **The Brain** subscribes to `invention.created`, performs AI analysis, and publishes `ai.processing.complete`.
- **The Vault** subscribes to `investment.pending`, verifies the on-chain transaction, and publishes `investment.confirmed`.

### 2. Exclusive Data Ownership

Each agent owns its primary data store and is the **sole writer** to that store.

- **The Face** owns Firestore for user-facing documents (profiles, inventions, comments, likes, notifications).
- **The Brain** writes AI analysis results back to Firestore via the Admin SDK, but only to fields explicitly designated for AI output within the invention document.
- **The Vault** owns PostgreSQL for the financial ledger (investments, dividend distributions, claims). It also reads from the blockchain but never writes to Firestore directly.

Cross-agent data needs are fulfilled by events. For example, when the Vault confirms an investment, it publishes `investment.confirmed`; the Face's event handler then updates the relevant Firestore documents.

### 3. Shared Contract: InventionSchema.json

The canonical **InventionSchema.json** file is the single source of truth for the shape of an invention record. All three agents must conform to this schema when reading or writing invention data. Changes to the schema require coordination across all agents.

### 4. Firestore as the Meeting Point

From the Flutter client's perspective, **Firestore is the only data source**. The client never calls the Brain or the Vault directly. Instead:

- The Brain's AI analysis results are written into Firestore invention documents.
- The Vault's investment confirmations are reflected in Firestore via event-driven Cloud Functions.
- The Flutter app subscribes to Firestore streams and receives real-time updates regardless of which agent produced the data.

---

## Architecture Diagram (Logical)

```
Flutter Client
     |
     | Firestore streams + REST API
     v
+-----------+       Pub/Sub        +-----------+
|           | -------------------> |           |
| The Face  |                      | The Brain |
| (Dart/TS) | <------------------- | (Python)  |
|           |       Pub/Sub        |           |
+-----------+                      +-----------+
     |
     | Pub/Sub
     v
+-----------+
|           |
| The Vault |
|  (Rust)   |
|           |
+-----------+
     |
     v
PostgreSQL + Blockchain
```

---

## Development Phases

The project is delivered in three sequential phases. Each phase builds on the outputs of the previous one.

### Phase 1 — Foundation

**Goal:** Scaffold all services, define schemas, and establish mock integrations.

- Set up the Flutter project with Riverpod, GoRouter, and Firebase SDK integration.
- Create the TypeScript Cloud Functions project with Express router scaffolding.
- Create the Python Brain service with a FastAPI skeleton and mock AI responses.
- Create the Rust Vault service with an Axum skeleton and mock verification logic.
- Define `InventionSchema.json` and Firestore security rules.
- Define the PostgreSQL schema for the Vault.
- Establish Pub/Sub topic and subscription definitions.

### Phase 2 — Integration

**Goal:** Wire Pub/Sub, implement real business logic, and enable blockchain verification.

- Connect all three agents through live Pub/Sub topics.
- Implement real AI analysis in the Brain (patent search, structuring, scoring).
- Implement real on-chain transaction verification in the Vault using ethers-rs.
- Build the investment flow end-to-end: UI submission, pending event, Vault verification, confirmation event, Firestore update.
- Implement dividend distribution with Merkle tree proof generation.

### Phase 3 — Polish

**Goal:** Wallet connection, real AI integration, and production deployment.

- Integrate browser/mobile wallet connection in Flutter (WalletConnect or equivalent).
- Harden AI prompts and integrate production LLM endpoints.
- Deploy all services to Google Cloud (Cloud Run for Brain and Vault, Firebase Hosting + Functions for the Face).
- Enable monitoring, alerting, and structured logging across all agents.
- Conduct security review of Firestore rules, Pub/Sub IAM policies, and smart contract audits.
