# The Vault — Rust Agent Specification

**The Vault** is the financial integrity layer of IdeaCapital. It verifies blockchain transactions, maintains the authoritative investment ledger in PostgreSQL, calculates token distributions, and manages dividend payouts using Merkle proofs.

---

## Technology Stack

| Component | Technology | Version |
|---|---|---|
| HTTP Framework | Axum | 0.7 |
| Database | PostgreSQL via SQLx | Latest stable |
| Blockchain Client | ethers-rs | 2 |
| Merkle Tree | Custom implementation (SHA-256) | N/A |
| Serialization | serde + serde_json | Latest stable |
| Async Runtime | Tokio | Latest stable |

---

## API Routes

All routes are prefixed with `/api/v1/vault`.

### Investment Routes

#### `POST /api/v1/vault/investments/verify`

Verifies an on-chain investment transaction and records it in the ledger.

**Request Body:**

```json
{
  "tx_hash": "0xabc123...",
  "invention_id": "invention_uuid",
  "wallet_address": "0xdef456..."
}
```

**Processing Steps:**

1. Fetch the transaction receipt from the blockchain RPC provider via ethers-rs.
2. Confirm the transaction status is successful (`status == 1`).
3. Validate that the transaction sender address matches the provided `wallet_address` (lowercased comparison).
4. Decode the `Investment` event log from the receipt to extract the USDC amount (6 decimals) and token amount (18 decimals).
5. Insert the verified investment record into the PostgreSQL `investments` table.
6. Publish an `investment.confirmed` event to Pub/Sub.

**Responses:**

- `200 OK` — Investment verified and recorded.
- `400 Bad Request` — Invalid input or transaction does not match expectations.
- `404 Not Found` — Transaction receipt not found on-chain.
- `409 Conflict` — Transaction hash already recorded (duplicate submission).

#### `GET /api/v1/vault/investments/:id`

Returns a single investment record by its internal ID.

**Response:**

```json
{
  "id": "uuid",
  "invention_id": "uuid",
  "wallet_address": "0x...",
  "amount_usdc": 1000000,
  "tx_hash": "0x...",
  "status": "confirmed",
  "block_number": 12345678,
  "token_amount": "1000000000000000000",
  "created_at": "2025-01-15T10:30:00Z",
  "confirmed_at": "2025-01-15T10:31:00Z"
}
```

#### `GET /api/v1/vault/investments/by-invention/:id`

Returns all investment records for a given invention, ordered by confirmation time.

**Response:** Array of investment objects (same shape as the single lookup).

---

### Dividend Routes

#### `POST /api/v1/vault/dividends/distribute/:invention_id`

Calculates dividend shares for all token holders and builds a Merkle tree for on-chain claim verification.

**Request Body:**

```json
{
  "total_revenue_usdc": 5000000000,
  "holder_balances": [
    { "wallet": "0xaaa...", "balance": "500000000000000000000" },
    { "wallet": "0xbbb...", "balance": "300000000000000000000" },
    { "wallet": "0xccc...", "balance": "200000000000000000000" }
  ]
}
```

**Processing Steps:**

1. Calculate each holder's proportional share of the total revenue based on their token balance relative to the sum of all balances.
2. Build a SHA-256 Merkle tree from the resulting `(wallet, amount)` leaf set.
3. Store the Merkle root and claim count in the `dividend_distributions` table.
4. Store each individual claim with its Merkle proof in the `dividend_claims` table.
5. Return the Merkle root and distribution summary.

**Response:**

```json
{
  "distribution_id": "uuid",
  "invention_id": "uuid",
  "merkle_root": "0x...",
  "claim_count": 3,
  "total_revenue_usdc": 5000000000
}
```

#### `GET /api/v1/vault/dividends/claims/:wallet`

Returns all claimable (unclaimed) dividend entries for a given wallet address.

**Response:**

```json
[
  {
    "claim_id": "uuid",
    "distribution_id": "uuid",
    "invention_id": "uuid",
    "amount_usdc": 2500000000,
    "merkle_proof": ["0x...", "0x...", "0x..."],
    "claimed": false
  }
]
```

---

## Internal Services

### `transaction_verifier`

Responsible for all on-chain transaction verification logic.

- Connects to the blockchain RPC endpoint via ethers-rs `Provider<Http>`.
- Fetches the full transaction receipt by hash.
- Validates:
  - **Status**: Receipt status must equal `1` (success).
  - **Sender**: `from` address must match the expected wallet (both lowercased before comparison).
  - **Event decoding**: Parses the `Investment` event from the receipt logs using the crowdsale contract ABI.
- Extracts:
  - `amount_usdc` — USDC transferred, using **6 decimal** precision.
  - `token_amount` — Tokens allocated, using **18 decimal** precision (ERC-20 standard).
- Returns a structured `VerifiedInvestment` that is passed to the database layer.

### `pubsub`

Handles all Pub/Sub communication for the Vault.

