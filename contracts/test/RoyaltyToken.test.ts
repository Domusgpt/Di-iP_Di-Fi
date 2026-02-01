import { expect } from "chai";
import { ethers } from "hardhat";
import { RoyaltyToken } from "../typechain-types";

describe("RoyaltyToken", function () {
  let token: RoyaltyToken;
  let owner: any;
  let inventor: any;
  let investor1: any;
  let investor2: any;

  const MAX_SUPPLY = ethers.parseUnits("1000000", 18);
  const IPNFT_TOKEN_ID = 42;

  beforeEach(async function () {
    [owner, inventor, investor1, investor2] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("RoyaltyToken");
    token = await Factory.deploy(
      "Gutter Drone Royalty",
      "GDR",
      IPNFT_TOKEN_ID,
      MAX_SUPPLY,
    );
    await token.waitForDeployment();
  });

  describe("Deployment", function () {
    it("should set correct name and symbol", async function () {
      expect(await token.name()).to.equal("Gutter Drone Royalty");
      expect(await token.symbol()).to.equal("GDR");
    });

    it("should set max supply and IPNFT token ID", async function () {
      expect(await token.maxSupply()).to.equal(MAX_SUPPLY);
      expect(await token.ipnftTokenId()).to.equal(IPNFT_TOKEN_ID);
    });

    it("should start with zero total supply", async function () {
      expect(await token.totalSupply()).to.equal(0);
    });

    it("should not be finalized initially", async function () {
      expect(await token.distributionFinalized()).to.equal(false);
    });
  });

  describe("Minting", function () {
    it("should mint tokens to investor", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await expect(token.mintToInvestor(investor1.address, amount))
        .to.emit(token, "TokensDistributed")
        .withArgs(investor1.address, amount, "investor");

      expect(await token.balanceOf(investor1.address)).to.equal(amount);
    });

    it("should mint tokens to inventor", async function () {
      const amount = ethers.parseUnits("200000", 18);
      await expect(token.mintToInventor(inventor.address, amount))
        .to.emit(token, "TokensDistributed")
        .withArgs(inventor.address, amount, "inventor");

      expect(await token.balanceOf(inventor.address)).to.equal(amount);
    });

    it("should not exceed max supply", async function () {
      const overSupply = MAX_SUPPLY + 1n;
      await expect(token.mintToInvestor(investor1.address, overSupply))
        .to.be.revertedWith("Exceeds max supply");
    });

    it("should not exceed max supply across multiple mints", async function () {
      await token.mintToInvestor(investor1.address, MAX_SUPPLY - 1n);
      await expect(token.mintToInvestor(investor2.address, 2n))
        .to.be.revertedWith("Exceeds max supply");
    });

    it("should only allow owner to mint", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await expect(token.connect(investor1).mintToInvestor(investor1.address, amount))
        .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
    });
  });

  describe("Distribution Finalization", function () {
    it("should finalize distribution", async function () {
      await expect(token.finalizeDistribution())
        .to.emit(token, "DistributionFinalized");

      expect(await token.distributionFinalized()).to.equal(true);
    });

    it("should prevent minting after finalization", async function () {
      await token.finalizeDistribution();

      await expect(token.mintToInvestor(investor1.address, 1000n))
        .to.be.revertedWith("Distribution is finalized");

      await expect(token.mintToInventor(inventor.address, 1000n))
        .to.be.revertedWith("Distribution is finalized");
    });

    it("should only allow owner to finalize", async function () {
      await expect(token.connect(investor1).finalizeDistribution())
        .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
    });
  });

  describe("ERC20 Transfers", function () {
    it("should allow token transfers between holders", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await token.mintToInvestor(investor1.address, amount);

      const transferAmount = ethers.parseUnits("500", 18);
      await token.connect(investor1).transfer(investor2.address, transferAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(amount - transferAmount);
      expect(await token.balanceOf(investor2.address)).to.equal(transferAmount);
    });

    it("should allow burning tokens", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await token.mintToInvestor(investor1.address, amount);

      const burnAmount = ethers.parseUnits("300", 18);
      await token.connect(investor1).burn(burnAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(amount - burnAmount);
      expect(await token.totalSupply()).to.equal(amount - burnAmount);
    });
  });
});
