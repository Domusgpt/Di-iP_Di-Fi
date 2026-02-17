# Smart Contract Reference

This document provides the API specification for the IdeaCapital Solidity smart contracts.

## 1. Governance.sol

The **Governance** contract implements Liquid Democracy. It allows Reputation Token holders to vote on proposals.

### Inheritance
`Ownable`

### Events

*   `ProposalCreated(uint256 indexed id, string description, uint256 endTime)`
*   `Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight)`
*   `Delegated(address indexed delegator, address indexed delegatee)`

### Functions

#### `createProposal(string description)`
Creates a new governance proposal.
*   **Requires:** `balanceOf(msg.sender) >= 100 * 1e18` (100 REP).
*   **Params:**
    *   `description` - Text description of the proposal.
*   **Side Effects:** Increases `proposalCount`, emits `ProposalCreated`.

#### `vote(uint256 proposalId, bool support)`
Cast a vote on an active proposal.
*   **Requires:**
    *   Proposal must be active (`block.timestamp < endTime`).
    *   Caller must not have already voted.
*   **Params:**
    *   `proposalId` - ID of the proposal.
    *   `support` - `true` for Yes, `false` for No.
*   **Logic:**
    *   Fetches voting power via `getVotingPower(msg.sender)`.
    *   Adds weight to `votesFor` or `votesAgainst`.
    *   Marks `hasVoted[msg.sender] = true`.

#### `delegate(address delegatee)`
Delegate voting power to another address.
*   **Params:**
    *   `delegatee` - Address to receive voting power.
*   **Note:** Current MVP implementation stores delegation but `getVotingPower` does not yet traverse the chain recursively to avoid gas limits. Full implementation pending v2.

---

## 2. ReputationToken.sol

The **ReputationToken (REP)** is a Soulbound ERC-20 token used for governance.

### Inheritance
`ERC20`, `Ownable`

### Functions

#### `mint(address to, uint256 amount)`
Mints new reputation points.
*   **Access:** `onlyOwner` (Governance or Vault).

#### `burn(address from, uint256 amount)`
Burns reputation points.
*   **Access:** `onlyOwner`.

#### `_update(address from, address to, uint256 value)`
Override of ERC-20 transfer hook.
*   **Logic:** Reverts if `from != 0` and `to != 0`. This enforces the Soulbound property (non-transferable).

---

## 3. IPNFT.sol

The **IPNFT** contract represents ownership of an invention.

### Inheritance
`ERC721`, `ERC721URIStorage`, `Ownable`

### Functions

#### `mintInvention(address to, string ipfsCid, address royaltyToken)`
Mints a new IP-NFT.
*   **Access:** `onlyOwner` (Vault).
*   **Params:**
    *   `to` - Recipient address.
    *   `ipfsCid` - IPFS Content ID for metadata.
    *   `royaltyToken` - Address of the associated ERC-20 token.
*   **Side Effects:**
    *   Registers asset with **Story Protocol**.
    *   Sets Token URI to `ipfs://<cid>`.
    *   Updates internal mapping `royaltyTokens[tokenId]`.

#### `getRoyaltyToken(uint256 tokenId)`
Returns the address of the Royalty Token contract associated with the given IP-NFT ID.
