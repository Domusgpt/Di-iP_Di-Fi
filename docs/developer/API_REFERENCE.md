# API Reference

This document outlines the REST API endpoints for the IdeaCapital Backend.

## 1. The Brain (Python - AI & ZKP)
**Base URL:** `http://localhost:8000`

### `POST /analyze`
**Purpose:** Phase 1 Invention Analysis.
**Request Body:**
```json
{
  "invention_id": "uuid",
  "creator_id": "uuid",
  "raw_text": "string (optional)",
  "voice_url": "url (optional)",
  "sketch_url": "url (optional)"
}
```
**Response:** `200 OK`
```json
{
  "invention_id": "uuid",
  "status": "REVIEW_READY",
  "social_metadata": { "display_title": "string" },
  "technical_brief": { "technical_field": "string" },
  "risk_assessment": { "feasibility_score": 5 }
}
```

### `POST /prove_novelty`
**Purpose:** Generate Zero-Knowledge Proof.
**Request Body:**
```json
{
  "invention_id": "uuid",
  "content": "string (preimage)"
}
```
**Response:** `200 OK`
```json
{
  "invention_id": "uuid",
  "status": "PROOF_GENERATED",
  "proof": { "pi_a": [...], "pi_b": [...], "pi_c": [...] }
}
```

---

## 2. The Vault (Rust - Financial Engine)
**Base URL:** `http://localhost:3000`

### `POST /distribute/:invention_id`
**Purpose:** Create a Dividend Distribution.
**Request Body:**
```json
{
  "revenue_usdc": 1000.0,
  "holders": [
    { "wallet_address": "0x...", "token_balance": 500.0 },
    { "wallet_address": "0x...", "token_balance": 500.0 }
  ]
}
```
**Response:** `200 OK`
```json
{
  "id": "uuid",
  "merkle_root": "0x...",
  "claim_count": 2,
  "created_at": "ISO8601"
}
```
**Error Handling:**
*   `400 Bad Request`: Invalid input or zero revenue.
*   `500 Internal Server Error`: Database failure or **Compliance Check Failed** (Fail-Closed).

### `GET /claims/:wallet_address`
**Purpose:** Fetch unclaimed dividends for a user.
**Response:** `200 OK`
```json
[
  {
    "id": "uuid",
    "distribution_id": "uuid",
    "amount_usdc": 12.50,
    "merkle_proof": ["0x...", "0x..."],
    "claimed": false
  }
]
```
