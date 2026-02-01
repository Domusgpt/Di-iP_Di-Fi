import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config({ path: "../.env" });

const DEPLOYER_KEY = process.env.DEPLOYER_PRIVATE_KEY || "0x" + "0".repeat(64);
const RPC_URL = process.env.RPC_URL || "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    polygonMumbai: {
      url: RPC_URL,
      accounts: [DEPLOYER_KEY],
      chainId: 80001,
    },
    polygon: {
      url: RPC_URL,
      accounts: [DEPLOYER_KEY],
      chainId: 137,
    },
    base: {
      url: RPC_URL,
      accounts: [DEPLOYER_KEY],
      chainId: 8453,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