- **Subscribes to**: `investment.pending` — triggers the verification flow.
- **Publishes to**: `investment.confirmed` — consumed by the Face to update Firestore.
- Messages are deserialized from JSON using serde. Failed deserialization is logged and the message is nacked for retry.

### `token_calculator`

Encapsulates all proportional arithmetic for token distribution and dividend calculation.

- **Token allocation**: Given a USDC investment amount and the crowdsale token price, calculates the number of tokens to issue.
- **Dividend shares**: Given a list of `(wallet, balance)` tuples and a total revenue figure, calculates each holder's proportional payout.
- All calculations use integer arithmetic on the smallest unit to prevent floating-point rounding errors.

### `chain_watcher`

A background task that listens for on-chain events relevant to the platform.

- Runs as a long-lived Tokio task alongside the Axum server.
- Watches for `Investment` events emitted by crowdsale contracts.
- When a new event is detected, it triggers the same verification pipeline used by the `/verify` endpoint.
- Serves as a redundancy mechanism: even if the client-initiated verification request is lost, the chain watcher will eventually pick up the event.

---

## Cryptography — `merkle.rs`

The Vault implements a custom SHA-256 Merkle tree for dividend claim verification.

### Design

- **Hash function**: SHA-256.
- **Leaf construction**: Each leaf is `SHA256(abi.encodePacked(wallet_address, amount_usdc))`.
- **Internal node construction**: Child hashes are **sorted** before concatenation (`sorted pair hashing`). This ensures that proof verification is order-independent, simplifying the on-chain verifier.
- **Padding**: The leaf set is padded to the next **power of 2** by duplicating the last leaf. This guarantees a balanced tree and simplifies proof length calculations.

### Operations

| Function | Description |
|---|---|
| `build_tree(leaves)` | Accepts a list of `(wallet, amount)` pairs, hashes them into leaves, pads to a power of 2, and constructs the full Merkle tree. Returns the root hash. |
| `generate_proof(tree, leaf_index)` | Returns the sibling hashes needed to reconstruct the root from a given leaf. |
| `verify_proof(root, leaf, proof)` | Recomputes the root from the leaf and proof using sorted pair hashing, then compares against the expected root. Used primarily in tests; on-chain verification is performed by the smart contract. |

---

## PostgreSQL Schema

### `investments`

| Column | Type | Constraints |
|---|---|---|
| `id` | `UUID` | Primary key, default `gen_random_uuid()` |
| `invention_id` | `UUID` | Not null, indexed |
| `wallet_address` | `TEXT` | Not null, indexed |
| `amount_usdc` | `BIGINT` | Not null |
| `tx_hash` | `TEXT` | Not null, **UNIQUE** |
| `status` | `TEXT` | Not null, default `'pending'` |
| `block_number` | `BIGINT` | Nullable (set on confirmation) |
| `token_amount` | `NUMERIC(78, 0)` | Nullable (set on confirmation) |
| `created_at` | `TIMESTAMPTZ` | Not null, default `now()` |
| `confirmed_at` | `TIMESTAMPTZ` | Nullable |

The `UNIQUE` constraint on `tx_hash` prevents duplicate recording of the same on-chain transaction.

### `dividend_distributions`

| Column | Type | Constraints |
|---|---|---|
| `id` | `UUID` | Primary key, default `gen_random_uuid()` |
| `invention_id` | `UUID` | Not null, indexed |
| `total_revenue_usdc` | `BIGINT` | Not null |
| `merkle_root` | `TEXT` | Not null |
| `claim_count` | `INTEGER` | Not null |
| `created_at` | `TIMESTAMPTZ` | Not null, default `now()` |

### `dividend_claims`

| Column | Type | Constraints |
|---|---|---|
| `id` | `UUID` | Primary key, default `gen_random_uuid()` |
| `distribution_id` | `UUID` | Not null, foreign key to `dividend_distributions(id)` |
| `wallet_address` | `TEXT` | Not null, indexed |
| `amount_usdc` | `BIGINT` | Not null |
| `merkle_proof` | `TEXT[]` | Not null |
| `claimed` | `BOOLEAN` | Not null, default `false` |
| `claim_tx_hash` | `TEXT` | Nullable (set when claimed on-chain) |
| `created_at` | `TIMESTAMPTZ` | Not null, default `now()` |

### `invention_ledger`

| Column | Type | Constraints |
|---|---|---|
| `invention_id` | `UUID` | Primary key |
| `crowdsale_address` | `TEXT` | Not null |
| `royalty_token_address` | `TEXT` | Not null |
| `ipnft_token_id` | `BIGINT` | Not null |
| `token_supply` | `NUMERIC(78, 0)` | Not null |
| `created_at` | `TIMESTAMPTZ` | Not null, default `now()` |

This table maps each invention to its on-chain contract addresses and token identifiers, serving as the bridge between the platform's internal UUIDs and the blockchain state.
