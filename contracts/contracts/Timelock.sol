// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title IdeaCapitalTimelock
 * @notice Standard OpenZeppelin TimelockController for IdeaCapital governance.
 * @dev This contract will hold ownership of sensitive contracts (IPNFT, FeeManager).
 *      It enforces a delay between proposal passing and execution.
 */
contract IdeaCapitalTimelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
