# Smart Contracts Reference

> IdeaCapital On-Chain Layer -- Solidity 0.8.24, OpenZeppelin v5, Hardhat Toolbox

This document provides a complete reference for the four Solidity smart contracts that form the on-chain backbone of IdeaCapital. These contracts handle invention ownership (IP-NFT), fractional revenue rights (RoyaltyToken), crowdfunding (Crowdsale), and dividend distribution (DividendVault).

All contracts are located in `contracts/contracts/` and are compiled with the Solidity optimizer enabled (200 runs).

---

## Table of Contents

1. [Contract Overview](#contract-overview)
2. [IPNFT.sol](#1-ipnftsol)
3. [RoyaltyToken.sol](#2-royaltytokensol)
4. [Crowdsale.sol](#3-crowdsalesol)
5. [DividendVault.sol](#4-dividendvaultsol)
6. [Contract Interaction Diagram](#contract-interaction-diagram)
7. [Deployment Sequence](#deployment-sequence)
8. [End-to-End Lifecycle](#end-to-end-lifecycle)
9. [Network Configuration](#network-configuration)
10. [Security Considerations](#security-considerations)

---

## Contract Overview

| Contract | Standard | Purpose | Deployment |
|----------|----------|---------|------------|
| **IPNFT** | ERC-721 + URIStorage | Represents invention ownership as a non-fungible token | Once (global singleton) |
| **RoyaltyToken** | ERC-20 + Burnable | Fractional ownership of an invention's revenue stream | Once per invention |
| **Crowdsale** | Custom (Ownable) | Manages USDC investments in exchange for RoyaltyTokens | Once per invention |
| **DividendVault** | Custom (Ownable) | Gas-efficient dividend distribution using Merkle proofs | Once (global singleton) |

---

## 1. IPNFT.sol

**Source:** `contracts/contracts/IPNFT.sol`

### Purpose

IPNFT is the on-chain source of truth for invention ownership. Each funded invention receives exactly one NFT, minted when its crowdfunding goal is reached. The NFT is initially held by the platform escrow and is transferred to the legal entity representing the invention once the patent is filed.

### Inheritance Chain

```
IPNFT
  -> ERC721 (OpenZeppelin)
  -> ERC721URIStorage (OpenZeppelin)
  -> Ownable (OpenZeppelin)
```

### State Variables

| Variable | Type | Visibility | Description |
|----------|------|------------|-------------|
| `_nextTokenId` | `uint256` | `private` | Auto-incrementing token ID counter |
| `royaltyTokens` | `mapping(uint256 => address)` | `public` | Maps token ID to its associated RoyaltyToken contract address |
| `ipfsMetadata` | `mapping(uint256 => string)` | `public` | Maps token ID to its IPFS metadata CID |

### Constructor

```solidity
constructor() ERC721("IdeaCapital IP", "IPNFT") Ownable(msg.sender) {}
```

- Token name: `IdeaCapital IP`
- Token symbol: `IPNFT`
- Owner: deployer address (the platform)

### Key Functions

#### `mintInvention(address to, string memory ipfsCid, address royaltyToken) -> uint256`

Mints a new IP-NFT for a funded invention.

- **Access:** `onlyOwner` (platform only)
- **Parameters:**
  - `to` -- The inventor's address or the platform escrow address
  - `ipfsCid` -- The IPFS CID containing the invention metadata (InventionSchema JSON)
  - `royaltyToken` -- The deployed RoyaltyToken contract address for this invention
- **Returns:** The newly minted `tokenId`
- **Behavior:**
  1. Increments `_nextTokenId` and assigns the new ID
  2. Calls `_safeMint(to, tokenId)` to mint the NFT
  3. Sets the token URI to `ipfs://{ipfsCid}`
  4. Stores the royaltyToken mapping
  5. Stores the IPFS CID mapping
  6. Emits `InventionMinted`

#### `getRoyaltyToken(uint256 tokenId) -> address`

Returns the RoyaltyToken contract address associated with a given token ID. This is a convenience view function (the `royaltyTokens` mapping is also public).

#### `tokenURI(uint256 tokenId) -> string` (override)

Required override resolving the diamond between ERC721 and ERC721URIStorage. Delegates to the URIStorage implementation.

#### `supportsInterface(bytes4 interfaceId) -> bool` (override)

Required override resolving the diamond between ERC721 and ERC721URIStorage.

### Events

```solidity
event InventionMinted(
    uint256 indexed tokenId,
    address indexed creator,
    string ipfsCid,
    address royaltyToken
);
```

Emitted when a new IP-NFT is minted. The `creator` parameter is indexed for efficient filtering by inventor address.

### Access Control

- **Owner (platform):** Can mint new IP-NFTs via `mintInvention`. This is the only write operation.
- **Token holder:** Standard ERC-721 transfer capabilities (transfer, approve, etc.).
- **Public:** Can read token metadata, royalty token mappings, and IPFS CIDs.

---

## 2. RoyaltyToken.sol

**Source:** `contracts/contracts/RoyaltyToken.sol`

### Purpose

RoyaltyToken is an ERC-20 token representing fractional ownership of an invention's revenue stream. Each funded invention gets its own RoyaltyToken contract with a fixed maximum supply. Token holders receive proportional dividends from licensing revenue distributed through the DividendVault.

One RoyaltyToken contract is deployed per invention.

### Inheritance Chain

```
RoyaltyToken
  -> ERC20 (OpenZeppelin)
  -> ERC20Burnable (OpenZeppelin)
  -> Ownable (OpenZeppelin)
```

### State Variables

| Variable | Type | Visibility | Description |
|----------|------|------------|-------------|
| `ipnftTokenId` | `uint256` | `public immutable` | The associated IP-NFT token ID |
| `maxSupply` | `uint256` | `public immutable` | Maximum supply, set at deployment, cannot increase |
| `distributionFinalized` | `bool` | `public` | Whether the initial distribution is complete |

### Constructor

```solidity
constructor(
    string memory name,
    string memory symbol,
    uint256 _ipnftTokenId,
    uint256 _maxSupply
) ERC20(name, symbol) Ownable(msg.sender)
```

- **Parameters:**
  - `name` -- Human-readable token name (e.g., "SolarPaint Royalty Token")
  - `symbol` -- Token symbol (e.g., "SOLPAINT")
  - `_ipnftTokenId` -- The token ID from the IPNFT contract linking this token to its invention
  - `_maxSupply` -- The hard cap on total supply, immutable after deployment

### Key Functions

#### `mintToInvestor(address to, uint256 amount)`

Mints tokens to an investor during the crowdsale phase.

- **Access:** `onlyOwner` (Crowdsale contract)
- **Requires:**
  - `distributionFinalized` is `false`
  - `totalSupply() + amount <= maxSupply`
- **Emits:** `TokensDistributed(to, amount, "investor")`

#### `mintToInventor(address inventor, uint256 amount)`

Mints tokens to the inventor as their retained share of the invention.

- **Access:** `onlyOwner` (Crowdsale contract)
- **Requires:**
  - `distributionFinalized` is `false`
  - `totalSupply() + amount <= maxSupply`
- **Emits:** `TokensDistributed(inventor, amount, "inventor")`

#### `finalizeDistribution()`

Locks the token supply permanently. No more minting is possible after this call. This is called by the Crowdsale contract when the funding goal is reached and the crowdsale is finalized.

- **Access:** `onlyOwner`
- **Behavior:** Sets `distributionFinalized = true`
- **Emits:** `DistributionFinalized()`

### Events

```solidity
event TokensDistributed(address indexed recipient, uint256 amount, string role);
event DistributionFinalized();
```

- `TokensDistributed` -- Emitted for every mint, with a `role` string distinguishing `"investor"` from `"inventor"` allocations.
- `DistributionFinalized` -- Emitted once when the supply is locked.

### Access Control

- **Owner (Crowdsale contract):** Can mint tokens and finalize distribution. Ownership is transferred to the Crowdsale contract after deployment.
- **Token holders:** Standard ERC-20 capabilities (transfer, approve) plus ERC20Burnable `burn()` and `burnFrom()`.
- **Transfer restriction:** Transfers are not explicitly blocked before finalization in the current implementation, but the Crowdsale contract controls all minting. Secondary market trading is planned for Phase 3.

### Deployment Notes

- The `maxSupply` is immutable and represents the total number of tokens that will ever exist for this invention.
- The owner of this contract should be the Crowdsale contract, which calls `mintToInvestor` and `mintToInventor` as investments come in.
- After `finalizeDistribution()` is called, the token supply is permanently fixed.

---

## 3. Crowdsale.sol

**Source:** `contracts/contracts/Crowdsale.sol`

### Purpose

The Crowdsale contract manages the USDC-denominated crowdfunding campaign for a single invention. Investors send USDC and receive RoyaltyTokens proportionally. If the funding goal is reached, funds are released to the invention's treasury and token distribution is finalized. If the goal is not met by the deadline, investors can claim full refunds.

This contract is the one that the Rust Vault's chain watcher monitors for `Investment` events.

### Inheritance Chain

```
Crowdsale
  -> Ownable (OpenZeppelin)
```

Uses `SafeERC20` from OpenZeppelin for secure USDC transfers.

### State Variables

| Variable | Type | Visibility | Description |
|----------|------|------------|-------------|
| `usdc` | `IERC20` | `public immutable` | The USDC token contract |
| `royaltyToken` | `RoyaltyToken` | `public immutable` | The RoyaltyToken being sold |
| `goalAmount` | `uint256` | `public immutable` | Funding goal in USDC (6 decimals) |
| `minInvestment` | `uint256` | `public immutable` | Minimum investment amount in USDC |
| `deadline` | `uint256` | `public immutable` | Unix timestamp deadline (block.timestamp + durationSeconds) |
| `totalRaised` | `uint256` | `public` | Total USDC raised so far |
| `finalized` | `bool` | `public` | Whether the crowdsale has been finalized |
| `goalReached` | `bool` | `public` | Whether the funding goal was reached |
| `contributions` | `mapping(address => uint256)` | `public` | Maps investor address to their USDC contribution |
| `investorCount` | `uint256` | `public` | Number of unique investors |

### Constructor

```solidity
constructor(
    address _usdc,
    address _royaltyToken,
    uint256 _goalAmount,
    uint256 _minInvestment,
    uint256 _durationSeconds
) Ownable(msg.sender)
```

- **Parameters:**
  - `_usdc` -- Address of the USDC token contract on the target chain
  - `_royaltyToken` -- Address of the deployed RoyaltyToken contract for this invention
  - `_goalAmount` -- Funding target in USDC (6 decimal places, e.g., 50000000000 = 50,000 USDC)
  - `_minInvestment` -- Minimum per-investment amount in USDC
  - `_durationSeconds` -- Campaign duration in seconds from deployment

### Key Functions

#### `invest(uint256 amount)`

Allows any user to invest USDC in the invention.

- **Access:** Public (any address with USDC approval)
- **Requires:**
  - `block.timestamp < deadline` (campaign still active)
  - `finalized` is `false`
  - `amount >= minInvestment`
  - Caller has approved this contract to spend `amount` USDC
- **Behavior:**
  1. Transfers `amount` USDC from caller to this contract via `safeTransferFrom`
  2. Increments `investorCount` if this is the caller's first investment
  3. Adds `amount` to the caller's `contributions` and to `totalRaised`
  4. Calculates token amount: `(amount * royaltyToken.maxSupply()) / goalAmount`
  5. Mints the calculated RoyaltyTokens to the investor via `royaltyToken.mintToInvestor()`
  6. Emits `Investment(investor, amount, tokenAmount)`
  7. If `totalRaised >= goalAmount` and goal not previously reached, sets `goalReached = true` and emits `GoalReached(totalRaised)`

#### `finalize()`

Finalizes the crowdsale after the deadline or when the goal is reached.

- **Access:** `onlyOwner` (platform)
- **Requires:**
  - `block.timestamp >= deadline` OR `goalReached` is `true`
  - `finalized` is `false`
- **Behavior:**
  - If goal was reached: Transfers all USDC balance to the owner (invention treasury), then calls `royaltyToken.finalizeDistribution()` to lock the token supply.
  - If goal was not reached: Simply sets `finalized = true` to enable refunds.
  - Emits `Finalized(goalReached, totalRaised)` in both cases.

#### `refund()`

Allows investors to reclaim their USDC if the campaign failed.

- **Access:** Public (any investor)
- **Requires:**
  - `finalized` is `true`
  - `goalReached` is `false`
  - Caller has a non-zero contribution
- **Behavior:**
  1. Reads the caller's contribution amount
  2. Sets their contribution to zero (reentrancy guard pattern)
  3. Transfers the USDC back to the caller
  4. Emits `Refunded(investor, amount)`

### Events

```solidity
event Investment(address indexed investor, uint256 amount, uint256 tokenAmount);
event GoalReached(uint256 totalRaised);
event Refunded(address indexed investor, uint256 amount);
event Finalized(bool goalReached, uint256 totalRaised);
```

- `Investment` -- Emitted on every investment. This is the primary event the Vault's chain indexer watches.
- `GoalReached` -- Emitted once when cumulative investments meet or exceed the goal.
- `Refunded` -- Emitted when an investor reclaims their USDC from a failed campaign.
- `Finalized` -- Emitted when the crowdsale is finalized, reporting whether the goal was reached and the total amount raised.

### Access Control

- **Owner (platform):** Can call `finalize()` to close the campaign. Cannot modify the goal, deadline, or token price after deployment.
- **Investors (public):** Can call `invest()` during the campaign and `refund()` if it fails.
- **Critical dependency:** The Crowdsale contract must be the `owner` of the RoyaltyToken contract to mint tokens to investors.

---

## 4. DividendVault.sol

**Source:** `contracts/contracts/DividendVault.sol`

### Purpose

DividendVault handles the distribution of licensing revenue (USDC) to RoyaltyToken holders using Merkle proofs for gas-efficient on-chain claims. Instead of iterating over all token holders on-chain (which would be prohibitively expensive), the Rust Vault calculates each holder's share off-chain, constructs a Merkle tree, and posts the root on-chain. Token holders then submit a proof to claim their share.

This is the "Code is Law" dividend distribution -- trustless and verifiable.

### Inheritance Chain

```
DividendVault
  -> Ownable (OpenZeppelin)
```

Uses `SafeERC20` for secure USDC transfers and `MerkleProof` from OpenZeppelin for proof verification.

### State Variables

| Variable | Type | Visibility | Description |
|----------|------|------------|-------------|
| `usdc` | `IERC20` | `public immutable` | The USDC token contract |
| `currentEpoch` | `uint256` | `public` | Current distribution epoch counter |
| `merkleRoots` | `mapping(uint256 => bytes32)` | `public` | Merkle root for each epoch |
| `epochTotals` | `mapping(uint256 => uint256)` | `public` | Total USDC available per epoch |
| `claimed` | `mapping(uint256 => mapping(address => bool))` | `public` | Tracks whether an address has claimed for a specific epoch |

### Constructor

```solidity
constructor(address _usdc) Ownable(msg.sender)
```

- **Parameters:**
  - `_usdc` -- Address of the USDC token contract

### Key Functions

#### `createDistribution(bytes32 merkleRoot, uint256 totalAmount)`

Creates a new dividend distribution epoch.

- **Access:** `onlyOwner` (platform / Vault service)
- **Requires:**
  - `merkleRoot` is not the zero hash
  - `totalAmount > 0`
  - Caller has approved this contract to spend `totalAmount` USDC
- **Behavior:**
  1. Transfers `totalAmount` USDC from the caller into the vault via `safeTransferFrom`
  2. Increments `currentEpoch`
  3. Stores the `merkleRoot` for the new epoch
  4. Stores the `totalAmount` for the new epoch
  5. Emits `NewDistribution(currentEpoch, merkleRoot, totalAmount)`

#### `claimDividend(uint256 epoch, uint256 amount, bytes32[] calldata merkleProof)`

Allows a token holder to claim their dividend for a specific epoch by providing a valid Merkle proof.

- **Access:** Public (any address with a valid claim)
- **Requires:**
  - Caller has not already claimed for this epoch
  - The epoch has a valid (non-zero) Merkle root
  - The Merkle proof is valid against the stored root
- **Merkle Leaf Encoding:**
  ```solidity
  leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))))
  ```
  This double-hashing pattern (hash of a hash) is an OpenZeppelin convention that prevents second preimage attacks on the Merkle tree.
- **Behavior:**
  1. Computes the leaf from `msg.sender` and `amount`
  2. Verifies the proof against the epoch's Merkle root using `MerkleProof.verify()`
  3. Marks the caller as claimed for this epoch
  4. Transfers `amount` USDC to the caller
  5. Emits `DividendClaimed(epoch, claimant, amount)`

#### `hasClaimed(uint256 epoch, address account) -> bool`

View function that checks whether an address has already claimed for a specific epoch.

### Events

```solidity
event NewDistribution(uint256 indexed epoch, bytes32 merkleRoot, uint256 totalAmount);
event DividendClaimed(uint256 indexed epoch, address indexed claimant, uint256 amount);
```

- `NewDistribution` -- Emitted when a new dividend epoch is created with its Merkle root and total USDC amount.
- `DividendClaimed` -- Emitted when a token holder successfully claims their dividend.

### Access Control

- **Owner (platform / Vault):** Can create new distribution epochs via `createDistribution`. Must have pre-approved USDC spending.
- **Claimants (public):** Can call `claimDividend` with a valid Merkle proof. No other permission required.
- **Critical constraint:** The Merkle proof encoding in the Rust Vault's `merkle.rs` module MUST match the leaf encoding in this contract. The leaf format is: `keccak256(bytes.concat(keccak256(abi.encode(address, amount))))`.

---

## Contract Interaction Diagram

```
                          Platform (Owner/Deployer)
                                    |
                    ________________|________________
                   |                |                |
                   v                v                v
            +-----------+   +---------------+   +----------------+
            |   IPNFT   |   | DividendVault |   |   Per-Invention|
            | (Global)  |   |   (Global)    |   |   Deployment   |
            |           |   |               |   |                |
            | ERC-721   |   | Merkle-based  |   |  +------------+|
            | Patent    |   | USDC dividend |   |  |RoyaltyToken||
            | Ownership |   | claims        |   |  | (ERC-20)   ||
            +-----------+   +---------------+   |  +-----+------+|
                 ^                ^              |        |       |
                 |                |              |        v       |
                 |                |              |  +-----------+ |
                 |                |              |  | Crowdsale | |
                 |                |              |  | (USDC ->  | |
                 |                |              |  |  Tokens)  | |
                 |                |              |  +-----------+ |
                 |                |              +----------------+
                 |                |                    |
                 |                |                    v
                 |                |              +----------+
                 |                |              |  USDC    |
                 |                +<-------------|  (ERC-20)|
                 |                               +----------+
                 |                                    ^
                 |                                    |
            +---------+                          +---------+
            |Inventor |                          |Investors|
            +---------+                          +---------+

Relationships:
  IPNFT.royaltyTokens[tokenId]  -->  RoyaltyToken address
  Crowdsale.royaltyToken         -->  RoyaltyToken (calls mintToInvestor)
  Crowdsale.usdc                 -->  USDC contract (receives investments)
  DividendVault.usdc             -->  USDC contract (distributes dividends)
  RoyaltyToken.ipnftTokenId      -->  IPNFT token ID (back-reference)
```

---

## Deployment Sequence

The contracts are deployed in a specific order due to constructor dependencies. The deployment script is located at `contracts/scripts/deploy.ts`.

### Phase 1: Global Contracts (One-Time)

These contracts are deployed once and shared across all inventions.

```
Step 1: Deploy IPNFT
        No constructor arguments (uses msg.sender as owner).
        Record the deployed address.

Step 2: Deploy DividendVault
        Constructor argument: USDC contract address on the target chain.
        Record the deployed address.
```

### Phase 2: Per-Invention Contracts (Repeated)

These contracts are deployed each time a new invention's crowdfunding campaign begins.

```
Step 3: Deploy RoyaltyToken
        Constructor arguments:
          - name:          e.g., "SolarPaint Royalty Token"
          - symbol:        e.g., "SOLPAINT"
          - _ipnftTokenId: The IPNFT token ID (may be pre-assigned)
          - _maxSupply:    Total token supply for this invention

Step 4: Deploy Crowdsale
        Constructor arguments:
          - _usdc:             USDC contract address
          - _royaltyToken:     Address from Step 3
          - _goalAmount:       Funding goal in USDC (6 decimals)
          - _minInvestment:    Minimum investment amount
          - _durationSeconds:  Campaign duration in seconds

Step 5: Transfer RoyaltyToken ownership to the Crowdsale contract
        The Crowdsale must be the owner of the RoyaltyToken
        so it can call mintToInvestor() and mintToInventor().
```

### Post-Funding

```
Step 6: After the crowdsale goal is reached and finalized:
        - Crowdsale.finalize() releases USDC and calls
          RoyaltyToken.finalizeDistribution()
        - IPNFT.mintInvention() is called to create the patent NFT,
          linking it to the RoyaltyToken address
```

### Deployment Commands

```bash
# Compile contracts
cd contracts && npx hardhat compile

# Run tests against local Hardhat node
cd contracts && npx hardhat test

# Deploy to local Hardhat network
cd contracts && npx hardhat run scripts/deploy.ts --network hardhat

# Deploy to Polygon Mumbai testnet
cd contracts && npx hardhat run scripts/deploy.ts --network polygonMumbai

# Deploy to Polygon mainnet
cd contracts && npx hardhat run scripts/deploy.ts --network polygon

# Deploy to Base mainnet
cd contracts && npx hardhat run scripts/deploy.ts --network base
```

---

## End-to-End Lifecycle

The following describes the complete lifecycle of an invention from creation to dividend distribution, focusing on how the smart contracts participate at each stage.

### Stage 1: Invention Creation (Off-Chain)

1. Inventor submits an idea via the Flutter app (text, voice, or sketch).
2. The TypeScript backend publishes to `ai.processing` Pub/Sub topic.
3. The Python Brain structures the idea into a patent-ready brief.
4. The Brain publishes to `ai.processing.complete`.
5. The TypeScript backend updates Firestore with the structured data.
6. The inventor reviews, refines, and publishes the invention.

**No smart contracts involved at this stage.**

### Stage 2: Crowdfunding Campaign (On-Chain)

7. The platform deploys a **RoyaltyToken** contract for the invention (fixed max supply).
8. The platform deploys a **Crowdsale** contract linked to the RoyaltyToken and USDC.
9. RoyaltyToken ownership is transferred to the Crowdsale contract.
10. Investors call `Crowdsale.invest(amount)` -- USDC is transferred to the contract and RoyaltyTokens are minted proportionally.
11. The Vault's chain watcher (or the TypeScript blockchain indexer) monitors for `Investment` events and publishes `investment.confirmed` to Pub/Sub.
12. The TypeScript backend updates Firestore funding totals and sends notifications.

### Stage 3: Funding Goal Reached (On-Chain)

13. When `totalRaised >= goalAmount`, the Crowdsale emits `GoalReached`.
14. The platform calls `Crowdsale.finalize()`:
    - USDC is transferred to the invention treasury (owner).
    - `RoyaltyToken.finalizeDistribution()` is called, permanently locking the supply.
15. The platform calls `IPNFT.mintInvention()` to create the patent NFT:
    - Invention metadata is uploaded to IPFS.
    - The NFT is minted with a link to the IPFS CID and the RoyaltyToken address.

### Stage 4: Patent Filing (Off-Chain + On-Chain)

16. Legal costs are covered by the released USDC funds.
17. A patent application is filed.
18. The `patent.status.updated` Pub/Sub topic is used to track filing progress.
19. The IP-NFT may be transferred to a legal entity representing the invention.

### Stage 5: Revenue Distribution (On-Chain)

20. Licensing revenue (USDC) arrives at the platform.
21. The Rust Vault calculates each RoyaltyToken holder's proportional share.
22. The Vault builds a Merkle tree of all claims: `leaf = keccak256(bytes.concat(keccak256(abi.encode(address, amount))))`.
23. The platform calls `DividendVault.createDistribution(merkleRoot, totalAmount)`, depositing USDC into the vault.
24. Token holders call `DividendVault.claimDividend(epoch, amount, proof)` to withdraw their share.
25. Each claim is verified on-chain against the Merkle root and marked as claimed to prevent double-spending.

### Stage 6: Failed Campaign (On-Chain)

If the funding goal is not reached by the deadline:

26. The platform calls `Crowdsale.finalize()` -- no funds are released, `goalReached` remains `false`.
27. Investors call `Crowdsale.refund()` to reclaim their full USDC contribution.
28. No IP-NFT is minted. No RoyaltyToken distribution is finalized.

---

## Network Configuration

The Hardhat configuration (`contracts/hardhat.config.ts`) supports the following networks:

| Network | Chain ID | Purpose |
|---------|----------|---------|
| `hardhat` | 31337 | Local development and testing |
| `polygonMumbai` | 80001 | Testnet deployment and integration testing |
| `polygon` | 137 | Production deployment (Polygon mainnet) |
| `base` | 8453 | Alternative production deployment (Base L2) |

**Environment variables required for deployment:**

| Variable | Description |
|----------|-------------|
| `DEPLOYER_PRIVATE_KEY` | Private key of the deploying wallet |
| `RPC_URL` | JSON-RPC endpoint for the target network |
| `USDC_CONTRACT_ADDRESS` | USDC token address on the target chain |

---

## Security Considerations

### Reentrancy Protection

- The Crowdsale `refund()` function follows the checks-effects-interactions pattern: the contribution is zeroed before the USDC transfer.
- The DividendVault `claimDividend()` sets `claimed[epoch][msg.sender] = true` before transferring USDC.
- All USDC transfers use OpenZeppelin's `SafeERC20`, which handles non-standard ERC-20 return values.

### Access Control

- All administrative functions (minting, finalizing, creating distributions) are restricted to `onlyOwner`.
- The IPNFT owner is the platform. The RoyaltyToken owner is the Crowdsale contract. The DividendVault owner is the platform.
- There is no `renounceOwnership` or `transferOwnership` override, so the OpenZeppelin default behavior applies (owner can transfer ownership).

### Immutable Parameters

- `goalAmount`, `deadline`, `minInvestment` on the Crowdsale are all immutable -- they cannot be changed after deployment.
- `maxSupply` on the RoyaltyToken is immutable -- the supply cap is fixed at deployment.
- `usdc` addresses on Crowdsale and DividendVault are immutable.

### Decimal Precision

- USDC uses 6 decimal places on-chain.
- RoyaltyTokens use 18 decimal places (ERC-20 default).
- Token amount calculation in Crowdsale: `(amount * royaltyToken.maxSupply()) / goalAmount`. This integer division may result in dust amounts at the margins.

### Merkle Proof Security

- The DividendVault uses OpenZeppelin's double-hash leaf encoding (`keccak256(bytes.concat(keccak256(abi.encode(address, amount))))`) to prevent second preimage attacks.
- The Rust Vault's `merkle.rs` implementation MUST match this exact encoding. A mismatch would result in all claims being rejected and funds locked in the vault.

### Known Limitations

- The Crowdsale does not enforce a maximum raise (overfunding is possible if `totalRaised` exceeds `goalAmount`).
- RoyaltyToken transfers are not explicitly blocked before `distributionFinalized` -- enforcement relies on the Crowdsale contract controlling all minting.
- The blockchain indexer (`chain-indexer.ts`) runs on a 1-minute schedule, meaning there is up to a 60-second delay between on-chain confirmation and Firestore state update.
