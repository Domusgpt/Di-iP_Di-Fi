import { expect } from "chai";
import { ethers } from "hardhat";
import { IPNFT } from "../typechain-types";

describe("IPNFT", function () {
  let ipnft: IPNFT;
  let owner: any;
  let inventor: any;

  let storyAdapter: any;

  beforeEach(async function () {
    [owner, inventor] = await ethers.getSigners();

    // Deploy Mock Story Adapter
    const StoryFactory = await ethers.getContractFactory("StoryProtocolAdapter");
    // Pass zero address for registry since we are mocking/testing the adapter itself
    // In a real integration test we'd mock the registry too
    storyAdapter = await StoryFactory.deploy(ethers.ZeroAddress);
    await storyAdapter.waitForDeployment();

    const IPNFT_Factory = await ethers.getContractFactory("IPNFT");
    ipnft = await IPNFT_Factory.deploy(await storyAdapter.getAddress());
    await ipnft.waitForDeployment();
  });

  describe("Minting", function () {
    it("should mint an IP-NFT to the inventor", async function () {
      const ipfsCid = "QmTestCID123";
      const royaltyToken = ethers.ZeroAddress; // Mock for this test

      const tx = await ipnft.mintInvention(inventor.address, ipfsCid, royaltyToken);
      await tx.wait();

      expect(await ipnft.ownerOf(0)).to.equal(inventor.address);
      expect(await ipnft.ipfsMetadata(0)).to.equal(ipfsCid);
      expect(await ipnft.royaltyTokens(0)).to.equal(royaltyToken);
    });

    it("should emit InventionMinted event", async function () {
      const ipfsCid = "QmTestCID456";
      const royaltyToken = ethers.ZeroAddress;

      await expect(ipnft.mintInvention(inventor.address, ipfsCid, royaltyToken))
        .to.emit(ipnft, "InventionMinted")
        .withArgs(0, inventor.address, ipfsCid, royaltyToken);
    });

    it("should increment token IDs", async function () {
      await ipnft.mintInvention(inventor.address, "CID1", ethers.ZeroAddress);
      await ipnft.mintInvention(inventor.address, "CID2", ethers.ZeroAddress);

      expect(await ipnft.ownerOf(0)).to.equal(inventor.address);
      expect(await ipnft.ownerOf(1)).to.equal(inventor.address);
    });

    it("should only allow owner to mint", async function () {
      await expect(
        ipnft.connect(inventor).mintInvention(inventor.address, "CID", ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(ipnft, "OwnableUnauthorizedAccount");
    });
  });

  describe("Token URI", function () {
    it("should return ipfs:// URI", async function () {
      const ipfsCid = "QmTestCID789";
      await ipnft.mintInvention(inventor.address, ipfsCid, ethers.ZeroAddress);

      const uri = await ipnft.tokenURI(0);
      expect(uri).to.equal(`ipfs://${ipfsCid}`);
    });
  });
});
