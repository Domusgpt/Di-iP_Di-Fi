// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StoryProtocolAdapter
 * @notice Adapter to register IdeaCapital IP-NFTs with Story Protocol's global IP registry.
 * @dev Mocks the interface of Story Protocol v1 core contracts.
 */
interface IPAssetRegistry {
    function register(address tokenContract, uint256 tokenId) external returns (address ipAsset);
}

contract StoryProtocolAdapter is Ownable {
    IPAssetRegistry public immutable ipAssetRegistry;

    // Mapping from IdeaCapital Token ID -> Story Protocol IP Asset Address
    mapping(address => mapping(uint256 => address)) public ipAssets;

    event IPRegistered(address indexed tokenContract, uint256 indexed tokenId, address ipAsset);

    constructor(address _ipAssetRegistry) Ownable(msg.sender) {
        ipAssetRegistry = IPAssetRegistry(_ipAssetRegistry);
    }

    /**
     * @notice Register an IdeaCapital invention as a global IP Asset.
     * @param tokenContract The IPNFT contract address.
     * @param tokenId The ID of the invention NFT.
     */
    function registerInvention(address tokenContract, uint256 tokenId) external {
        // In real Story Protocol, we might need to be the owner or approved
        // Here we just call the registry
        address ipAsset = ipAssetRegistry.register(tokenContract, tokenId);
        ipAssets[tokenContract][tokenId] = ipAsset;

        emit IPRegistered(tokenContract, tokenId, ipAsset);
    }
}
