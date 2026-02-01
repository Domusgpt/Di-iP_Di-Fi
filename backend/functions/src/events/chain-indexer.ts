/**
 * Blockchain Indexer (Scheduled)
 *
 * Runs on a schedule to check for confirmed blockchain events.
 * In production, this would be replaced by The Graph or a dedicated
 * event listener in The Vault (Rust), but this serves as the Phase 2 MVP indexer.
 *
 * Integration Point: Reads from blockchain, publishes `investment.confirmed` to Pub/Sub.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { PubSub } from "@google-cloud/pubsub";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const pubsub = new PubSub();
const db = admin.firestore();

/**
 * Runs every minute to check pending investments against the blockchain.
 */
export const blockchainIndexer = onSchedule(
  {
    schedule: "every 1 minutes",
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async () => {
    logger.info("Blockchain indexer running...");

    // Find all pending investments
    const pendingSnapshot = await db
      .collection("investments")
      .where("status", "==", "PENDING")
      .limit(50)
      .get();

    if (pendingSnapshot.empty) {
      logger.info("No pending investments to check.");
      return;
    }

    for (const doc of pendingSnapshot.docs) {
      const investment = doc.data();
      const { tx_hash, investment_id, invention_id, amount_usdc, wallet_address } = investment;

      try {
        // TODO: Use viem/ethers to check transaction receipt
        // const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
        // const receipt = await provider.getTransactionReceipt(tx_hash);

        // For now, this is the structure of what happens when confirmed:
        // if (receipt && receipt.status === 1) {
        //   const topic = pubsub.topic("investment.confirmed");
        //   await topic.publishMessage({
        //     json: {
        //       investment_id,
        //       invention_id,
        //       wallet_address,
        //       amount_usdc,
        //       token_amount: calculateTokenAmount(amount_usdc),
        //       block_number: receipt.blockNumber,
        //     },
        //   });
        // }

        logger.info(`Checked tx ${tx_hash} for investment ${investment_id}`);
      } catch (error) {
        logger.error(`Error checking tx ${tx_hash}:`, error);
      }
    }
  },
);
