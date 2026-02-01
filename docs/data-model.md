# IdeaCapital Data Model Reference

> Comprehensive documentation of all data structures, storage schemas, and entity relationships across Firestore and PostgreSQL.

---

## Table of Contents

1. [Overview](#overview)
2. [Invention Status Lifecycle](#invention-status-lifecycle)
3. [InventionSchema -- The Canonical Contract](#inventionschema----the-canonical-contract)
4. [Firestore Collections](#firestore-collections)
   - [users/{uid}](#usersuid)
   - [users/{uid}/notifications/{id}](#usersuidnotificationsid)
   - [inventions/{id}](#inventionsid)
   - [inventions/{id}/comments/{id}](#inventionsidcommentsid)
   - [inventions/{id}/likes/{uid}](#inventionsidlikesuid)
   - [inventions/{id}/conversation_history/{id}](#inventionsidconversation_historyid)
   - [investments/{id}](#investmentsid)
   - [following/{uid}/user_following/{targetUid}](#followinguiduser_followingtargetuid)
   - [followers/{uid}/user_followers/{followerUid}](#followersuiduser_followersfolloweruid)
   - [feed_index/{inventionId}](#feed_indexinventionid)
   - [pledges/{id}](#pledgesid)
5. [PostgreSQL Tables (Vault)](#postgresql-tables-vault)
   - [investments](#investments-table)
   - [dividend_distributions](#dividend_distributions-table)
   - [dividend_claims](#dividend_claims-table)
   - [invention_ledger](#invention_ledger-table)
6. [Cross-Service Data Flow](#cross-service-data-flow)
7. [Schema Mirrors](#schema-mirrors)
8. [Precision and Encoding](#precision-and-encoding)

---

## Overview

IdeaCapital uses a **hybrid storage architecture** optimized for each use case:

| Store | Technology | Purpose | Access Pattern |
|-------|-----------|---------|---------------|
| **Firestore** | Google Cloud Firestore (NoSQL) | Social data, user profiles, invention documents, feed index | High read volume, real-time subscriptions, low financial risk |
| **PostgreSQL** | PostgreSQL 15+ | Financial ledger, investment records, dividend distributions | Transactional integrity, decimal precision, audit trail |
| **Blockchain** | Polygon / Base (EVM) | Source of truth for ownership, payments, and IP-NFT minting | Immutable, trustless, publicly verifiable |

### Design Principles

1. **Blockchain is Source of Truth.** Financial ownership and token balances are authoritative only on-chain.
2. **Firestore is Fast Cache.** The TypeScript backend syncs blockchain events into Firestore for fast reads and real-time UI updates.
3. **PostgreSQL is the Financial Ledger.** The Vault records verified transactions with full decimal precision for accounting and dividend calculations.
4. **One Canonical Schema.** The `InventionSchema.json` file in `/schemas/` is the single source of truth for the invention data structure. All four languages (Dart, TypeScript, Python, Rust) mirror this schema.

---

## Invention Status Lifecycle

Every invention follows a strictly ordered status progression. Transitions are enforced by the backend and triggered by specific events.

```
                    User submits idea
                          |
                          v
                    +-----------+
                    |   DRAFT   |  Invention created, not yet sent to AI
                    +-----------+
                          |
                    POST /api/inventions/analyze
                          |
                          v
                  +----------------+
                  | AI_PROCESSING  |  The Brain is structuring the idea
                  +----------------+
                          |
                    ai.processing.complete (Pub/Sub)
                          |
                          v
                  +----------------+
                  | REVIEW_READY   |  AI has generated the patent brief; inventor reviews
                  +----------------+
                          |
                    POST /api/inventions/:id/publish
                          |
                          v
                    +-----------+
                    |   LIVE    |  Visible on the public discovery feed
                    +-----------+
                          |
                    Funding campaign starts
                          |
                          v
                  +----------------+
                  |   FUNDING      |  Crowdsale is open, accepting USDC investments
                  +----------------+
                          |
                    Goal reached (raised_usdc >= goal_usdc)
                          |
                          v
                  +----------------+
                  |   FUNDED       |  Crowdsale closed successfully
                  +----------------+
                          |
                    IP-NFT minted on-chain
                          |
                          v
                  +----------------+
                  |   MINTED       |  IP-NFT exists on-chain, RoyaltyTokens distributed
                  +----------------+
                          |
                    Licensing deals secured
                          |
                          v
                  +----------------+
                  |  LICENSING     |  Patent filed, licensing agreements active
                  +----------------+
                          |
                    Revenue received
                          |
                          v
                  +----------------+
                  |   REVENUE      |  Dividends being distributed to token holders
                  +----------------+
```

### Status Enum Values

```typescript
type InventionStatus =
  | "DRAFT"           // Initial creation, pre-AI
  | "AI_PROCESSING"   // Brain is analyzing the idea
  | "REVIEW_READY"    // AI draft ready for inventor review
  | "LIVE"            // Published to public feed
  | "FUNDING"         // Crowdsale active
  | "FUNDED"          // Funding goal met
  | "MINTED"          // IP-NFT minted, tokens distributed
  | "LICENSING"       // Active licensing agreements
  | "REVENUE";        // Generating revenue, dividends flowing
```

---

## InventionSchema -- The Canonical Contract

The canonical schema is defined in `/schemas/InventionSchema.json`. This is the single data contract that all services must conform to. Below is a field-by-field reference.

**Source file:** `/home/user/Di-iP_Di-Fi/schemas/InventionSchema.json`

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string (UUID v4) | Yes | Globally unique identifier |
| `status` | InventionStatus enum | Yes | Current lifecycle state (see enum above) |
| `created_at` | ISO 8601 datetime | Yes | When the invention was first created |
| `updated_at` | ISO 8601 datetime | No | Last modification timestamp |
| `creator_id` | string | No | Firebase UID of the inventor |

### `social_metadata` (required)

Public-facing content displayed on the discovery feed. Optimized for engagement and discoverability.

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `display_title` | string | Yes | Max 60 chars | Catchy marketing name for the invention |
| `short_pitch` | string | Yes | Max 280 chars | The "tweet" version -- concise value proposition |
| `virality_tags` | string[] | No | | Discovery tags (e.g., `["GreenTech", "Robotics", "AI"]`) |
| `media_assets` | object | No | | Visual content for the listing |
| `media_assets.hero_image_url` | string (URI) | No | | Primary image displayed on feed cards |
| `media_assets.explainer_video_url` | string (URI) | No | | Explainer or pitch video |
| `media_assets.thumbnail_url` | string (URI) | No | | Small thumbnail for compact views |
| `media_assets.gallery` | string[] (URIs) | No | | Additional images for the detail page |

### `technical_brief`

The AI-structured legal and technical foundation. This section is the core output of The Brain's analysis and forms the basis for patent filing.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `technical_field` | string | No | Classification of the invention domain (e.g., "Portable Consumer Electronics - Battery Management") |
| `background_problem` | string | No | The pain point or market gap this invention addresses |
| `solution_summary` | string | No | How the invention solves the problem |
| `core_mechanics` | object[] | No | Step-by-step functional breakdown of how the invention works |
| `core_mechanics[].step` | integer | Yes (per item) | Sequential step number |
| `core_mechanics[].description` | string | Yes (per item) | Description of what happens at this step |
| `novelty_claims` | string[] | No | Specific aspects that make this invention unique and potentially patentable |
| `hardware_requirements` | string[] | No | Physical components needed to build the invention |
| `software_logic` | string | No | Description of algorithms, firmware, or software logic involved |

### `risk_assessment`

AI pre-vetting to save lawyers time and give investors confidence. Generated by The Brain during analysis.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `potential_prior_art` | object[] | No | Known similar inventions or patents |
| `potential_prior_art[].source` | string | No | Where the prior art was found (e.g., "Google Patents") |
| `potential_prior_art[].patent_id` | string | No | Patent number or document ID |
| `potential_prior_art[].similarity_score` | number | No | 0.0 to 1.0 similarity rating |
| `potential_prior_art[].notes` | string | No | Explanation of similarities and differences |
| `feasibility_score` | integer | No | 1 to 10 AI estimate of technical viability |
| `missing_info` | string[] | No | Information gaps the inventor needs to fill |

### `funding`

Crowdfunding campaign parameters. Set when the invention transitions to `FUNDING` status.

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `goal_usdc` | number | No | >= 0 | Target funding amount in USDC |
| `raised_usdc` | number | No | >= 0 | Current amount raised |
| `backer_count` | integer | No | >= 0 | Number of unique investors |
| `min_investment_usdc` | number | No | >= 0 | Minimum single investment amount |
| `royalty_percentage` | number | No | 0-100 | Percentage of future revenue allocated to backers |
| `deadline` | ISO 8601 datetime | No | | Campaign end date |
| `token_supply` | integer | No | | Total RoyaltyToken supply for this invention |
| `pending_investments` | number | No | | Count of investments awaiting blockchain confirmation |

### `blockchain_ref`

On-chain references. Populated after the invention is minted as an IP-NFT.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `nft_contract_address` | string | No | Address of the IPNFT contract |
| `nft_token_id` | string | No | Token ID within the IPNFT contract |
| `royalty_token_address` | string | No | ERC-20 RoyaltyToken contract address |
| `crowdsale_address` | string | No | Crowdsale contract address |
| `chain_id` | integer | No | EVM chain ID (137 for Polygon, 8453 for Base) |
| `ipfs_metadata_cid` | string | No | IPFS content identifier for the metadata JSON |

### `patent_status`

Legal and patent filing status. Updated externally as the patent process progresses.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | enum | No | One of: `NOT_FILED`, `PROVISIONAL_FILED`, `PENDING`, `GRANTED`, `REJECTED` |
| `filing_date` | ISO 8601 datetime | No | Date the patent application was filed |
| `patent_number` | string | No | Assigned patent number (when granted) |
| `jurisdiction` | string | No | Filing jurisdiction (e.g., "US", "EU", "PCT") |

---

## Firestore Collections

Firestore is the primary database for social features, user profiles, and cached invention data. All documents are accessed via the Firebase Admin SDK (server-side) or Firebase Client SDK (Flutter, for real-time reads).

---

### `users/{uid}`

Stores the user profile for each registered user. The document ID is the Firebase Auth UID.

**Path:** `users/{uid}`

**Created by:** Firestore trigger `onUserCreated` (when a new Firebase Auth user is provisioned)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `uid` | string | (from Auth) | Firebase Auth UID (matches document ID) |
| `display_name` | string | `""` | User-facing display name |
| `email` | string | (from Auth) | Email address |
| `avatar_url` | string | `null` | URL to profile picture |
| `bio` | string | `""` | Short user biography |
| `wallet_address` | string | `null` | Connected EVM wallet address (set via `PUT /api/profile/wallet`) |
| `badges` | string[] | `[]` | Achievement badges (e.g., `"early_adopter"`, `"first_invention"`, `"top_investor"`) |
| `reputation_score` | number | `0` | Composite reputation score based on activity |
| `inventions_count` | number | `0` | Number of inventions published |
| `investments_count` | number | `0` | Number of investments made |
| `role` | string | `"user"` | User role (`"user"`, `"inventor"`, `"investor"`) |
| `created_at` | Timestamp | Server timestamp | Account creation time |
| `updated_at` | Timestamp | Server timestamp | Last profile update |

**Access Rules:**
- Public read (anyone can view profiles)
- Owner write only (users can only update their own profile)

---

### `users/{uid}/notifications/{id}`

Per-user notification feed. Notifications are created by backend Pub/Sub handlers when relevant events occur (e.g., investment confirmed, comment received, AI analysis complete).

**Path:** `users/{uid}/notifications/{id}`

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Notification headline (e.g., "Investment Confirmed!") |
| `body` | string | Detailed notification text |
| `type` | string | Notification category: `"investment_confirmed"`, `"ai_complete"`, `"comment"`, `"like"`, `"funding_milestone"`, `"dividend_available"` |
| `data` | map | Contextual payload (varies by type, e.g., `{ "invention_id": "...", "amount_usdc": 1000 }`) |
| `read` | boolean | Whether the user has seen this notification (default: `false`) |
| `created_at` | Timestamp | When the notification was generated |

**Access Rules:**
- Owner read only
- Admin/backend write only

---

### `inventions/{id}`

The primary invention document. Stores the full `InventionSchema` data. The document ID is the `invention_id` (UUID v4).

**Path:** `inventions/{id}`

This document conforms to the canonical `InventionSchema.json`. See the [InventionSchema section](#inventionschema----the-canonical-contract) above for the complete field reference. Key fields:

| Field | Type | Description |
|-------|------|-------------|
| `invention_id` | string (UUID) | Matches document ID |
| `creator_id` | string | Firebase UID of the inventor |
| `status` | InventionStatus | Current lifecycle state |
| `social_metadata` | map | Display title, pitch, tags, media (see schema) |
| `technical_brief` | map | AI-generated technical analysis (see schema) |
| `risk_assessment` | map | Prior art search results, feasibility score (see schema) |
| `funding` | map | Crowdsale parameters and progress (see schema) |
| `blockchain_ref` | map | On-chain contract references (see schema) |
| `patent_status` | map | Legal filing status (see schema) |
| `like_count` | number | Denormalized total like count (updated atomically by social service) |
| `created_at` | Timestamp | Invention creation time |
| `updated_at` | Timestamp | Last modification time |

**Access Rules:**
- Public read (published inventions are visible to everyone)
- Creator write (only the inventor can modify their own invention)
- Admin write (backend services update status and AI-generated fields)

---

### `inventions/{id}/comments/{id}`

Comments on an invention. Supports threaded replies via the `parent_id` field.

**Path:** `inventions/{inventionId}/comments/{commentId}`

| Field | Type | Description |
|-------|------|-------------|
| `comment_id` | string (UUID) | Unique comment identifier (matches document ID) |
| `user_id` | string | Firebase UID of the commenter |
| `display_name` | string | Denormalized display name (copied from user profile at comment creation) |
| `avatar_url` | string or null | Denormalized avatar URL |
| `text` | string | Comment text (1-2000 characters) |
| `parent_id` | string or null | Parent comment ID for threaded replies; `null` for top-level comments |
| `created_at` | Timestamp | When the comment was posted |
| `like_count` | number | Number of likes on this comment |

**Access Rules:**
- Public read
- Authenticated create (any signed-in user)
- Owner delete (users can only delete their own comments)

---

### `inventions/{id}/likes/{uid}`

Like records for an invention. Each document is keyed by the user's UID, ensuring one like per user per invention.

**Path:** `inventions/{inventionId}/likes/{uid}`

| Field | Type | Description |
|-------|------|-------------|
| `user_id` | string | Firebase UID of the user who liked |
| `created_at` | Timestamp | When the like was recorded |

**Access Rules:**
- Public read
- Owner write (users can only add/remove their own likes)

---

### `inventions/{id}/conversation_history/{id}`

Stores the multi-turn conversation between the inventor and The Brain AI agent. Each document represents one turn in the conversation.

**Path:** `inventions/{inventionId}/conversation_history/{turnId}`

| Field | Type | Description |
|-------|------|-------------|
| `role` | string | Who sent this message: `"user"` (inventor) or `"assistant"` (AI agent) |
| `content` | string | The message text |
| `updated_fields` | map or null | Schema fields that were updated as a result of this turn (assistant turns only) |
| `schema_completeness` | number or null | Percentage of InventionSchema fields filled (0-100, assistant turns only) |
| `created_at` | Timestamp | When this turn occurred |

**Access Rules:**
- Authenticated read (invention creator and admin)
- Admin write only (written by the Brain via the TypeScript backend)

---

### `investments/{id}`

Investment records in Firestore. This is the cached version of investment data -- the authoritative record lives in The Vault's PostgreSQL database and on-chain. The Firestore copy enables real-time UI updates.

**Path:** `investments/{investmentId}`

| Field | Type | Description |
|-------|------|-------------|
| `investment_id` | string (UUID) | Unique investment identifier (matches document ID) |
| `invention_id` | string (UUID) | Target invention |
| `user_id` | string | Firebase UID of the investor |
| `wallet_address` | string | Investor's EVM wallet address |
| `amount_usdc` | number | Investment amount in USDC |
| `tx_hash` | string | Blockchain transaction hash |
| `status` | string | `"PENDING"`, `"CONFIRMED"`, or `"FAILED"` |
| `block_number` | number or null | Block number where the transaction was confirmed |
| `token_amount` | number or null | RoyaltyTokens allocated to the investor |
| `created_at` | Timestamp | When the investment was submitted |
| `confirmed_at` | Timestamp or null | When the blockchain confirmation was received |

**Access Rules:**
- Authenticated read
- Admin write only (updated by the TypeScript backend when Pub/Sub events arrive)

---

### `following/{uid}/user_following/{targetUid}`

Tracks which users someone is following. The top-level document `following/{uid}` may not contain fields itself; the subcollection holds the actual follow relationships.

**Path:** `following/{uid}/user_following/{targetUid}`

| Field | Type | Description |
|-------|------|-------------|
| `created_at` | Timestamp | When the follow relationship was created |

**Access Rules:**
- Public read
- Owner write (users manage their own following list)

---

### `followers/{uid}/user_followers/{followerUid}`

Inverse of the following collection. Maintained automatically (via backend trigger or client write) to enable efficient "who follows me" queries.

**Path:** `followers/{uid}/user_followers/{followerUid}`

| Field | Type | Description |
|-------|------|-------------|
| `created_at` | Timestamp | When the follow relationship was created |

**Access Rules:**
- Public read
- Admin write (maintained by backend triggers to stay in sync with `following`)

---

### `feed_index/{inventionId}`

Denormalized index for the discovery feed. Contains a subset of invention data optimized for fast queries with sorting and filtering. Updated when inventions are published or engagement metrics change.

**Path:** `feed_index/{inventionId}`

| Field | Type | Description |
|-------|------|-------------|
| `invention_id` | string (UUID) | Matches document ID and `inventions/{id}` |
| `creator_id` | string | Firebase UID of the inventor |
| `display_title` | string | Copied from `social_metadata.display_title` |
| `short_pitch` | string | Copied from `social_metadata.short_pitch` |
| `hero_image_url` | string or null | Copied from `social_metadata.media_assets.hero_image_url` |
| `virality_tags` | string[] | Copied from `social_metadata.virality_tags` |
| `status` | InventionStatus | Current invention status |
| `published_at` | Timestamp | When the invention was published to the feed |
| `engagement_score` | number | Composite score calculated from likes, comments, and investments |
| `view_count` | number | Total views of the invention detail page |
| `like_count` | number | Denormalized like count |
| `comment_count` | number | Denormalized comment count |
| `funding_progress` | number | `raised_usdc / goal_usdc` ratio (0.0 to 1.0) |

**Access Rules:**
- Public read (this is the feed query target)
- Admin write only

**Indexes:**
- `engagement_score` DESC (trending sort)
- `published_at` DESC (newest sort)
- `funding_progress` DESC (near-goal sort)
- Composite: `virality_tags` ARRAY_CONTAINS + `engagement_score` DESC (tag filtering)

---

### `pledges/{id}`

Phase 1 mock investment pledges. Non-binding expressions of investment interest used before real blockchain investments are enabled.

**Path:** `pledges/{pledgeId}`

| Field | Type | Description |
|-------|------|-------------|
| `pledge_id` | string (UUID) | Unique pledge identifier (matches document ID) |
| `user_id` | string | Firebase UID of the pledger |
| `invention_id` | string (UUID) | Target invention |
| `amount_usdc` | number | Pledged amount in USDC |
| `status` | string | `"PLEDGED"` (Phase 1 only supports this single state) |
| `created_at` | Timestamp | When the pledge was made |

**Access Rules:**
- Authenticated read
- Authenticated create (any signed-in user can pledge)

---

## PostgreSQL Tables (Vault)

The Vault's PostgreSQL database is the authoritative financial ledger. All monetary values use `NUMERIC(18, 6)` for precise decimal arithmetic. The schema is managed via SQL migration files in `/vault/migrations/`.

**Migration file:** `/home/user/Di-iP_Di-Fi/vault/migrations/001_initial.sql`

---

### `investments` Table

Records all blockchain-verified investment transactions. Each row corresponds to a single USDC transfer to a Crowdsale contract.

```sql
CREATE TABLE investments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invention_id    TEXT NOT NULL,
    wallet_address  TEXT NOT NULL,
    amount_usdc     NUMERIC(18, 6) NOT NULL,
    tx_hash         TEXT NOT NULL UNIQUE,
    status          investment_status NOT NULL DEFAULT 'pending',
    block_number    BIGINT,
    token_amount    NUMERIC(18, 6),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at    TIMESTAMPTZ
);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, auto-generated | Unique record identifier |
| `invention_id` | TEXT | NOT NULL | ID of the target invention |
| `wallet_address` | TEXT | NOT NULL | Investor's EVM wallet address (lowercased) |
| `amount_usdc` | NUMERIC(18,6) | NOT NULL | Investment amount in USDC (6 decimal places) |
| `tx_hash` | TEXT | NOT NULL, UNIQUE | Blockchain transaction hash (prevents duplicate recording) |
| `status` | investment_status | NOT NULL, DEFAULT 'pending' | Enum: `pending`, `confirmed`, `failed` |
| `block_number` | BIGINT | Nullable | Block number where the transaction was mined |
| `token_amount` | NUMERIC(18,6) | Nullable | RoyaltyTokens allocated (calculated by token_calculator) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the record was created |
| `confirmed_at` | TIMESTAMPTZ | Nullable | When the blockchain confirmation was received |

**Indexes:**

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_investments_invention` | `invention_id` | Fast lookup of all investments for an invention |
| `idx_investments_wallet` | `wallet_address` | Fast lookup of all investments by a wallet |
| `idx_investments_status` | `status` | Filter by confirmation status |

---

### `dividend_distributions` Table

Records each dividend distribution event. When licensing revenue is received for an invention, a distribution is created with the Merkle root that enables on-chain claims.

```sql
CREATE TABLE dividend_distributions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invention_id        TEXT NOT NULL,
    total_revenue_usdc  NUMERIC(18, 6) NOT NULL,
    merkle_root         TEXT NOT NULL,
    claim_count         INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, auto-generated | Unique distribution identifier |
| `invention_id` | TEXT | NOT NULL | Invention that generated the revenue |
| `total_revenue_usdc` | NUMERIC(18,6) | NOT NULL | Total licensing revenue being distributed |
| `merkle_root` | TEXT | NOT NULL | Root of the Merkle tree (submitted to DividendVault contract) |
| `claim_count` | INT | NOT NULL, DEFAULT 0 | Number of individual claims in this distribution |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the distribution was created |

**Indexes:**

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_distributions_invention` | `invention_id` | Lookup distributions for an invention |

---

### `dividend_claims` Table

Individual claim records within a distribution. Each row represents one token holder's share of a distribution, along with the Merkle proof needed to claim on-chain.

```sql
CREATE TABLE dividend_claims (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    distribution_id UUID NOT NULL REFERENCES dividend_distributions(id),
    wallet_address  TEXT NOT NULL,
    amount_usdc     NUMERIC(18, 6) NOT NULL,
    merkle_proof    TEXT[] NOT NULL,
    claimed         BOOLEAN NOT NULL DEFAULT FALSE,
    claim_tx_hash   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, auto-generated | Unique claim identifier |
| `distribution_id` | UUID | FK -> dividend_distributions(id), NOT NULL | Parent distribution |
| `wallet_address` | TEXT | NOT NULL | Claimant's wallet address |
| `amount_usdc` | NUMERIC(18,6) | NOT NULL | Amount owed to this holder |
| `merkle_proof` | TEXT[] | NOT NULL | Array of Merkle proof hashes for on-chain verification |
| `claimed` | BOOLEAN | NOT NULL, DEFAULT FALSE | Whether this claim has been executed on-chain |
| `claim_tx_hash` | TEXT | Nullable | Transaction hash of the on-chain claim (set when claimed) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the claim record was created |

**Indexes:**

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_claims_wallet` | `wallet_address` | Lookup all claims for a wallet |
| `idx_claims_distribution` | `distribution_id` | Lookup all claims in a distribution |
| `idx_claims_unclaimed` | `claimed` (partial: WHERE claimed = FALSE) | Efficient query for unclaimed dividends |

**Merkle Proof Format:**

The Merkle proof is stored as a PostgreSQL `TEXT[]` array. Each element is a hex-encoded 32-byte hash. The leaf encoding must match the Solidity `DividendVault.sol` contract:

```
leaf = keccak256(abi.encodePacked(keccak256(abi.encode(address, amount))))
```

This double-hashing pattern (hash-of-hash) prevents second preimage attacks on the Merkle tree.

---

### `invention_ledger` Table

Financial summary per invention. Aggregates investment totals and stores the on-chain contract addresses. Synced from Firestore and updated as investments are confirmed.

```sql
CREATE TABLE invention_ledger (
    invention_id            TEXT PRIMARY KEY,
    total_raised_usdc       NUMERIC(18, 6) NOT NULL DEFAULT 0,
    total_distributed_usdc  NUMERIC(18, 6) NOT NULL DEFAULT 0,
    backer_count            INT NOT NULL DEFAULT 0,
    nft_token_id            TEXT,
    royalty_token_address   TEXT,
    crowdsale_address       TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `invention_id` | TEXT | PK | Matches the invention's UUID across all systems |
| `total_raised_usdc` | NUMERIC(18,6) | NOT NULL, DEFAULT 0 | Sum of all confirmed investments |
| `total_distributed_usdc` | NUMERIC(18,6) | NOT NULL, DEFAULT 0 | Sum of all dividend distributions |
| `backer_count` | INT | NOT NULL, DEFAULT 0 | Number of unique investors |
| `nft_token_id` | TEXT | Nullable | IP-NFT token ID on the IPNFT contract |
| `royalty_token_address` | TEXT | Nullable | Deployed RoyaltyToken ERC-20 contract address |
| `crowdsale_address` | TEXT | Nullable | Deployed Crowdsale contract address |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the ledger entry was created |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Last update time |

---

## Cross-Service Data Flow

The following diagram shows how data flows between storage systems when key events occur.

### Investment Flow

```
1. Flutter sends POST /api/investments/:inventionId/invest
   └─> TypeScript creates Firestore doc: investments/{id} (status: PENDING)
   └─> TypeScript publishes to Pub/Sub: investment.pending

2. Vault receives investment.pending
   └─> Vault calls RPC to verify tx on-chain
   └─> Vault inserts row: PostgreSQL investments (status: confirmed)
   └─> Vault publishes to Pub/Sub: investment.confirmed

3. TypeScript receives investment.confirmed
   └─> TypeScript updates Firestore: investments/{id} (status: CONFIRMED)
   └─> TypeScript updates Firestore: inventions/{id}.funding.raised_usdc
   └─> TypeScript updates Firestore: feed_index/{id}.funding_progress
   └─> TypeScript creates Firestore: users/{uid}/notifications/{id}

4. Flutter receives real-time Firestore update
   └─> UI refreshes investment status and funding progress bar
```

### AI Analysis Flow

```
1. Flutter sends POST /api/inventions/analyze
   └─> TypeScript creates Firestore doc: inventions/{id} (status: AI_PROCESSING)
   └─> TypeScript publishes to Pub/Sub: ai.processing

2. Brain receives ai.processing
   └─> Brain calls Gemini Pro LLM for structuring
   └─> Brain calls Google Patents API for prior art
   └─> Brain publishes to Pub/Sub: ai.processing.complete

3. TypeScript receives ai.processing.complete
   └─> TypeScript updates Firestore: inventions/{id} (full schema, status: REVIEW_READY)
   └─> TypeScript creates Firestore: inventions/{id}/conversation_history/{id}
   └─> TypeScript creates Firestore: users/{uid}/notifications/{id}

4. Flutter receives real-time Firestore update
   └─> UI shows the structured patent brief for review
```

---

## Schema Mirrors

The canonical `InventionSchema.json` is mirrored in all four languages. When the schema changes, all mirrors must be updated.

| Language | File | Pattern |
|----------|------|---------|
| **JSON Schema** | `/schemas/InventionSchema.json` | JSON Schema draft-07 (authoritative) |
| **TypeScript** | `/backend/functions/src/models/types.ts` | TypeScript interfaces |
| **Python** | `/brain/src/models/invention.py` | Pydantic `BaseModel` classes |
| **Dart** | `/frontend/ideacapital/lib/models/invention.dart` | `json_serializable` annotated classes |
| **Rust** | (no direct mirror) | Uses `serde_json::Value` for flexibility |

### Field Name Mapping

All services use `snake_case` for field names to match the JSON Schema. This is consistent across:
- Firestore document fields
- PostgreSQL column names
- JSON API request/response bodies
- Pub/Sub message payloads

---

## Precision and Encoding

Financial values require careful handling across the technology stack to prevent rounding errors and ensure correctness.

### USDC Amounts

| Layer | Type | Precision | Example |
|-------|------|-----------|---------|
| **Solidity** | `uint256` | 6 decimals (USDC standard) | `1000000` = 1.00 USDC |
| **PostgreSQL** | `NUMERIC(18, 6)` | 6 decimal places | `1000.000000` |
| **Rust** | `rust_decimal::Decimal` | Arbitrary precision | `Decimal::new(1000000, 6)` |
| **TypeScript** | `number` | IEEE 754 float64 | `1000.0` (safe up to ~9 trillion USDC) |
| **Python** | `float` | IEEE 754 float64 | `1000.0` |
| **Dart** | `double` | IEEE 754 float64 | `1000.0` |

### Token Amounts

| Layer | Type | Precision | Example |
|-------|------|-----------|---------|
| **Solidity** | `uint256` | 18 decimals (ERC-20 standard) | `50000000000000000000000` = 50,000 tokens |
| **PostgreSQL** | `NUMERIC(18, 6)` | 6 decimal places | `50000.000000` |
| **Rust** | `rust_decimal::Decimal` | Arbitrary precision | |

### Wallet Addresses

Wallet addresses must be **lowercased** before any comparison or storage operation. This prevents checksum mismatches across services.

```
Input:  0xAbCdEf1234567890AbCdEf1234567890AbCdEf12
Stored: 0xabcdef1234567890abcdef1234567890abcdef12
```

### Timestamps

| Store | Format |
|-------|--------|
| **Firestore** | `FirebaseFirestore.Timestamp` (server-generated via `FieldValue.serverTimestamp()`) |
| **PostgreSQL** | `TIMESTAMPTZ` (UTC, microsecond precision) |
| **JSON APIs** | ISO 8601 string (e.g., `"2025-01-15T14:00:00.000Z"`) |

---

## Entity Relationship Summary

```
users/{uid}
  ├── notifications/{id}           (1:many)
  ├── [following/{uid}/user_following/{targetUid}]   (many:many via subcollection)
  └── [followers/{uid}/user_followers/{followerUid}] (many:many via subcollection)

inventions/{id}
  ├── comments/{id}                (1:many)
  ├── likes/{uid}                  (1:many, keyed by user)
  └── conversation_history/{id}    (1:many)

investments/{id}                   (references: inventions/{id}, users/{uid})
pledges/{id}                       (references: inventions/{id}, users/{uid})
feed_index/{inventionId}           (denormalized from: inventions/{id})

PostgreSQL (Vault):
  investments                      (references: invention_id)
  dividend_distributions           (references: invention_id)
  dividend_claims                  (references: dividend_distributions.id)
  invention_ledger                 (references: invention_id)
```
