// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RoyaltyToken - ERC20 representing ownership shares of an invention.
 * @notice Each funded invention gets its own RoyaltyToken contract.
 *         Token holders receive proportional dividends from licensing revenue.
 *
 * @dev Token distribution:
 *      - Investors receive tokens proportional to their USDC contribution
 *      - The inventor retains a configured percentage
 *      - The platform takes a small operational fee
 *
 *      These tokens are tradeable on the secondary market (Phase 3).
 */
contract RoyaltyToken is ERC20, ERC20Burnable, Ownable {
    /// @notice The associated IP-NFT token ID.
    uint256 public immutable ipnftTokenId;

    /// @notice Maximum supply (set at deployment, cannot increase).
    uint256 public immutable maxSupply;

    /// @notice Whether the initial distribution is complete.
    bool public distributionFinalized;

    event TokensDistributed(address indexed recipient, uint256 amount, string role);
    event DistributionFinalized();

    constructor(
        string memory name,
        string memory symbol,
        uint256 _ipnftTokenId,
        uint256 _maxSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        ipnftTokenId = _ipnftTokenId;
        maxSupply = _maxSupply;
    }

    /**
     * @notice Mint tokens to an investor during the crowdsale.
     * @param to The investor's wallet address.
     * @param amount The number of tokens to mint.
     */
    function mintToInvestor(address to, uint256 amount) external onlyOwner {
        require(!distributionFinalized, "Distribution is finalized");
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");

        _mint(to, amount);
        emit TokensDistributed(to, amount, "investor");
    }

    /**
     * @notice Mint tokens to the inventor (their retained share).
     * @param inventor The inventor's wallet address.
     * @param amount The number of tokens to mint.
     */
    function mintToInventor(address inventor, uint256 amount) external onlyOwner {
        require(!distributionFinalized, "Distribution is finalized");
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");

        _mint(inventor, amount);
        emit TokensDistributed(inventor, amount, "inventor");
    }

    /**
     * @notice Finalize the token distribution. No more minting after this.
     */
    function finalizeDistribution() external onlyOwner {
        distributionFinalized = true;
        emit DistributionFinalized();
    }
}
