// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./RoyaltyToken.sol";

/**
 * @title Crowdsale - Handles USDC investments for invention funding.
 * @notice Investors send USDC to this contract and receive RoyaltyTokens in return.
 *
 * @dev Flow:
 *      1. Inventor deploys Crowdsale with funding goal and deadline.
 *      2. Investors call `invest(amount)` with USDC.
 *      3. If goal is reached by deadline → funds released, tokens distributed.
 *      4. If goal not reached → investors can call `refund()` to get USDC back.
 *
 *      This is the contract The Vault (Rust) watches for `Investment` events.
 */
contract Crowdsale is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The USDC token contract.
    IERC20 public immutable usdc;

    /// @notice The RoyaltyToken being sold.
    RoyaltyToken public immutable royaltyToken;

    /// @notice Funding goal in USDC (6 decimals).
    uint256 public immutable goalAmount;

    /// @notice Minimum investment amount.
    uint256 public immutable minInvestment;

    /// @notice Deadline timestamp.
    uint256 public immutable deadline;

    /// @notice Total USDC raised so far.
    uint256 public totalRaised;

    /// @notice Whether the crowdsale has been finalized.
    bool public finalized;

    /// @notice Whether the goal was reached.
    bool public goalReached;

    /// @notice Maps investor address to their USDC contribution.
    mapping(address => uint256) public contributions;

    /// @notice Number of unique investors.
    uint256 public investorCount;

    // Events watched by The Vault's chain indexer
    event Investment(
        address indexed investor,
        uint256 amount,
        uint256 tokenAmount
    );
    event GoalReached(uint256 totalRaised);
    event Refunded(address indexed investor, uint256 amount);
    event Finalized(bool goalReached, uint256 totalRaised);

    constructor(
        address _usdc,
        address _royaltyToken,
        uint256 _goalAmount,
        uint256 _minInvestment,
        uint256 _durationSeconds
    ) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        royaltyToken = RoyaltyToken(_royaltyToken);
        goalAmount = _goalAmount;
        minInvestment = _minInvestment;
        deadline = block.timestamp + _durationSeconds;
    }

    /**
     * @notice Invest USDC in this invention.
     * @param amount The USDC amount (6 decimals).
     */
    function invest(uint256 amount) external {
        require(block.timestamp < deadline, "Crowdsale ended");
        require(!finalized, "Crowdsale finalized");
        require(amount >= minInvestment, "Below minimum investment");

        // Transfer USDC from investor to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        if (contributions[msg.sender] == 0) {
            investorCount++;
        }

        contributions[msg.sender] += amount;
        totalRaised += amount;

        // Calculate royalty tokens: (amount / goalAmount) * royaltyToken.maxSupply()
        uint256 tokenAmount = (amount * royaltyToken.maxSupply()) / goalAmount;

        // Mint royalty tokens to investor
        royaltyToken.mintToInvestor(msg.sender, tokenAmount);

        emit Investment(msg.sender, amount, tokenAmount);

        if (totalRaised >= goalAmount && !goalReached) {
            goalReached = true;
            emit GoalReached(totalRaised);
        }
    }

    /**
     * @notice Finalize the crowdsale after the deadline.
     * @dev If goal reached: release funds to inventor.
     *      If goal not reached: enable refunds.
     */
    function finalize() external onlyOwner {
        require(
            block.timestamp >= deadline || goalReached,
            "Crowdsale still active"
        );
        require(!finalized, "Already finalized");

        finalized = true;

        if (goalReached) {
            // Release funds to the invention's treasury (owner)
            uint256 balance = usdc.balanceOf(address(this));
            usdc.safeTransfer(owner(), balance);
            royaltyToken.finalizeDistribution();
        }

        emit Finalized(goalReached, totalRaised);
    }

    /**
     * @notice Claim a refund if the crowdsale failed.
     */
    function refund() external {
        require(finalized, "Not finalized yet");
        require(!goalReached, "Goal was reached, no refunds");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution to refund");

        contributions[msg.sender] = 0;
        usdc.safeTransfer(msg.sender, amount);

        emit Refunded(msg.sender, amount);
    }
}
