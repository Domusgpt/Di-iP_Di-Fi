---
title: "IdeaCapital: A Protocol for Decentralized Invention Capital"
version: 1.0.0
date: 2026-03-01
author: IdeaCapital Labs
---

# IdeaCapital: A Protocol for Decentralized Invention Capital

**Abstract**

Intellectual Property (IP) is the world's most valuable asset class, estimated at over $65 trillion, yet it remains fundamentally illiquid. Deep tech innovation—specifically in biotech, hardware, and energy—faces a "Valley of Death" where funding is scarce due to long time horizons and high verification costs. IdeaCapital proposes a decentralized protocol to tokenize inventions as IP-NFTs, verify their novelty using Zero-Knowledge Proofs (ZKPs), and fractionalize their future revenue streams into liquid Royalty Tokens. By combining legal engineering (Arizona ABS) with cryptographic truth, IdeaCapital aims to democratize access to early-stage deep tech investment.

---

## 1. Introduction

### 1.1 The Stagnation of Deep Tech
While software innovation has accelerated due to low marginal costs and rapid feedback loops, "hard tech" or "deep tech" innovation has stagnated. Developing a new drug, a fusion reactor, or a carbon capture device requires significant upfront capital and 5-10 years of R&D before monetization. Traditional Venture Capital (VC) models, which prioritize 10-year fund lifecycles and SaaS-like returns, are structurally ill-equipped to fund these endeavors.

### 1.2 The Liquidity Trap
For an inventor, a patent is a "negative asset"—it costs money to maintain and generates no yield until licensing or acquisition. There is no public market for early-stage IP. If an inventor needs $50,000 to build a prototype, they cannot sell 1% of their patent; they must sell equity in their entire company or take on debt.

### 1.3 The Verification Problem
Investors avoid deep tech because due diligence is prohibitively expensive. Verifying the novelty of a chemical compound or a mechanical design requires specialized expertise that generalist VCs lack.

---

## 2. The Solution: IdeaCapital Protocol

IdeaCapital is a full-stack protocol that transforms IP from a legal document into a programmable financial asset.

### 2.1 Core Components
1.  **The Vault:** A compliant financial engine for handling fiat/crypto ramping and dividend distribution.
2.  **The Brain:** An AI-driven agent that performs automated due diligence and generates Zero-Knowledge Proofs of Novelty.
3.  **The Ledger:** A set of smart contracts on the Polygon blockchain that manage ownership (IP-NFTs) and governance (Liquid Democracy).

### 2.2 The Flow
1.  **Ingest:** An inventor uploads a "Napkin Sketch" (voice, text, or image) to the platform.
2.  **Verify:** The Brain analyzes the submission against global patent databases. If novel, it generates a ZK-Proof.
3.  **Tokenize:** The invention is minted as an **IP-NFT** (ERC-721).
4.  **Fund:** The protocol launches a Crowdsale. Backers deposit USDC and receive **Royalty Tokens** (ERC-20).
5.  **Liquidate:** The funds are released to the inventor to prosecute the patent.
6.  **Distribute:** Future licensing revenue is deposited into the Vault, which automatically distributes dividends to token holders.

---

## 3. Technical Architecture

### 3.1 The Vault (Rust)
The Vault is the "Trust Layer." It is written in Rust for memory safety and concurrency.
*   **Merkle Compatibility:** It uses a custom "Double Hash" Merkle Tree (`keccak256(keccak256(abi.encode(addr, amt)))`) to ensure compatibility with Solidity's verification logic.
*   **Fail-Closed Compliance:** Before any dividend distribution, the Vault queries the `compliance_fee_splits` table. If this query fails or returns invalid data, the transaction aborts. This ensures strict adherence to legal mandates (e.g., deducting 20% for legal fees).

### 3.2 The Brain (Python & Circom)
The Brain is the "Verification Layer."
*   **AI Agent:** Uses Vertex AI (Gemini Pro) to transcribe voice notes and analyze sketches, turning unstructured data into a structured `InventionSchema`.
*   **ZKP Circuit:** A Circom 2.0 circuit (`novelty.circom`) proves that the platform knows the "Preimage" (the invention text) that corresponds to a public hash commitment, without revealing the invention itself on-chain.

### 3.3 The Ledger (Solidity)
The Ledger is the "Ownership Layer."
*   **IP-NFT:** An ERC-721 token that represents the root ownership. It integrates with **Story Protocol** to register the asset in a global IP index.
*   **Reputation Token (REP):** A Soulbound (non-transferable) ERC-20 token. It is minted to inventors and successful backers. REP is used for governance voting power.

---

## 4. Tokenomics

### 4.1 Royalty Tokens (Project-Specific)
*   **Type:** ERC-20
*   **Supply:** Fixed per invention (e.g., 1,000,000).
*   **Utility:** Claim rights on future revenue streams (dividends).
*   **Distribution:** 100% to crowdsale participants.

### 4.2 Reputation Token (Protocol-Wide)
*   **Type:** Soulbound ERC-20.
*   **Supply:** Dynamic (Mint/Burn).
*   **Utility:** Governance voting weight.
*   **Acquisition:** Earned by contributing valid IP (Inventors) or identifying prior art (Curators).

### 4.3 Fee Structure
*   **Platform Fee:** 2.5% of funds raised and dividends distributed.
*   **Legal Fee:** Variable (approx. 20-30%) paid directly to the partner law firm via the Vault's split logic.

---

## 5. Governance: Liquid Democracy

IdeaCapital utilizes a Liquid Democracy model to balance expert knowledge with decentralized control.

*   **Delegation:** Token holders can delegate their REP voting power to domain experts (e.g., "Delegate my Biotech votes to Alice").
*   **Proposal Threshold:** 100 REP required to submit a proposal.
*   **Quorum:** 10% of total active REP.

---

## 6. Legal Framework: Arizona ABS

IdeaCapital operates under the **Arizona Alternative Business Structure (ABS)** framework.
*   **Non-Lawyer Ownership:** Arizona law allows non-lawyers to hold economic interests in law firms. This is the legal "bridge" that allows token holders to effectively "own" a share of the legal work product (the patent) and its revenue.
*   **Compliance:** The Vault's software logic mirrors this legal structure, enforcing fee splits at the code level.

---

## 7. Roadmap

*   **Phase 1 (Alpha - Current):** Functional MVP on Polygon Testnet. Manual ZKP generation.
*   **Phase 2 (Beta - Q3 2026):** Mainnet launch. Automated ZKP pipeline.
*   **Phase 3 (Scale - 2027):** Secondary marketplace for Royalty Tokens. Full DAO decentralization.

---

## 8. Conclusion

IdeaCapital is not just a crowdfunding platform; it is a new financial primitive for the knowledge economy. By aligning incentives between inventors, investors, and experts, we can bridge the Valley of Death and accelerate the pace of human innovation.
