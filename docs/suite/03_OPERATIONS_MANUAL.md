# IdeaCapital Operations Manual

**Version 2.0 — March 2026**
**Status:** Internal Draft
**Scope:** Governance, Legal Compliance, Emergency Procedures

---

## 1. Governance Operations

The IdeaCapital DAO is governed by the `ReputationToken` (REP) and the `Governance` contract.

### 1.1 Proposal Lifecycle
1.  **Draft:** Community members discuss ideas on Discourse/Discord.
2.  **Submission:** Any REP holder with > 100 REP can submit a proposal on-chain via `createProposal(string description)`.
    *   **Cost:** Gas fee only.
    *   **Threshold:** 100 REP (prevent spam).
3.  **Voting Period:** 7 days.
    *   **Quorum:** 10% of total active REP supply required.
    *   **Approval:** Simple majority (> 50% "For").
4.  **Execution:** If passed, the proposal is executed via the `Timelock` contract (48-hour delay).

### 1.2 Delegation
*   **Purpose:** Allow passive holders to participate without constant attention.
*   **Mechanism:** Call `delegate(address expert)` on the `Governance` contract.
*   **Revocation:** Call `delegate(address(0))` or re-delegate to a new address at any time.

### 1.3 Emergency Powers
The **Guardian Council** (multisig wallet) holds veto power over malicious proposals during the Timelock delay period. This power will be dissolved as the protocol decentralizes (Progressive Decentralization).

---

## 2. Legal Compliance (Arizona ABS)

IdeaCapital operates under the **Arizona Alternative Business Structure (ABS)** framework (Rule 31).

### 2.1 Entity Formation
For each funded invention:
1.  **Form ABS:** A legal entity (LLC) is formed in Arizona.
2.  **Ownership:** The ABS is owned by:
    *   **Inventor (Manager):** Operational control.
    *   **Token Holders (Members):** Economic interest via Royalty Tokens.
    *   **Legal Partner (Non-Lawyer Owner):** Compliance oversight.

### 2.2 Fee Splitting
The Vault enforces the legal agreement at the code level.
*   **Configuration:** The `compliance_fee_splits` table in PostgreSQL defines the mandated splits.
*   **Verification:** Before any dividend distribution, the Vault verifies:
    *   `SUM(percentage) <= 100%`
    *   Legal Partner address is valid and whitelisted.
    *   Platform Fee address is correct.

### 2.3 Audit Logging
All financial actions are logged to the immutable `audit_logs` table.
*   **Retention:** Indefinite.
*   **Access:** Read-only for auditors and regulators.

---

## 3. Emergency Procedures

### 3.1 Smart Contract Pause
In the event of a critical bug or hack:
1.  **Trigger:** The Guardian Council calls `pause()` on `Pausable` contracts (Crowdsale, DividendVault).
2.  **Effect:** All deposits, withdrawals, and claims are frozen.
3.  **Resolution:** Governance must vote on a fix and upgrade the implementation via Proxy pattern (if applicable) or deploy a new version.

### 3.2 Key Rotation
If a Vault signing key is compromised:
1.  **Revocation:** The Guardian Council calls `revokeRole(VAULT_ROLE, compromised_address)`.
2.  **Rotation:** Generate a new key pair offline.
3.  **Authorization:** Governance votes to authorize the new key address.
4.  **Update:** Update the Vault service configuration with the new private key.

### 3.3 Database Recovery
PostgreSQL is backed up daily with Point-In-Time Recovery (PITR) enabled.
*   **RPO (Recovery Point Objective):** 5 minutes.
*   **RTO (Recovery Time Objective):** 1 hour.

---

## 4. Maintenance & Upgrades

### 4.1 Protocol Upgrades
*   **Smart Contracts:** Upgrades follow the UUPS Proxy pattern (where applicable). Proposed implementations must be deployed and verified on Etherscan before a governance vote.
*   **Off-Chain Services:** Deployed via CI/CD pipeline (GitHub Actions -> Google Cloud Run). Zero-downtime deployments via traffic splitting.

### 4.2 Monitoring
*   **Infrastructure:** Google Cloud Monitoring (CPU, RAM, Latency).
*   **Application:** Sentry (Error Tracking), Grafana (Business Metrics).
*   **Blockchain:** Dune Analytics dashboard for on-chain activity.

---

## 5. Contact Information

*   **Security Emergency:** security@ideacapital.app (PGP Key ID: 0xDEADBEEF)
*   **Legal Counsel:** legal@ideacapital.app
*   **General Support:** support@ideacapital.app
