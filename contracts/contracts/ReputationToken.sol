// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReputationToken (Soulbound)
 * @notice Represents "Expertise" in the IdeaCapital ecosystem.
 * @dev Non-transferable token minted to inventors and top backers.
 *      Used for weighted voting in the Governance contract.
 */
contract ReputationToken is ERC20, Ownable {
    constructor() ERC20("IdeaCapital Reputation", "REP") Ownable(msg.sender) {}

    /**
     * @notice Mint reputation points. Only callable by authorized contracts (e.g., Governance, Vault).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn reputation (slashing mechanism for bad actors).
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @notice Hook that prevents transfers (Soulbound logic).
     *         Minting and burning are allowed (from/to zero address).
     */
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            revert("ReputationToken is non-transferable");
        }
        super._update(from, to, value);
    }
}
