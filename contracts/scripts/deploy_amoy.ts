import { ethers } from "hardhat";

async function main() {
  console.log("🚀 Deploying contracts to Polygon Amoy Testnet...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // 1. Deploy Mock USDC (for testing only)
  // In production, use the real USDC address: 0x41e94eb019c0762f9bfcf9fb1e58725bfb0e7582 (Amoy)
  const USDC_ADDRESS = "0x41e94eb019c0762f9bfcf9fb1e58725bfb0e7582";
  console.log("Using USDC:", USDC_ADDRESS);

  // 2. Deploy IPNFT
  const IPNFT = await ethers.getContractFactory("IPNFT");
  const ipnft = await IPNFT.deploy();
  await ipnft.waitForDeployment();
  console.log("✅ IPNFT deployed to:", await ipnft.getAddress());

  // 3. Deploy DividendVault
  const DividendVault = await ethers.getContractFactory("DividendVault");
  const vault = await DividendVault.deploy(USDC_ADDRESS);
  await vault.waitForDeployment();
  console.log("✅ DividendVault deployed to:", await vault.getAddress());

  // 4. Deploy StoryProtocolAdapter
  // Mock registry address for now
  const STORY_REGISTRY = "0x0000000000000000000000000000000000000000";
  const Adapter = await ethers.getContractFactory("StoryProtocolAdapter");
  const adapter = await Adapter.deploy(STORY_REGISTRY);
  await adapter.waitForDeployment();
  console.log("✅ StoryProtocolAdapter deployed to:", await adapter.getAddress());

  console.log("\n🎉 Deployment Complete!");
  console.log("----------------------------------------------------");
  console.log(`IPNFT_ADDRESS=${await ipnft.getAddress()}`);
  console.log(`DIVIDEND_VAULT_ADDRESS=${await vault.getAddress()}`);
  console.log(`STORY_ADAPTER_ADDRESS=${await adapter.getAddress()}`);
  console.log("----------------------------------------------------");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
