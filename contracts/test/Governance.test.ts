import { expect } from "chai";
import { ethers } from "hardhat";
import { Governance, ReputationToken } from "../typechain-types";

describe("Liquid Democracy Governance", function () {
  let gov: Governance;
  let rep: ReputationToken;
  let owner: any;
  let user1: any;
  let user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy Reputation Token
    const RepFactory = await ethers.getContractFactory("ReputationToken");
    rep = await RepFactory.deploy();
    await rep.waitForDeployment();

    // Deploy Governance
    const GovFactory = await ethers.getContractFactory("Governance");
    gov = await GovFactory.deploy(await rep.getAddress());
    await gov.waitForDeployment();

    // Mint initial reputation (Owner only)
    await rep.mint(user1.address, ethers.parseEther("150")); // Enough to propose
    await rep.mint(user2.address, ethers.parseEther("50"));  // Voting only
  });

  describe("ReputationToken (Soulbound)", function () {
    it("should allow minting by owner", async function () {
      expect(await rep.balanceOf(user1.address)).to.equal(ethers.parseEther("150"));
    });

    it("should prevent transfers between users", async function () {
      await expect(
        rep.connect(user1).transfer(user2.address, ethers.parseEther("10"))
      ).to.be.revertedWith("ReputationToken is non-transferable");
    });
  });

  describe("Proposals", function () {
    it("should allow users with >100 REP to propose", async function () {
      // Create a proposal and verify the event arguments
      // Note: Chai's any() is not available in Hardhat's chai wrapper in this environment
      // We'll capture the transaction and inspect the logs if needed, or just check the other args
      const tx = await gov.connect(user1).createProposal("Test Proposal");
      await expect(tx).to.emit(gov, "ProposalCreated").withArgs(0, "Test Proposal", (arg: any) => {
        return typeof arg === 'bigint' || typeof arg === 'number'; // timestamp
      });
    });

    it("should revert if user has insufficient reputation", async function () {
      await expect(
        gov.connect(user2).createProposal("Spam Proposal")
      ).to.be.revertedWith("Insufficient reputation");
    });
  });

  describe("Voting", function () {
    beforeEach(async function () {
      await gov.connect(user1).createProposal("Vote Me");
    });

    it("should tally votes correctly", async function () {
      // User 2 votes YES
      await expect(gov.connect(user2).vote(0, true))
        .to.emit(gov, "Voted")
        .withArgs(0, user2.address, true, ethers.parseEther("50"));

      const proposal = await gov.proposals(0);
      expect(proposal.votesFor).to.equal(ethers.parseEther("50"));
    });

    it("should prevent double voting", async function () {
      await gov.connect(user2).vote(0, true);
      await expect(
        gov.connect(user2).vote(0, false)
      ).to.be.revertedWith("Already voted");
    });
  });

  describe("Delegation", function () {
    it("should emit Delegated event", async function () {
      await expect(gov.connect(user2).delegate(user1.address))
        .to.emit(gov, "Delegated")
        .withArgs(user2.address, user1.address);
    });
  });
});
