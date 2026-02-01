import { expect } from "chai";
import { ethers } from "hardhat";
import { DividendVault } from "../typechain-types";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

describe("DividendVault", function () {
  let vault: DividendVault;
  let mockUSDC: any;
  let owner: any;
  let claimant1: any;
  let claimant2: any;
  let claimant3: any;

  beforeEach(async function () {
    [owner, claimant1, claimant2, claimant3] = await ethers.getSigners();

    // Deploy mock USDC
    const MockERC20 = await ethers.getContractFactory("RoyaltyToken");
    mockUSDC = await MockERC20.deploy("Mock USDC", "USDC", 0, ethers.parseUnits("10000000", 6));
    await mockUSDC.waitForDeployment();

    // Mint USDC to owner (for funding distributions)
    await mockUSDC.mintToInvestor(owner.address, ethers.parseUnits("1000000", 6));

    // Deploy DividendVault
    const VaultFactory = await ethers.getContractFactory("DividendVault");
    vault = await VaultFactory.deploy(await mockUSDC.getAddress());
    await vault.waitForDeployment();
  });

  describe("Deployment", function () {
    it("should set USDC address", async function () {
      expect(await vault.usdc()).to.equal(await mockUSDC.getAddress());
    });

    it("should start at epoch 0", async function () {
      expect(await vault.currentEpoch()).to.equal(0);
    });
  });

  describe("Distribution Creation", function () {
    it("should create a distribution epoch", async function () {
      const totalAmount = ethers.parseUnits("10000", 6);
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test_root"));

      await mockUSDC.approve(await vault.getAddress(), totalAmount);

      await expect(vault.createDistribution(merkleRoot, totalAmount))
        .to.emit(vault, "NewDistribution")
        .withArgs(1, merkleRoot, totalAmount);

      expect(await vault.currentEpoch()).to.equal(1);
      expect(await vault.merkleRoots(1)).to.equal(merkleRoot);
      expect(await vault.epochTotals(1)).to.equal(totalAmount);
    });

    it("should reject zero amount", async function () {
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await expect(vault.createDistribution(merkleRoot, 0))
        .to.be.revertedWith("Zero amount");
    });

    it("should reject empty merkle root", async function () {
      await expect(vault.createDistribution(ethers.ZeroHash, 1000))
        .to.be.revertedWith("Invalid root");
    });

    it("should increment epochs", async function () {
      const amount = ethers.parseUnits("1000", 6);
      const root1 = ethers.keccak256(ethers.toUtf8Bytes("root1"));
      const root2 = ethers.keccak256(ethers.toUtf8Bytes("root2"));

      await mockUSDC.approve(await vault.getAddress(), amount * 2n);
      await vault.createDistribution(root1, amount);
      await vault.createDistribution(root2, amount);

      expect(await vault.currentEpoch()).to.equal(2);
    });
  });

  describe("Dividend Claims with Merkle Proofs", function () {
    let merkleTree: any;
    let merkleRoot: string;
    const claim1Amount = ethers.parseUnits("500", 6);
    const claim2Amount = ethers.parseUnits("300", 6);
    const claim3Amount = ethers.parseUnits("200", 6);
    const totalAmount = claim1Amount + claim2Amount + claim3Amount;

    beforeEach(async function () {
      // Build a Merkle tree with the three claimants
      const values = [
        [claimant1.address, claim1Amount],
        [claimant2.address, claim2Amount],
        [claimant3.address, claim3Amount],
      ];

      merkleTree = StandardMerkleTree.of(values, ["address", "uint256"]);
      merkleRoot = merkleTree.root;

      // Fund and create the distribution
      await mockUSDC.approve(await vault.getAddress(), totalAmount);
      await vault.createDistribution(merkleRoot, totalAmount);
    });

    it("should allow valid claim with correct proof", async function () {
      // Get proof for claimant1
      let proof: string[] = [];
      for (const [i, v] of merkleTree.entries()) {
        if (v[0] === claimant1.address) {
          proof = merkleTree.getProof(i);
          break;
        }
      }

      const balanceBefore = await mockUSDC.balanceOf(claimant1.address);

      await expect(vault.connect(claimant1).claimDividend(1, claim1Amount, proof))
        .to.emit(vault, "DividendClaimed")
        .withArgs(1, claimant1.address, claim1Amount);

      const balanceAfter = await mockUSDC.balanceOf(claimant1.address);
      expect(balanceAfter - balanceBefore).to.equal(claim1Amount);
    });

    it("should prevent double claiming", async function () {
      let proof: string[] = [];
      for (const [i, v] of merkleTree.entries()) {
        if (v[0] === claimant1.address) {
          proof = merkleTree.getProof(i);
          break;
        }
      }

      await vault.connect(claimant1).claimDividend(1, claim1Amount, proof);

      await expect(vault.connect(claimant1).claimDividend(1, claim1Amount, proof))
        .to.be.revertedWith("Already claimed");
    });

    it("should reject claim with wrong amount", async function () {
      let proof: string[] = [];
      for (const [i, v] of merkleTree.entries()) {
        if (v[0] === claimant1.address) {
          proof = merkleTree.getProof(i);
          break;
        }
      }

      const wrongAmount = ethers.parseUnits("999", 6);
      await expect(vault.connect(claimant1).claimDividend(1, wrongAmount, proof))
        .to.be.revertedWith("Invalid proof");
    });

    it("should reject claim with wrong proof", async function () {
      // Use claimant2's proof for claimant1
      let proof: string[] = [];
      for (const [i, v] of merkleTree.entries()) {
        if (v[0] === claimant2.address) {
          proof = merkleTree.getProof(i);
          break;
        }
      }

      await expect(vault.connect(claimant1).claimDividend(1, claim1Amount, proof))
        .to.be.revertedWith("Invalid proof");
    });

    it("should correctly track claimed status", async function () {
      expect(await vault.hasClaimed(1, claimant1.address)).to.equal(false);

      let proof: string[] = [];
      for (const [i, v] of merkleTree.entries()) {
        if (v[0] === claimant1.address) {
          proof = merkleTree.getProof(i);
          break;
        }
      }

      await vault.connect(claimant1).claimDividend(1, claim1Amount, proof);
      expect(await vault.hasClaimed(1, claimant1.address)).to.equal(true);
      expect(await vault.hasClaimed(1, claimant2.address)).to.equal(false);
    });

    it("should allow all claimants to claim", async function () {
      for (const [i, v] of merkleTree.entries()) {
        const [addr, amount] = v;
        const proof = merkleTree.getProof(i);
        const signer =
          addr === claimant1.address ? claimant1 :
          addr === claimant2.address ? claimant2 :
          claimant3;

        await vault.connect(signer).claimDividend(1, amount, proof);
      }

      // Vault should be drained
      const vaultBalance = await mockUSDC.balanceOf(await vault.getAddress());
      expect(vaultBalance).to.equal(0);
    });
  });
});
