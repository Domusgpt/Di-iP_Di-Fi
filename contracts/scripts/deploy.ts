/**
 * IdeaCapital Contract Deployment Script
 *
 * Deploys the core contracts in order:
 * 1. IPNFT (the patent NFT collection)
 * 2. DividendVault (the revenue distribution contract)
 *
 * RoyaltyToken and Crowdsale are deployed per-invention, not globally.
 */

import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // 1. Deploy IPNFT
  console.log("\n--- Deploying IPNFT ---");
  const IPNFT = await ethers.getContractFactory("IPNFT");
  const ipnft = await IPNFT.deploy();
  await ipnft.waitForDeployment();
  const ipnftAddress = await ipnft.getAddress();
  console.log("IPNFT deployed to:", ipnftAddress);

  // 2. Deploy DividendVault (requires USDC address)
  // For testnet, we use a mock USDC or the testnet USDC address
  const USDC_ADDRESS = process.env.USDC_CONTRACT_ADDRESS || ethers.ZeroAddress;

  if (USDC_ADDRESS === ethers.ZeroAddress) {
    console.log("\n--- WARNING: No USDC address configured, skipping DividendVault ---");
    console.log("Set USDC_CONTRACT_ADDRESS in .env to deploy DividendVault");
  } else {
    console.log("\n--- Deploying DividendVault ---");
    const DividendVault = await ethers.getContractFactory("DividendVault");
    const vault = await DividendVault.deploy(USDC_ADDRESS);
    await vault.waitForDeployment();
    console.log("DividendVault deployed to:", await vault.getAddress());
  }

  console.log("\n--- Deployment Complete ---");
  console.log("IPNFT:", ipnftAddress);
  console.log("\nNext steps:");
  console.log("1. RoyaltyToken and Crowdsale are deployed per-invention");
  console.log("2. Update .env with the deployed addresses");
  console.log("3. Verify contracts on block explorer");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
