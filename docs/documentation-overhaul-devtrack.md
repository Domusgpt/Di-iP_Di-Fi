# Documentation Overhaul & Red Team Tracker

> **Objective:** Systematically critique the IdeaCapital codebase and architecture ("Red Teaming") to identify weaknesses, inconsistencies, and documentation gaps.
> **Status:** In Progress
> **Date:** March 2026

---

## 1. Red Teaming Methodology

We are evaluating the system across four vectors:
1.  **Security (SEC):** Vulnerabilities, auth bypasses, cryptographic flaws.
2.  **Scalability (SCL):** Bottlenecks, concurrency issues, database locking.
3.  **Economics (ECO):** Tokenomics sustainability, game-theory attacks.
4.  **Legal/Compliance (LEG):** Regulatory gaps, ABS structure validity.

---

## 2. Component Analysis Log

### A. The Vault (Financial Engine)
**Status:** Pending Review
-   **Target:** `dividends.rs`, `investments.rs`, `merkle.rs`
-   **Hypothesis:**
    -   Is the Double-Hash Merkle tree actually compatible with OpenZeppelin's verification?
    -   Can `distribute_dividends` be race-conditioned if called twice efficiently?
    -   Are fee splits atomic?

### B. The Brain (AI & ZKP)
**Status:** Pending Review
-   **Target:** `llm_service.py`, `zkp_service.py`
-   **Hypothesis:**
    -   Prompt Injection: Can a user trick the AI into validating a non-novel invention?
    -   ZK Soundness: Is the circuit checking the correct public signals?

### C. The Ledger (Smart Contracts)
**Status:** Pending Review
-   **Target:** `Governance.sol`, `IPNFT.sol`
-   **Hypothesis:**
    -   Flash Loan Attack: Can someone borrow REP (if transferable) or buy REP, vote, and sell? (Note: REP is Soulbound, but check `_update` logic).
    -   Centralization: Does the `owner` have too much power?

### D. The Face (Frontend)
**Status:** Pending Review
-   **Target:** `WalletProvider`, State Management
-   **Hypothesis:**
    -   Does the UI accurately reflect "Pending" vs "Confirmed" states?

---

## 3. Findings & Remediation

| ID | Component | Severity | Issue | Status | Action Item |
|----|-----------|----------|-------|--------|-------------|
| - | - | - | - | - | - |

---

## 4. Documentation Impact

Documentation must be updated to reflect the *reality* found during this exercise, not the *ideal*.
