# IdeaCapital Security Model

This document describes the security architecture of the IdeaCapital platform, covering authentication, authorization, financial integrity, and data protection.

---

## Authentication

IdeaCapital uses **Firebase Authentication** as its identity provider across all client and server surfaces.

### Client (Flutter)

- The Flutter application authenticates users via the `firebase_auth` package.
- Supported methods:
  - **Email / Password** (available now)
  - **Google OAuth** (planned)
- After sign-in the client obtains a Firebase ID token that is attached to every API request as a Bearer token.

### Server (TypeScript Backend)

- An Express middleware intercepts incoming requests and verifies the Firebase ID token using the Firebase Admin SDK.
- Requests without a valid token receive a `401 Unauthorized` response.
- The decoded token's `uid` is attached to the request context for downstream authorization checks.

### Service-to-Service (Brain and Vault)

- The Brain (Python) and Vault (Rust) agents authenticate to Firebase and Google Cloud resources using **Admin SDK credentials** or **service account keys**.
- Service accounts are provisioned with the minimum scopes required by each agent.
- No user-level tokens are exchanged between backend services; Pub/Sub message integrity is guaranteed by Google Cloud IAM.

---

## Authorization (Firestore Security Rules)

Firestore rules enforce per-collection access control. The guiding principle is **least privilege**: every collection is locked down by default, and access is opened only where explicitly required.

| Collection | Read | Create | Update | Delete |
|---|---|---|---|---|
| **Users** | Public | Owner | Owner | Owner |
| **Inventions** | Public | Authenticated (creator) | Creator only | **Denied** |
| **Comments** | Public | Authenticated | Owner only | Owner only |
| **Likes** | Public | Owner (UID-keyed docs) | Owner | Owner |
| **Notifications** | Owner only | Admin only | Admin only | Admin only |
| **Investments** | Authenticated | Admin only | Admin only | Admin only |
| **Following** | Public | Owner | Owner | Owner |
| **Followers** | Public | Admin only | Admin only | Admin only |
| **Conversation History** | Authenticated | Admin only | Admin only | Admin only |

### Key Design Decisions

- **Inventions cannot be deleted.** Once published, an invention is a permanent record. This protects investors who have committed funds against a particular invention.
- **Likes use UID-keyed documents** (`likes/{inventionId}/userLikes/{uid}`), which lets Firestore rules confirm that only the owning user can toggle their own like without requiring a Cloud Function round-trip.
- **Notifications and Investments are admin-write only.** These collections are populated exclusively by backend Cloud Functions to prevent client-side tampering with financial or notification data.
- **Followers are admin-write only.** The followers sub-collection is maintained as a server-side mirror of the following collection to ensure referential consistency.
- **Catch-all rule:** Any collection not explicitly listed above defaults to `deny` for both reads and writes.

---

## Financial Security

The Vault agent and its associated smart contracts enforce financial integrity at every stage of the investment lifecycle.

### Investment Verification

1. A user submits a USDC transaction on-chain targeting the invention's crowdsale contract.
2. The Vault fetches the **transaction receipt** from the blockchain RPC provider.
3. The Vault confirms:
   - The transaction **status** is successful (`status == 1`).
   - The **sender address** matches the expected wallet (comparison is performed on **lowercased** addresses to normalize mixed-case checksums).
   - The decoded `Investment` event log matches the expected invention and amount.
4. Only after all checks pass is the investment recorded in the PostgreSQL ledger and a `investment.confirmed` event published.

### Custodial Model

- **The platform never takes custody of user funds.** All USDC is held by the on-chain crowdsale contract.
- The crowdsale contract enforces a **funding goal** and a **deadline**.
- If the funding goal is not met before the deadline, the contract exposes a **refund mechanism** that allows investors to reclaim their USDC directly from the contract.

### Dividend Distribution

- Dividend payouts use a **Merkle tree** (SHA-256) to represent each holder's claimable amount.
- The Merkle root is stored on-chain; individual proofs are stored off-chain in PostgreSQL.
- Holders submit their Merkle proof to claim dividends. The on-chain verifier ensures each leaf can only be claimed **once**, preventing double-claiming.

---

## Data Protection

### Secrets Management

- **`.env` files are listed in `.gitignore`** and are never committed to version control.
- All private keys, API keys, and service account credentials are stored as **environment variables** (or injected via a secrets manager in production).
- No secret material appears in application source code.

### Numeric Precision

Incorrect decimal handling in financial systems can lead to rounding errors that compound over time. IdeaCapital enforces strict precision rules:

| Asset | Decimal Places | Rationale |
|---|---|---|
| USDC amounts | **6** | Matches the USDC contract's `decimals()` value. All on-chain and off-chain USDC figures use 6-decimal integer representation. |
| ERC-20 token amounts | **18** | Standard ERC-20 precision. Royalty tokens and platform tokens follow this convention. |

All arithmetic on monetary values is performed in **integer representation** (i.e., the smallest unit) to avoid floating-point errors. Conversion to human-readable format happens only at the presentation layer.
