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
**Status:** Remediated
-   **Target:** `dividends.rs`, `investments.rs`, `merkle.rs`
-   **Findings:**
    -   **Critical:** Financial calculations used `f64`, risking precision loss.
    -   **Verified:** Merkle implementation correctly uses double-hashing to match Solidity.
-   **Remediation:** Refactored entire Vault service to use `rust_decimal::Decimal`.

### B. The Brain (AI & ZKP)
**Status:** Mitigated
-   **Target:** `llm_service.py`, `zkp_service.py`
-   **Findings:**
    -   **Risk:** `zkp_service` relies on mock in local dev.
    -   **Risk:** LLM prompt injection possible but mitigated by ZKP validation of content hash.
-   **Remediation:** Enhanced ZKP mock to simulate constraint checking ("Deep Mock").

### C. The Ledger (Smart Contracts)
**Status:** Remediated
-   **Target:** `Governance.sol`, `IPNFT.sol`
-   **Findings:**
    -   **Critical:** `IPNFT` ownership allowed arbitrary changes to Story Protocol adapter.
    -   **Verified:** `ReputationToken` is correctly Soulbound (transfer reverts).
-   **Remediation:** Implemented `Timelock.sol` for governance delays. Verified security via `Security.test.ts`.

### D. The Face (Frontend)
**Status:** Remediated
-   **Target:** `WalletProvider`, `InvestScreen.dart`
-   **Findings:**
    -   **Risk:** Hardcoded contract addresses in UI code.
-   **Remediation:** Extracted configuration to `contracts.dart` using environment variables.

---

## 3. Findings & Remediation

| ID | Component | Severity | Issue | Status | Action Item |
|----|-----------|----------|-------|--------|-------------|
| 1 | Vault | P0 | Floating Point Math | **Fixed** | Refactored to `Decimal` |
| 2 | Ledger | P1 | Centralization Risk | **Fixed** | Added `Timelock.sol` |
| 3 | Ledger | P1 | Governance Attack | **Verified** | Confirmed Soulbound logic |
| 4 | Brain | P2 | ZKP Mocking | **Mitigated** | Added Deep Mock logic |
| 5 | Frontend | P2 | Hardcoded Config | **Fixed** | Extracted `ContractConfig` |

---

## 4. Documentation Impact

Documentation must be updated to reflect the *reality* found during this exercise, not the *ideal*.
