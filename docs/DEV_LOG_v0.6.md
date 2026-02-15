# Development Log v0.6.0 (Alpha)

> **Theme:** Hardening & Real-World Readiness
> **Started:** 2026-02-01

This log tracks the chronological progress of the v0.6.0 milestone, documenting design decisions, implementations, and verification steps for each session.

---

## Session 2: Compliance Logging & Cleanup
**Date:** 2026-02-01
**Goal:** Implement audit trails for compliance and fix critical build blockers identified in the audit.

### 1. Compliance Audit Logs
- **Context:** The Arizona ABS model requires strict tracking of financial events. A "Fail Closed" logic is not enough; we need immutable proof of what happened.
- **Action:** Created `audit_logs` table (`003_audit_logs.sql`) and wired `distribute_dividends` to write to it.
- **Result:** Every `DIVIDEND_DISTRIBUTION` event now records the total revenue, net revenue, and fee count immutably.

### 2. Dependency Hygiene
- **Context:** The audit revealed "hallucinated" version numbers in `package.json` (e.g., TypeScript 5.9.3) which broke fresh installs.
- **Action:** Downgraded `typescript` and `ts-jest` to stable versions (`^5.3.3` / `^29.1.2`).
- **Result:** CI/CD pipelines will now pass `npm install`.

---

## Session 1: Infrastructure & Hardening
**Date:** 2026-02-01
**Goal:** Address P1 risks from the audit (Floating Point Math) and lay the groundwork for production infrastructure (Terraform).

### 1. Vault Math Hardening
- **Context:** The `audit_2026-02-01.md` flagged `f64` usage in `vault/src/routes/dividends.rs` as a P1 risk. Floating point errors can lead to non-compliant fee distributions.
- **Action:** Refactored `dividends.rs` to use `rust_decimal::Decimal` for all currency and percentage calculations.
- **Verification:** Updated unit tests to assert exact decimal precision.

### 2. Infrastructure Scaffolding
- **Context:** Moving from `docker-compose` (local) to Google Cloud Platform requires Infrastructure-as-Code.
- **Action:** Created `infra/terraform` with definitions for:
    -   Cloud Run (Vault, Brain, Face)
    -   Cloud SQL (PostgreSQL 16)
    -   Pub/Sub Topics & Subscriptions
    -   Artifact Registry
- **Result:** A reproducible production environment definition.

---
