// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReputationToken.sol";

/**
 * @title Governance
 * @notice Liquid Democracy system for IdeaCapital.
 * @dev Allows Reputation Token holders to vote on platform proposals.
 *      Supports "Delegation" (Liquid Democracy) where users can delegate their
 *      voting power to an expert.
 */
contract Governance is Ownable {
    ReputationToken public immutable reputationToken;

    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    // Delegation: Delegator -> Delegatee
    mapping(address => address) public delegates;

    event ProposalCreated(uint256 indexed id, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event Delegated(address indexed delegator, address indexed delegatee);

    constructor(address _reputationToken) Ownable(msg.sender) {
        reputationToken = ReputationToken(_reputationToken);
    }

    /**
     * @notice Delegate your voting power to someone else.
     */
    function delegate(address delegatee) external {
        require(delegatee != msg.sender, "Self-delegation is automatic");
        delegates[msg.sender] = delegatee;
        emit Delegated(msg.sender, delegatee);
    }

    /**
     * @notice Create a new governance proposal.
     *         Requires a minimum reputation threshold (e.g., 100 REP).
     */
    function createProposal(string memory description) external {
        require(reputationToken.balanceOf(msg.sender) >= 100 * 1e18, "Insufficient reputation");

        uint256 id = proposalCount++;
        Proposal storage p = proposals[id];
        p.description = description;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + 7 days;

        emit ProposalCreated(id, description, p.endTime);
    }

    /**
     * @notice Vote on a proposal.
     *         Voting power = Own Balance + Delegated Balance (simplified for MVP).
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp < p.endTime, "Voting ended");
        require(!p.hasVoted[msg.sender], "Already voted");

        uint256 weight = getVotingPower(msg.sender);
        require(weight > 0, "No voting power");

        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        p.hasVoted[msg.sender] = true;
        emit Voted(proposalId, msg.sender, support, weight);
    }

    /**
     * @notice Calculate effective voting power (Own + Incoming Delegations).
     * @dev MVP implementation: In a real system, we'd use checkpoints/snapshots
     *      to avoid gas loops. Here we just count own balance since reverse-lookup is hard.
     *      Real Liquid Democracy requires a more complex checkpoint system (like Compound/OZ Governor).
     *      For this MVP, we will stick to: Power = BalanceOf(User).
     *      Delegation is stored but not yet computed in this loop to save gas.
     */
    function getVotingPower(address voter) public view returns (uint256) {
        // TODO: Implement full delegation chain traversal or checkpoints
        return reputationToken.balanceOf(voter);
    }
}
