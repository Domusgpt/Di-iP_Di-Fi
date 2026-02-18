// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Marketplace
 * @notice Secondary market for trading RoyaltyTokens.
 * @dev Fixed-price listing model. Supports ERC20 (USDC) payments.
 */
contract Marketplace is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Listing {
        uint256 id;
        address seller;
        address token; // The RoyaltyToken address
        uint256 amount; // Number of tokens to sell
        uint256 price; // Total price in USDC
        bool active;
    }

    IERC20 public immutable usdc;
    uint256 public platformFeeBasisPoints = 250; // 2.5%

    uint256 public listingCount;
    mapping(uint256 => Listing) public listings;

    event ListingCreated(uint256 indexed id, address indexed seller, address indexed token, uint256 amount, uint256 price);
    event ListingSold(uint256 indexed id, address indexed buyer, uint256 price);
    event ListingCancelled(uint256 indexed id);

    constructor(address _usdc) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
    }

    /**
     * @notice Create a listing to sell RoyaltyTokens.
     * @dev Seller must approve this contract to spend their RoyaltyTokens first.
     */
    function createListing(address token, uint256 amount, uint256 price) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(price > 0, "Price must be > 0");

        // Escrow the tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 id = listingCount++;
        listings[id] = Listing(id, msg.sender, token, amount, price, true);

        emit ListingCreated(id, msg.sender, token, amount, price);
    }

    /**
     * @notice Buy a listing.
     * @dev Buyer must approve this contract to spend their USDC.
     */
    function buyListing(uint256 id) external nonReentrant {
        Listing storage listing = listings[id];
        require(listing.active, "Listing not active");

        // Calculate fee
        uint256 fee = (listing.price * platformFeeBasisPoints) / 10000;
        uint256 sellerAmount = listing.price - fee;

        // Transfer USDC from buyer
        usdc.safeTransferFrom(msg.sender, address(this), listing.price);

        // Pay seller and platform
        usdc.safeTransfer(listing.seller, sellerAmount);
        if (fee > 0) {
            usdc.safeTransfer(owner(), fee); // Send fee to platform treasury
        }

        // Transfer tokens to buyer
        IERC20(listing.token).safeTransfer(msg.sender, listing.amount);

        listing.active = false;
        emit ListingSold(id, msg.sender, listing.price);
    }

    /**
     * @notice Cancel a listing and retrieve tokens.
     */
    function cancelListing(uint256 id) external nonReentrant {
        Listing storage listing = listings[id];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not seller");

        listing.active = false;
        IERC20(listing.token).safeTransfer(msg.sender, listing.amount);

        emit ListingCancelled(id);
    }
}
