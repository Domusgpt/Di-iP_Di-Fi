// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IPNFT - Intellectual Property NFT
 * @notice Represents ownership of a patent/invention on IdeaCapital.
 * @dev Each invention gets ONE NFT minted when its crowdfunding goal is reached.
 *      The NFT is held by the platform's escrow until the patent is filed,
 *      then transferred to the legal entity representing the invention.
 *
 *      This is the "Source of Truth" for invention ownership on-chain.
 */
contract IPNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    /// @notice Maps token ID to its associated RoyaltyToken contract address.
    mapping(uint256 => address) public royaltyTokens;

    /// @notice Maps token ID to its IPFS metadata CID.
    mapping(uint256 => string) public ipfsMetadata;

    event InventionMinted(
        uint256 indexed tokenId,
        address indexed creator,
        string ipfsCid,
        address royaltyToken
    );

    constructor() ERC721("IdeaCapital IP", "IPNFT") Ownable(msg.sender) {}

    /**
     * @notice Mint a new IP-NFT for a funded invention.
     * @param to The inventor's address (or escrow).
     * @param ipfsCid The IPFS CID containing the invention metadata.
     * @param royaltyToken The deployed RoyaltyToken contract for this invention.
     * @return tokenId The newly minted token ID.
     */
    function mintInvention(
        address to,
        string memory ipfsCid,
        address royaltyToken
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked("ipfs://", ipfsCid)));

        royaltyTokens[tokenId] = royaltyToken;
        ipfsMetadata[tokenId] = ipfsCid;

        emit InventionMinted(tokenId, to, ipfsCid, royaltyToken);
        return tokenId;
    }

    /**
     * @notice Get the RoyaltyToken contract address for an invention.
     */
    function getRoyaltyToken(uint256 tokenId) external view returns (address) {
        return royaltyTokens[tokenId];
    }

    // Required overrides
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
