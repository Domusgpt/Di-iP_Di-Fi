# IdeaCapital: Operations & Compliance Manual

> **Scope:** Legal Compliance, Governance, and Deployment Procedures.

This document outlines the operational protocols required to run IdeaCapital in a compliant and secure manner.

## 1. Arizona ABS Compliance

IdeaCapital operates under the **Arizona Alternative Business Structure (ABS)** framework, which allows non-lawyers to hold economic interests in law firms or legal service entities. This is critical for tokenizing IP, as patent prosecution is a legal service.

### The "Fail-Closed" Rule
The Vault's financial engine enforces strict compliance by failing closed. If the system cannot guarantee that mandatory legal fees (to the partner law firm) are deducted, **no dividends are distributed.**

**Implementation:**
1.  **Fee Table:** The `compliance_fee_splits` table in PostgreSQL defines the mandatory recipients (Lawyer, Platform, Inventor).
2.  **Atomic Transaction:** The `distribute_dividends` function in `dividends.rs` queries this table *before* calculating investor shares.
3.  **Abort Condition:** If the query fails, returns 0 rows, or if the fee calculation errors, the entire HTTP request returns `500 Internal Server Error` and rolls back. This prevents "accidental non-compliance."

### Audit Trail
Every distribution event generates an immutable record in the `audit_logs` table.
*   **Payload:** Includes `total_revenue`, `net_revenue`, `fee_splits` (with recipients), and `merkle_root`.
*   **Retention:** Logs are never deleted.

---

## 2. Decentralized Governance

IdeaCapital uses a **Liquid Democracy** model powered by the **Reputation Token (REP)**.

### Reputation Token (REP)
*   **Soulbound:** REP tokens are non-transferable (except to burn/mint by the protocol).
*   **Earned:** Users earn REP by contributing valid IP, identifying prior art (curation), or participating in governance.
*   **Weight:** Voting power is proportional to REP balance.

### Voting Process
1.  **Proposal:** Any user with >100 REP can submit a proposal (e.g., "Change Platform Fee to 2.5%").
2.  **Delegation:** Users can delegate their voting power to a domain expert (e.g., "Delegate to @BioTechExpert for all Bio-related votes").
3.  **Vote:** Proposals pass with a simple majority of participating REP, subject to a quorum.
4.  **Execution:** Successful proposals trigger a timelock contract to execute the change on-chain (future feature).

---

## 3. Deployment & Infrastructure

The platform is deployed on **Google Cloud Platform (GCP)** using Terraform.

### Prerequisites
*   Google Cloud SDK (`gcloud`)
*   Terraform
*   Docker

### Environment Variables
The following variables must be set in the production environment (e.g., GitHub Secrets or Google Secret Manager):

| Variable | Description |
| :--- | :--- |
| `WALLETCONNECT_PROJECT_ID` | Project ID from WalletConnect Cloud. |
| `POLYGON_RPC_URL` | HTTP endpoint for Polygon node (Alchemy/Infura). |
| `PRIVATE_KEY` | Private key for the deployer wallet (do not commit!). |
| `DATABASE_URL` | PostgreSQL connection string. |
| `OPENAI_API_KEY` | (Optional) For fallback LLM services. |
| `VERTEX_PROJECT_ID` | GCP Project ID for Vertex AI. |

### Deployment Steps

**1. Infrastructure (Terraform)**
```bash
cd infra/terraform
terraform init
terraform apply -var="project_id=ideacapital-prod"
```

**2. Database Migrations (Rust)**
```bash
cd vault
sqlx migrate run
```

**3. Services (Docker)**
```bash
# Build and push images
gcloud builds submit --tag gcr.io/ideacapital/vault ./vault
gcloud builds submit --tag gcr.io/ideacapital/brain ./brain

# Deploy to Cloud Run
gcloud run deploy vault --image gcr.io/ideacapital/vault --platform managed
gcloud run deploy brain --image gcr.io/ideacapital/brain --platform managed
```

**4. Smart Contracts (Hardhat)**
```bash
cd contracts
npx hardhat run scripts/deploy_amoy.ts --network amoy
```
