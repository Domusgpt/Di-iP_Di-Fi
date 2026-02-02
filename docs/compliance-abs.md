# Arizona ABS Compliance Module

> **Objective:** Enable IdeaCapital to operate as a compliant "Alternative Business Structure" (ABS) under Arizona Supreme Court Rule 31.1(c), allowing non-lawyers (token holders) to own equity in a firm that provides legal services (patent prosecution).

## 1. Legal Context

Traditionally, non-lawyers cannot share legal fees with lawyers (Rule 5.4). Arizona is the first US jurisdiction to abolish this rule for ABS entities.

**Requirement:**
- The platform must distinguish between "Legal Fees" (prosecution costs) and "Investment Returns" (royalties).
- Fee sharing must be explicit and tracked on-chain/in-ledger.
- A "Compliance Lawyer" must have veto power over specific ethical decisions.

## 2. Technical Implementation

### Database Schema (`vault/migrations/002_arizona_abs.sql`)

Added `fee_sharing_enabled` and `compliance_lawyer_id` to `invention_ledger`.
Added `compliance_fee_splits` table to strictly define who gets what percentage of revenue.

```sql
CREATE TABLE compliance_fee_splits (
    id UUID PRIMARY KEY,
    invention_id TEXT NOT NULL,
    recipient_type TEXT NOT NULL, -- LAWYER, PLATFORM, INVENTOR
    percentage NUMERIC(5, 2) NOT NULL
);
```

### Token Logic

When `token_calculator.rs` runs, it must check `fee_sharing_enabled`.
- **If TRUE:** Revenue distribution follows the `compliance_fee_splits` table. The `LAWYER` share is deducted *before* dividend calculation for token holders.
- **If FALSE:** Standard distribution applies (Platform Fee + Inventor Share + Investor Share).

### Governance Gate

A new API endpoint `POST /api/v1/compliance/veto` allows the assigned `compliance_lawyer_id` to pause distribution if an ethical conflict arises.

## 3. Workflow

1. **Invention Submission:** Inventor selects "Arizona ABS Track".
2. **ABS Setup:** Platform assigns a Compliance Lawyer. `fee_sharing_enabled = TRUE`.
3. **Revenue Event:** 10,000 USDC licensing fee comes in.
4. **Vault Calculation:**
   - Query `compliance_fee_splits`.
   - Lawyer (20%) -> 2,000 USDC sent to Lawyer Wallet.
   - Platform (5%) -> 500 USDC sent to Treasury.
   - Remaining (75%) -> 7,500 USDC distributed to RoyaltyToken holders via Merkle Tree.
5. **Audit:** All splits are recorded in `dividend_distributions` metadata.
