# IdeaCapital API Reference

> Complete REST API documentation for all IdeaCapital backend services.

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Error Handling](#error-handling)
4. [TypeScript Backend (Firebase Cloud Functions)](#typescript-backend)
   - [Health Check](#health-check)
   - [Inventions](#inventions)
   - [Investments](#investments)
   - [Profile](#profile)
   - [Social](#social)
5. [Brain Service (FastAPI)](#brain-service)
6. [Vault Service (Axum)](#vault-service)
   - [Investment Verification](#investment-verification)
   - [Dividend Distribution](#dividend-distribution)

---

## Overview

IdeaCapital exposes three independent API surfaces. All client traffic flows through the TypeScript backend; the Brain and Vault are internal services that communicate via Pub/Sub and direct HTTP calls from the backend.

| Service | Framework | Default Port | Base URL |
|---------|-----------|-------------|----------|
| **TypeScript Backend** | Express on Firebase Functions Gen 2 | 5001 (emulator) | `https://<region>-<project>.cloudfunctions.net/apiRouter` |
| **Brain** | FastAPI (Python) | 8081 | `http://brain:8081` |
| **Vault** | Axum (Rust) | 8080 | `http://vault:8080` |

All request and response bodies use `Content-Type: application/json`.

### Environments

| Environment | TypeScript | Brain | Vault |
|-------------|-----------|-------|-------|
| Local (Docker) | `http://localhost:5001/<project>/us-central1/apiRouter` | `http://localhost:8081` | `http://localhost:8080` |
| Production | `https://us-central1-<project>.cloudfunctions.net/apiRouter` | Internal only (Cloud Run) | Internal only (Cloud Run) |

---

## Authentication

All authenticated endpoints on the TypeScript backend require a **Firebase Auth ID token** in the `Authorization` header.

```
Authorization: Bearer <firebase-id-token>
```

### How It Works

1. The Flutter client signs in via Firebase Auth (email/password, Google Sign-In).
2. The client obtains an ID token via `FirebaseAuth.instance.currentUser.getIdToken()`.
3. The token is sent as a Bearer token with every API request.
4. The backend middleware (`auth.ts`) verifies the token using `admin.auth().verifyIdToken(token)` and attaches the decoded user (`uid`, `email`, etc.) to the request.

### Token Format

The decoded token provides these fields to the backend:

```json
{
  "uid": "abc123",
  "email": "inventor@example.com",
  "email_verified": true,
  "name": "Jane Doe",
  "iat": 1700000000,
  "exp": 1700003600
}
```

### Unauthorized Response

If the token is missing, malformed, or expired, all authenticated endpoints return:

```
HTTP 401 Unauthorized
```

```json
{
  "error": "Missing or invalid Authorization header"
}
```

or

```json
{
  "error": "Invalid or expired token"
}
```

> **Note:** The Brain and Vault services do not perform their own authentication. They are internal services accessed only by the TypeScript backend or via Pub/Sub. Network-level security (VPC, Cloud Run IAM) protects these services in production.

---

## Error Handling

All services follow a consistent error response format.

### Standard Error Response

```json
{
  "error": "Human-readable error description"
}
```

### Common Status Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `201` | Resource created |
| `202` | Accepted for async processing |
| `400` | Bad request (invalid input) |
| `401` | Unauthorized (missing or invalid token) |
| `403` | Forbidden (insufficient permissions) |
| `404` | Resource not found |
| `422` | Unprocessable entity (e.g., blockchain transaction failed) |
| `500` | Internal server error |

---

## TypeScript Backend

The TypeScript backend is the API gateway for all client-facing operations. It runs as a single Firebase Cloud Function (Gen 2) that internally routes via Express.

**Cloud Function Configuration:**
- Region: `us-central1`
- Memory: `512 MiB`
- Timeout: `120 seconds`

---

### Health Check

#### `GET /api/health`

Public endpoint. No authentication required.

**Response: `200 OK`**

```json
{
  "status": "ok",
  "service": "ideacapital-functions",
  "timestamp": "2025-01-15T10:30:00.000Z"
}
```

---

### Inventions

All invention endpoints require authentication.

---

#### `POST /api/inventions/analyze`

Submit a raw invention idea for AI analysis. Creates a draft invention in Firestore with status `AI_PROCESSING` and dispatches the idea to The Brain via the `ai.processing` Pub/Sub topic. This is an asynchronous operation; the client receives an immediate acknowledgment and is later notified via Firestore real-time updates when the AI finishes processing.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `raw_text` | string | At least one of `raw_text`, `voice_url`, or `sketch_url` | Text description of the invention idea |
| `voice_url` | string | | Firebase Storage URL of voice note |
| `sketch_url` | string | | Firebase Storage URL of sketch/diagram |

```json
{
  "raw_text": "A solar-powered backpack that charges your phone while you walk. It uses flexible panels woven into the fabric and has a built-in battery pack.",
  "voice_url": null,
  "sketch_url": "gs://ideacapital-uploads/sketches/solar-backpack-001.png"
}
```

**Response: `202 Accepted`**

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "AI_PROCESSING",
  "message": "Your idea is being analyzed. You will be notified when the draft is ready."
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | No input provided (all three fields are null/empty) |
| `401` | Not authenticated |

```json
{
  "error": "At least one input (raw_text, voice_url, sketch_url) is required"
}
```

---

#### `POST /api/inventions/:id/chat`

Continue the AI agent conversation to refine an invention. The inventor can ask questions, provide additional details, or request changes. Only the invention creator can use this endpoint. Messages are dispatched to The Brain with the `CONTINUE_CHAT` action.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | string (UUID) | Invention ID |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | string | Yes | The inventor's message to the AI agent |

```json
{
  "message": "The solar panels should be removable so the backpack can be machine washed. Can you update the hardware requirements?"
}
```

**Response: `202 Accepted`**

```json
{
  "status": "processing",
  "message": "AI is processing your response"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `401` | Not authenticated |
| `404` | Invention not found or not owned by the requesting user |

---

#### `POST /api/inventions/:id/publish`

Publish an invention to the public discovery feed. Transitions the invention status from `REVIEW_READY` to `LIVE` and emits an `invention.created` Pub/Sub event. Only the creator can publish, and the invention must be in `REVIEW_READY` status.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | string (UUID) | Invention ID |

**Request Body:** None.

**Response: `200 OK`**

```json
{
  "status": "LIVE",
  "message": "Your invention is now live on the feed!"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | Invention is not in `REVIEW_READY` status |
| `401` | Not authenticated |
| `404` | Invention not found or not owned by the requesting user |

```json
{
  "error": "Invention must be in REVIEW_READY status to publish"
}
```

---

#### `GET /api/inventions/:id`

Retrieve the full details of an invention. Returns the complete `InventionSchema` document from Firestore.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | string (UUID) | Invention ID |

**Response: `200 OK`**

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "LIVE",
  "created_at": "2025-01-15T10:30:00.000Z",
  "updated_at": "2025-01-15T12:00:00.000Z",
  "creator_id": "firebase-uid-abc123",
  "social_metadata": {
    "display_title": "SolarPack Pro",
    "short_pitch": "A solar-powered backpack that charges your phone while you walk.",
    "virality_tags": ["GreenTech", "Wearables", "Solar"],
    "media_assets": {
      "hero_image_url": "https://storage.googleapis.com/ideacapital/hero/solarpak.jpg",
      "thumbnail_url": "https://storage.googleapis.com/ideacapital/thumb/solarpak.jpg",
      "gallery": []
    }
  },
  "technical_brief": {
    "technical_field": "Portable Consumer Electronics - Solar Energy Harvesting",
    "background_problem": "Mobile devices run out of battery during outdoor activities, and existing power banks add weight without multi-functionality.",
    "solution_summary": "Flexible solar panels integrated into backpack fabric with a built-in battery management system.",
    "core_mechanics": [
      { "step": 1, "description": "Flexible solar cells woven into the top panel of the backpack" },
      { "step": 2, "description": "MPPT charge controller routes power to internal lithium battery" },
      { "step": 3, "description": "USB-C output port provides regulated 5V/3A charging" }
    ],
    "novelty_claims": [
      "Removable solar panel array for machine washing",
      "Integrated MPPT controller in backpack strap"
    ],
    "hardware_requirements": ["Flexible monocrystalline solar cells", "MPPT charge controller", "18650 lithium battery cells"],
    "software_logic": "BMS firmware monitors cell voltage and temperature, dynamically adjusting charge rate."
  },
  "risk_assessment": {
    "potential_prior_art": [
      {
        "source": "Google Patents",
        "patent_id": "US10123456B2",
        "similarity_score": 0.45,
        "notes": "Similar solar backpack but uses rigid panels, not flexible"
      }
    ],
    "feasibility_score": 7,
    "missing_info": ["Target retail price point", "Expected wattage output"]
  },
  "funding": {
    "goal_usdc": 50000,
    "raised_usdc": 12500,
    "backer_count": 23,
    "token_supply": 1000000,
    "min_investment_usdc": 10,
    "royalty_percentage": 15
  },
  "blockchain_ref": {
    "chain_id": 137,
    "nft_token_id": "42",
    "royalty_token_address": "0x1234...abcd",
    "crowdsale_address": "0x5678...ef01"
  },
  "patent_status": {
    "status": "NOT_FILED"
  }
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `401` | Not authenticated |
| `404` | Invention not found |

---

### Investments

All investment endpoints require authentication.

---

#### `POST /api/investments/:inventionId/pledge`

Record a non-binding pledge of investment intent. This is used in **Phase 1** (Social MVP) before real blockchain investments are enabled. Pledges are stored in Firestore and the invention's `funding.raised_usdc` and `funding.backer_count` are incremented optimistically.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Target invention ID |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `amount_usdc` | number | Yes | Pledged amount in USDC (must be > 0) |

```json
{
  "amount_usdc": 500
}
```

**Response: `201 Created`**

```json
{
  "pledge_id": "p1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "status": "PLEDGED"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | Invalid or missing amount |
| `401` | Not authenticated |

---

#### `POST /api/investments/:inventionId/invest`

Submit a real blockchain-backed investment. The client has already signed and broadcast a USDC transfer transaction on-chain; this endpoint records the pending investment and dispatches a verification request to The Vault via the `investment.pending` Pub/Sub topic.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Target invention ID |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `amount_usdc` | number | Yes | Investment amount in USDC |
| `wallet_address` | string | Yes | Investor's wallet address (checksummed) |
| `tx_hash` | string | Yes | Blockchain transaction hash |

```json
{
  "amount_usdc": 1000,
  "wallet_address": "0xAbCdEf1234567890AbCdEf1234567890AbCdEf12",
  "tx_hash": "0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"
}
```

**Response: `202 Accepted`**

```json
{
  "investment_id": "i1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "status": "PENDING",
  "message": "Investment submitted. Waiting for blockchain confirmation."
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | Missing required fields (`amount_usdc`, `tx_hash`, or `wallet_address`) |
| `401` | Not authenticated |

```json
{
  "error": "amount_usdc, tx_hash, and wallet_address are required"
}
```

---

#### `GET /api/investments/:inventionId/status`

Get the current funding status for an invention. Returns the funding object from the invention document along with the overall status.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Target invention ID |

**Response: `200 OK`**

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "FUNDING",
  "funding": {
    "goal_usdc": 50000,
    "raised_usdc": 12500,
    "backer_count": 23,
    "min_investment_usdc": 10,
    "royalty_percentage": 15,
    "token_supply": 1000000
  }
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `401` | Not authenticated |
| `404` | Invention not found |

---

### Profile

All profile endpoints require authentication. Operations apply to the authenticated user only.

---

#### `GET /api/profile`

Get the authenticated user's profile document.

**Response: `200 OK`**

```json
{
  "uid": "firebase-uid-abc123",
  "display_name": "Jane Inventor",
  "email": "jane@example.com",
  "avatar_url": "https://storage.googleapis.com/ideacapital/avatars/jane.jpg",
  "bio": "Hardware hacker and renewable energy enthusiast.",
  "wallet_address": "0xAbCdEf1234567890AbCdEf1234567890AbCdEf12",
  "badges": ["early_adopter", "first_invention"],
  "reputation_score": 42,
  "inventions_count": 3,
  "investments_count": 7,
  "created_at": "2025-01-01T00:00:00.000Z",
  "updated_at": "2025-01-15T12:00:00.000Z"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `401` | Not authenticated |
| `404` | Profile not found (user document does not exist in Firestore) |

---

#### `PUT /api/profile`

Update the authenticated user's profile. Only the fields listed below are accepted; any other fields in the request body are silently ignored.

**Request Body (all fields optional):**

| Field | Type | Description |
|-------|------|-------------|
| `display_name` | string | User's display name |
| `bio` | string | Short biography |
| `avatar_url` | string | URL to avatar image |
| `role` | string | User role (e.g., `inventor`, `investor`) |

```json
{
  "display_name": "Jane the Inventor",
  "bio": "Building the future, one patent at a time."
}
```

**Response: `200 OK`**

```json
{
  "status": "updated"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | No valid fields provided |
| `401` | Not authenticated |

```json
{
  "error": "No valid fields to update"
}
```

---

#### `PUT /api/profile/wallet`

Link or update the wallet address on the authenticated user's profile. This is called after the user connects their wallet via WalletConnect/Reown in the Flutter app.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `wallet_address` | string | Yes | EVM wallet address |

```json
{
  "wallet_address": "0xAbCdEf1234567890AbCdEf1234567890AbCdEf12"
}
```

**Response: `200 OK`**

```json
{
  "status": "wallet_linked"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | Missing `wallet_address` |
| `401` | Not authenticated |

---

### Social

All social endpoints require authentication. Social data lives entirely in Firestore subcollections under each invention document.

---

#### `GET /api/social/:inventionId/comments`

Get paginated comments for an invention. Comments are returned in reverse chronological order.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Invention ID |

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 20 | Number of comments to return (max 50) |
| `startAfter` | string | | Comment ID for cursor-based pagination |

**Response: `200 OK`**

```json
{
  "comments": [
    {
      "id": "c1a2b3c4-d5e6-7890-abcd-ef1234567890",
      "comment_id": "c1a2b3c4-d5e6-7890-abcd-ef1234567890",
      "user_id": "firebase-uid-xyz",
      "display_name": "Bob Investor",
      "avatar_url": "https://storage.googleapis.com/ideacapital/avatars/bob.jpg",
      "text": "This is a brilliant idea! Have you considered using perovskite solar cells?",
      "parent_id": null,
      "created_at": "2025-01-15T14:30:00.000Z",
      "like_count": 5
    }
  ],
  "hasMore": false
}
```

---

#### `POST /api/social/:inventionId/comments`

Add a comment to an invention.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Invention ID |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | Yes | Comment text (1-2000 characters) |
| `parent_id` | string | No | Parent comment ID for threaded replies |

```json
{
  "text": "Have you considered using perovskite solar cells? They are lighter and more flexible.",
  "parent_id": null
}
```

**Response: `201 Created`**

```json
{
  "comment_id": "c1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "user_id": "firebase-uid-xyz",
  "display_name": "Bob Investor",
  "avatar_url": "https://storage.googleapis.com/ideacapital/avatars/bob.jpg",
  "text": "Have you considered using perovskite solar cells? They are lighter and more flexible.",
  "parent_id": null,
  "created_at": "2025-01-15T14:30:00.000Z",
  "like_count": 0
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | Empty text or text exceeds 2000 characters |
| `401` | Not authenticated |
| `404` | Invention not found |

---

#### `DELETE /api/social/:inventionId/comments/:commentId`

Delete a comment. Users can only delete their own comments.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Invention ID |
| `commentId` | string (UUID) | Comment ID |

**Response: `200 OK`**

```json
{
  "status": "deleted"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `401` | Not authenticated |
| `403` | Attempting to delete another user's comment |
| `404` | Comment not found |

---

#### `POST /api/social/:inventionId/like`

Toggle a like on an invention. If the user has not liked the invention, a like is created. If the user has already liked it, the like is removed. The invention's `like_count` field is updated atomically.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Invention ID |

**Request Body:** None.

**Response: `200 OK`**

Like added:
```json
{
  "liked": true
}
```

Like removed:
```json
{
  "liked": false
}
```

---

#### `GET /api/social/:inventionId/like`

Check whether the authenticated user has liked a specific invention.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Invention ID |

**Response: `200 OK`**

```json
{
  "liked": true
}
```

---

#### `GET /api/social/:inventionId/like/count`

Get the total like count for an invention.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inventionId` | string (UUID) | Invention ID |

**Response: `200 OK`**

```json
{
  "count": 42
}
```

---

## Brain Service

The Brain is the AI layer of IdeaCapital. It runs as a standalone FastAPI application on port **8081**. In production, it is deployed as a Cloud Run service and is not directly accessible from clients. The TypeScript backend communicates with The Brain via Pub/Sub topics (`ai.processing` / `ai.processing.complete`). The HTTP endpoints documented below are also available for direct service-to-service calls during development.

**Base URL:** `http://brain:8081` (Docker) or `http://localhost:8081` (local dev)

---

### `GET /health`

Health check for the Brain service. No authentication required.

**Response: `200 OK`**

```json
{
  "status": "ok",
  "service": "ideacapital-brain",
  "version": "0.1.0"
}
```

---

### `POST /api/v1/brain/analyze`

Analyze a raw invention idea and produce a structured patent brief. This is the "Napkin Sketch" phase -- the AI ingests the raw idea and generates the initial `InventionSchema`-compliant structure including social metadata, technical brief, and risk assessment.

> **Note:** In production, this endpoint is triggered indirectly via the `ai.processing` Pub/Sub topic with `action: "INITIAL_ANALYSIS"`. Direct HTTP calls are used during development and testing.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string (UUID) | Yes | ID of the invention being analyzed |
| `creator_id` | string | Yes | Firebase UID of the inventor |
| `raw_text` | string | At least one input | Text description of the idea |
| `voice_url` | string | | URL to uploaded voice note |
| `sketch_url` | string | | URL to uploaded sketch/diagram |

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "creator_id": "firebase-uid-abc123",
  "raw_text": "A solar-powered backpack that charges your phone while you walk. Flexible panels woven into fabric with a built-in battery pack.",
  "voice_url": null,
  "sketch_url": "gs://ideacapital-uploads/sketches/solar-backpack-001.png"
}
```

**Response: `200 OK`**

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "REVIEW_READY",
  "social_metadata": {
    "display_title": "SolarPack Pro",
    "short_pitch": "A solar-powered backpack that charges your phone while you walk.",
    "virality_tags": ["GreenTech", "Wearables", "Solar"]
  },
  "technical_brief": {
    "technical_field": "Portable Consumer Electronics - Solar Energy Harvesting",
    "background_problem": "Mobile devices run out of battery during outdoor activities.",
    "solution_summary": "Flexible solar panels integrated into backpack fabric with built-in battery management.",
    "core_mechanics": [
      { "step": 1, "description": "Flexible solar cells woven into top panel" },
      { "step": 2, "description": "MPPT controller routes power to internal battery" },
      { "step": 3, "description": "USB-C port provides regulated charging output" }
    ],
    "novelty_claims": ["Removable solar panel array for washing"],
    "hardware_requirements": ["Flexible monocrystalline cells", "MPPT charge controller"],
    "software_logic": "BMS firmware monitors cell voltage and temperature."
  },
  "risk_assessment": {
    "potential_prior_art": [
      {
        "source": "Google Patents",
        "patent_id": "US10123456B2",
        "similarity_score": 0.45,
        "notes": "Similar concept but uses rigid panels"
      }
    ],
    "feasibility_score": 7,
    "missing_info": ["Target price point", "Expected wattage output"]
  },
  "agent_message": "I've drafted your invention summary. The concept is strong -- flexible solar integration in wearables is an active space. I flagged one similar patent but your removable panel approach appears novel. Can you clarify your target wattage output?"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | No input provided (all of `raw_text`, `voice_url`, `sketch_url` are null) |

```json
{
  "detail": "At least one input required"
}
```

---

### `POST /api/v1/brain/chat`

Continue the AI agent conversation for refining an invention. This covers Phases 2 ("Drill Down") and 3 ("Sanity Check") of the invention structuring workflow. The agent identifies gaps in the schema and asks targeted follow-up questions.

> **Note:** In production, this endpoint is triggered via the `ai.processing` Pub/Sub topic with `action: "CONTINUE_CHAT"`.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string (UUID) | Yes | Invention being refined |
| `creator_id` | string | Yes | Firebase UID of the inventor |
| `message` | string | Yes | The inventor's latest message |

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "creator_id": "firebase-uid-abc123",
  "message": "The panels should produce about 15 watts in direct sunlight. Target retail price is $149."
}
```

**Response: `200 OK`**

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "agent_message": "Great details! 15W is competitive with standalone portable panels. I've updated the hardware requirements and added pricing context. Your schema is now 85% complete. One remaining question: have you tested any specific flexible solar cell vendors?",
  "updated_fields": {
    "technical_brief.hardware_requirements": ["15W flexible monocrystalline solar array", "MPPT charge controller", "18650 lithium battery cells"],
    "funding.min_investment_usdc": 10
  },
  "schema_completeness": 85
}
```

---

## Vault Service

The Vault is the financial trust layer of IdeaCapital. It runs as a standalone Axum (Rust) application on port **8080** with a PostgreSQL database for financial record-keeping. It verifies blockchain transactions, calculates token allocations, and manages dividend distributions via Merkle trees.

**Base URL:** `http://vault:8080` (Docker) or `http://localhost:8080` (local dev)

> **Note:** The Vault does not authenticate requests itself. Access control is enforced at the network level (Cloud Run IAM, VPC). In production, only the TypeScript backend and Pub/Sub push subscriptions can reach the Vault.

---

### `GET /health`

Health check for the Vault service.

**Response: `200 OK`**

```json
{
  "status": "ok",
  "service": "ideacapital-vault",
  "version": "0.1.0"
}
```

---

### Investment Verification

---

#### `POST /api/v1/vault/investments/verify`

Verify a blockchain transaction on-chain and record the confirmed investment in PostgreSQL. The Vault reads the transaction from the blockchain via an RPC provider, verifies the amount and sender, and records the investment. On success, it publishes an `investment.confirmed` Pub/Sub event.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `invention_id` | string | Yes | Invention ID this investment targets |
| `wallet_address` | string | Yes | Investor's EVM wallet address |
| `amount_usdc` | decimal | Yes | Expected USDC amount (6 decimal precision) |
| `tx_hash` | string | Yes | On-chain transaction hash to verify |

```json
{
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "wallet_address": "0xAbCdEf1234567890AbCdEf1234567890AbCdEf12",
  "amount_usdc": 1000.000000,
  "tx_hash": "0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"
}
```

**Response: `200 OK`**

```json
{
  "id": "inv-uuid-1234-5678-abcd",
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "wallet_address": "0xabcdef1234567890abcdef1234567890abcdef12",
  "amount_usdc": "1000.000000",
  "tx_hash": "0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba",
  "status": "confirmed",
  "block_number": 48500123,
  "token_amount": "50000.000000",
  "created_at": "2025-01-15T14:00:00Z",
  "confirmed_at": "2025-01-15T14:00:05Z"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `202` | Transaction is still pending on-chain (not yet mined) |
| `400` | Transaction verification failed (invalid hash, wrong sender, etc.) |
| `422` | Transaction was mined but reverted/failed on-chain |
| `500` | Database error when recording the investment |

---

#### `GET /api/v1/vault/investments/:id`

Get a single investment record by its UUID.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | UUID | Investment record ID |

**Response: `200 OK`**

```json
{
  "id": "inv-uuid-1234-5678-abcd",
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "wallet_address": "0xabcdef1234567890abcdef1234567890abcdef12",
  "amount_usdc": "1000.000000",
  "tx_hash": "0x9876...dcba",
  "status": "confirmed",
  "block_number": 48500123,
  "token_amount": "50000.000000",
  "created_at": "2025-01-15T14:00:00Z",
  "confirmed_at": "2025-01-15T14:00:05Z"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `404` | Investment not found |
| `500` | Database error |

---

#### `GET /api/v1/vault/investments/by-invention/:invention_id`

Get all investment records for a specific invention, ordered by creation time (newest first).

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `invention_id` | string | Invention ID |

**Response: `200 OK`**

```json
[
  {
    "id": "inv-uuid-1111",
    "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "wallet_address": "0xaaa...",
    "amount_usdc": "1000.000000",
    "tx_hash": "0x111...",
    "status": "confirmed",
    "block_number": 48500123,
    "token_amount": "50000.000000",
    "created_at": "2025-01-15T14:00:00Z",
    "confirmed_at": "2025-01-15T14:00:05Z"
  },
  {
    "id": "inv-uuid-2222",
    "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "wallet_address": "0xbbb...",
    "amount_usdc": "500.000000",
    "tx_hash": "0x222...",
    "status": "confirmed",
    "block_number": 48500100,
    "token_amount": "25000.000000",
    "created_at": "2025-01-15T13:00:00Z",
    "confirmed_at": "2025-01-15T13:00:05Z"
  }
]
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `500` | Database error |

> **Note:** Returns an empty array `[]` if no investments exist for the invention. This is not an error condition.

---

### Dividend Distribution

---

#### `POST /api/v1/vault/dividends/distribute/:invention_id`

Create a new dividend distribution for an invention. Calculates each token holder's proportional share of the revenue, builds a Merkle tree for gas-efficient on-chain claims, and stores the distribution and individual claims in PostgreSQL.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `invention_id` | string | Invention ID receiving revenue |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `revenue_usdc` | number | Yes | Total licensing revenue to distribute (must be > 0) |
| `holders` | array | Yes | Token holder balances (must not be empty) |
| `holders[].wallet_address` | string | Yes | Holder's wallet address |
| `holders[].token_balance` | number | Yes | Holder's RoyaltyToken balance |

```json
{
  "revenue_usdc": 10000.00,
  "holders": [
    { "wallet_address": "0xaaa111...", "token_balance": 50000 },
    { "wallet_address": "0xbbb222...", "token_balance": 30000 },
    { "wallet_address": "0xccc333...", "token_balance": 20000 }
  ]
}
```

In this example, holder `0xaaa111...` owns 50% of tokens and receives $5,000, `0xbbb222...` owns 30% and receives $3,000, and `0xccc333...` owns 20% and receives $2,000.

**Response: `200 OK`**

```json
{
  "id": "dist-uuid-1234-5678",
  "invention_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "total_revenue_usdc": "10000.000000",
  "merkle_root": "0xabc123def456789...",
  "claim_count": 3,
  "created_at": "2025-01-20T10:00:00Z"
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `400` | Empty holders list, revenue is zero or negative, or total token supply is zero |
| `500` | Database error during distribution or claim insertion |

---

#### `GET /api/v1/vault/dividends/claims/:wallet_address`

Get all unclaimed dividend claims for a given wallet address. Returns only claims where `claimed = false`, ordered by creation time (newest first). The returned `merkle_proof` array is used by the frontend to submit an on-chain claim to the `DividendVault` smart contract.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `wallet_address` | string | EVM wallet address to query |

**Response: `200 OK`**

```json
[
  {
    "id": "claim-uuid-1111",
    "distribution_id": "dist-uuid-1234-5678",
    "wallet_address": "0xaaa111...",
    "amount_usdc": "5000.000000",
    "merkle_proof": [
      "0x1234abcd...",
      "0x5678ef01..."
    ],
    "claimed": false,
    "claim_tx_hash": null,
    "created_at": "2025-01-20T10:00:00Z"
  }
]
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| `500` | Database error |

> **Note:** Returns an empty array `[]` if the wallet has no unclaimed dividends.

---

## Appendix: Pub/Sub Message Formats

The following Pub/Sub topics carry messages between services. These are not HTTP endpoints, but are documented here for completeness since they are integral to the API contract between services.

### `ai.processing`

**Publisher:** TypeScript Backend | **Subscriber:** Brain

```json
{
  "invention_id": "uuid",
  "creator_id": "firebase-uid",
  "raw_text": "optional text",
  "voice_url": "optional url",
  "sketch_url": "optional url",
  "message": "optional (for chat continuation)",
  "action": "INITIAL_ANALYSIS | CONTINUE_CHAT"
}
```

### `ai.processing.complete`

**Publisher:** Brain | **Subscriber:** TypeScript Backend

```json
{
  "invention_id": "uuid",
  "status": "REVIEW_READY",
  "social_metadata": { "..." },
  "technical_brief": { "..." },
  "risk_assessment": { "..." },
  "agent_message": "string"
}
```

### `investment.pending`

**Publisher:** TypeScript Backend | **Subscriber:** Vault

```json
{
  "investment_id": "uuid",
  "invention_id": "uuid",
  "tx_hash": "0x...",
  "wallet_address": "0x...",
  "amount_usdc": 1000
}
```

### `investment.confirmed`

**Publisher:** Vault | **Subscriber:** TypeScript Backend

```json
{
  "investment_id": "uuid",
  "invention_id": "uuid",
  "wallet_address": "0x...",
  "amount_usdc": 1000,
  "token_amount": 50000,
  "block_number": 48500123
}
```

### `invention.created`

**Publisher:** TypeScript Backend | **Subscriber:** TypeScript Backend (Feed Indexer)

```json
{
  "invention_id": "uuid",
  "creator_id": "firebase-uid",
  "action": "PUBLISHED"
}
```
