import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { Crowdsale, RoyaltyToken } from "../typechain-types";

describe("Crowdsale", function () {
  let crowdsale: Crowdsale;
  let royaltyToken: RoyaltyToken;
  let mockUSDC: any;
  let owner: any;
  let investor1: any;
  let investor2: any;

  const GOAL = ethers.parseUnits("10000", 6); // 10,000 USDC
  const MIN_INVESTMENT = ethers.parseUnits("10", 6); // 10 USDC
  const TOKEN_SUPPLY = ethers.parseUnits("1000000", 18); // 1M tokens
  const DURATION = 30 * 24 * 60 * 60; // 30 days

  beforeEach(async function () {
    [owner, investor1, investor2] = await ethers.getSigners();

    // Deploy mock USDC (ERC20)
    const MockERC20 = await ethers.getContractFactory("RoyaltyToken");
    mockUSDC = await MockERC20.deploy("Mock USDC", "USDC", 0, ethers.parseUnits("1000000", 6));
    await mockUSDC.waitForDeployment();

    // Mint USDC to investors
    await mockUSDC.mintToInvestor(investor1.address, ethers.parseUnits("50000", 6));
    await mockUSDC.mintToInvestor(investor2.address, ethers.parseUnits("50000", 6));

    // Deploy RoyaltyToken for the invention
    const RoyaltyTokenFactory = await ethers.getContractFactory("RoyaltyToken");
    royaltyToken = await RoyaltyTokenFactory.deploy(
      "Invention Alpha Royalty",
      "IAR",
      0,
      TOKEN_SUPPLY,
    );
    await royaltyToken.waitForDeployment();

    // Deploy Crowdsale
    const CrowdsaleFactory = await ethers.getContractFactory("Crowdsale");
    crowdsale = await CrowdsaleFactory.deploy(
      await mockUSDC.getAddress(),
      await royaltyToken.getAddress(),
      GOAL,
      MIN_INVESTMENT,
      DURATION,
    );
    await crowdsale.waitForDeployment();

    // Transfer RoyaltyToken ownership to the Crowdsale so it can mint
    await royaltyToken.transferOwnership(await crowdsale.getAddress());
  });

  describe("Deployment", function () {
    it("should set correct parameters", async function () {
      expect(await crowdsale.goalAmount()).to.equal(GOAL);
      expect(await crowdsale.minInvestment()).to.equal(MIN_INVESTMENT);
      expect(await crowdsale.totalRaised()).to.equal(0);
      expect(await crowdsale.finalized()).to.equal(false);
      expect(await crowdsale.goalReached()).to.equal(false);
    });

    it("should set deadline in the future", async function () {
      const deadline = await crowdsale.deadline();
      const now = BigInt(await time.latest());
      expect(deadline).to.be.greaterThan(now);
    });
  });

  describe("Investment", function () {
    it("should accept a valid investment", async function () {
      const amount = ethers.parseUnits("100", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);

      await expect(crowdsale.connect(investor1).invest(amount))
        .to.emit(crowdsale, "Investment");

      expect(await crowdsale.totalRaised()).to.equal(amount);
      expect(await crowdsale.contributions(investor1.address)).to.equal(amount);
      expect(await crowdsale.investorCount()).to.equal(1);
    });

    it("should mint royalty tokens proportional to investment", async function () {
      const amount = ethers.parseUnits("1000", 6); // 10% of goal
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);
      await crowdsale.connect(investor1).invest(amount);

      const expectedTokens = (amount * TOKEN_SUPPLY) / GOAL;
      expect(await royaltyToken.balanceOf(investor1.address)).to.equal(expectedTokens);
    });

    it("should reject investment below minimum", async function () {
      const amount = ethers.parseUnits("5", 6); // 5 USDC < 10 USDC minimum
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);

      await expect(crowdsale.connect(investor1).invest(amount))
        .to.be.revertedWith("Below minimum investment");
    });

    it("should track multiple investors", async function () {
      const amount1 = ethers.parseUnits("500", 6);
      const amount2 = ethers.parseUnits("300", 6);

      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount1);
      await crowdsale.connect(investor1).invest(amount1);

      await mockUSDC.connect(investor2).approve(await crowdsale.getAddress(), amount2);
      await crowdsale.connect(investor2).invest(amount2);

      expect(await crowdsale.investorCount()).to.equal(2);
      expect(await crowdsale.totalRaised()).to.equal(amount1 + amount2);
    });

    it("should not double-count investor on second investment", async function () {
      const amount = ethers.parseUnits("100", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount * 2n);

      await crowdsale.connect(investor1).invest(amount);
      await crowdsale.connect(investor1).invest(amount);

      expect(await crowdsale.investorCount()).to.equal(1);
      expect(await crowdsale.contributions(investor1.address)).to.equal(amount * 2n);
    });
  });

  describe("Goal Reached", function () {
    it("should emit GoalReached when goal is met", async function () {
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), GOAL);

      await expect(crowdsale.connect(investor1).invest(GOAL))
        .to.emit(crowdsale, "GoalReached")
        .withArgs(GOAL);

      expect(await crowdsale.goalReached()).to.equal(true);
    });

    it("should allow over-funding", async function () {
      const overAmount = GOAL + ethers.parseUnits("500", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), overAmount);
      await crowdsale.connect(investor1).invest(overAmount);

      expect(await crowdsale.totalRaised()).to.equal(overAmount);
      expect(await crowdsale.goalReached()).to.equal(true);
    });
  });

  describe("Finalization", function () {
    it("should release funds to owner when goal reached", async function () {
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), GOAL);
      await crowdsale.connect(investor1).invest(GOAL);

      const ownerBalanceBefore = await mockUSDC.balanceOf(owner.address);
      await crowdsale.finalize();
      const ownerBalanceAfter = await mockUSDC.balanceOf(owner.address);

      expect(ownerBalanceAfter - ownerBalanceBefore).to.equal(GOAL);
      expect(await crowdsale.finalized()).to.equal(true);
    });

    it("should finalize distribution on royalty token", async function () {
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), GOAL);
      await crowdsale.connect(investor1).invest(GOAL);
      await crowdsale.finalize();

      expect(await royaltyToken.distributionFinalized()).to.equal(true);
    });

    it("should not allow finalization before deadline if goal not reached", async function () {
      const amount = ethers.parseUnits("100", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);
      await crowdsale.connect(investor1).invest(amount);

      await expect(crowdsale.finalize())
        .to.be.revertedWith("Crowdsale still active");
    });

    it("should allow finalization after deadline even if goal not reached", async function () {
      const amount = ethers.parseUnits("100", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);
      await crowdsale.connect(investor1).invest(amount);

      await time.increase(DURATION + 1);
      await crowdsale.finalize();

      expect(await crowdsale.finalized()).to.equal(true);
      expect(await crowdsale.goalReached()).to.equal(false);
    });
  });

  describe("Refunds", function () {
    it("should allow refund when goal not reached after deadline", async function () {
      const amount = ethers.parseUnits("500", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);
      await crowdsale.connect(investor1).invest(amount);

      await time.increase(DURATION + 1);
      await crowdsale.finalize();

      const balanceBefore = await mockUSDC.balanceOf(investor1.address);
      await expect(crowdsale.connect(investor1).refund())
        .to.emit(crowdsale, "Refunded")
        .withArgs(investor1.address, amount);
      const balanceAfter = await mockUSDC.balanceOf(investor1.address);

      expect(balanceAfter - balanceBefore).to.equal(amount);
    });

    it("should not allow refund when goal was reached", async function () {
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), GOAL);
      await crowdsale.connect(investor1).invest(GOAL);
      await crowdsale.finalize();

      await expect(crowdsale.connect(investor1).refund())
        .to.be.revertedWith("Goal was reached, no refunds");
    });

    it("should not allow double refund", async function () {
      const amount = ethers.parseUnits("500", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);
      await crowdsale.connect(investor1).invest(amount);

      await time.increase(DURATION + 1);
      await crowdsale.finalize();

      await crowdsale.connect(investor1).refund();
      await expect(crowdsale.connect(investor1).refund())
        .to.be.revertedWith("No contribution to refund");
    });

    it("should reject investment after deadline", async function () {
      await time.increase(DURATION + 1);

      const amount = ethers.parseUnits("100", 6);
      await mockUSDC.connect(investor1).approve(await crowdsale.getAddress(), amount);

      await expect(crowdsale.connect(investor1).invest(amount))
        .to.be.revertedWith("Crowdsale ended");
    });
  });
});
