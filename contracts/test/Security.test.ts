import { expect } from "chai";
import { ethers } from "hardhat";

describe("ReputationToken Security", function () {
  it("Should prevent transfers (Soulbound protection)", async function () {
    const [owner, otherAccount] = await ethers.getSigners();
    const ReputationToken = await ethers.getContractFactory("ReputationToken");
    const token = await ReputationToken.deploy();

    // Mint to owner
    await token.mint(owner.address, 100);

    // Attempt transfer
    await expect(
      token.transfer(otherAccount.address, 50)
    ).to.be.revertedWith("ReputationToken is non-transferable");
  });
});
