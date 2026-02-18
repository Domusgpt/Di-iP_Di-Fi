import { expect } from "chai";
import { ethers } from "hardhat";
import { Marketplace, RoyaltyToken } from "../typechain-types";

describe("Marketplace", function () {
  let market: Marketplace;
  let usdc: RoyaltyToken;
  let royalty: RoyaltyToken;
  let owner: any;
  let seller: any;
  let buyer: any;

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners();

    // Deploy Mock USDC
    const TokenFactory = await ethers.getContractFactory("RoyaltyToken");
    usdc = await TokenFactory.deploy("USDC", "USDC", 0, ethers.parseEther("1000000"));
    await usdc.waitForDeployment();

    // Deploy Royalty Token (Asset)
    royalty = await TokenFactory.deploy("Invention A", "ROY", 1, ethers.parseEther("1000"));
    await royalty.waitForDeployment();

    // Deploy Marketplace
    const MarketFactory = await ethers.getContractFactory("Marketplace");
    market = await MarketFactory.deploy(await usdc.getAddress());
    await market.waitForDeployment();

    // Setup: Seller gets Royalty Tokens
    await royalty.mintToInvestor(seller.address, ethers.parseEther("100"));

    // Setup: Buyer gets USDC
    await usdc.mintToInvestor(buyer.address, ethers.parseEther("1000"));
  });

  describe("Listing", function () {
    it("should allow creating a listing", async function () {
      // Seller approves Market
      await royalty.connect(seller).approve(await market.getAddress(), ethers.parseEther("10"));

      await expect(
        market.connect(seller).createListing(
            await royalty.getAddress(),
            ethers.parseEther("10"),
            ethers.parseEther("50") // 50 USDC price
        )
      ).to.emit(market, "ListingCreated");

      const listing = await market.listings(0);
      expect(listing.seller).to.equal(seller.address);
      expect(listing.price).to.equal(ethers.parseEther("50"));
      expect(listing.active).to.be.true;
    });
  });

  describe("Buying", function () {
    beforeEach(async function () {
      await royalty.connect(seller).approve(await market.getAddress(), ethers.parseEther("10"));
      await market.connect(seller).createListing(await royalty.getAddress(), ethers.parseEther("10"), ethers.parseEther("50"));
    });

    it("should allow buying a listing", async function () {
      // Buyer approves Market to spend USDC
      await usdc.connect(buyer).approve(await market.getAddress(), ethers.parseEther("50"));

      await expect(
        market.connect(buyer).buyListing(0)
      ).to.emit(market, "ListingSold");

      // Verify transfers
      expect(await royalty.balanceOf(buyer.address)).to.equal(ethers.parseEther("10")); // Buyer got tokens
      // Seller got price minus fee (2.5%) -> 50 - 1.25 = 48.75
      expect(await usdc.balanceOf(seller.address)).to.equal(ethers.parseEther("48.75"));
    });
  });
});
