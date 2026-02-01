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
import { ethers } from "ethers";

const pubsub = new PubSub();
const db = admin.firestore();

const CROWDSALE_ABI = [
  "event Investment(address indexed investor, uint256 usdcAmount, uint256 tokenAmount)",
];

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

    const rpcUrl = process.env.RPC_URL;
    if (!rpcUrl) {
      logger.warn("RPC_URL not set, skipping blockchain check");
      return;
    }

    const provider = new ethers.JsonRpcProvider(rpcUrl);

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

    const iface = new ethers.Interface(CROWDSALE_ABI);

    for (const doc of pendingSnapshot.docs) {
      const investment = doc.data();
      const { tx_hash, invention_id, amount_usdc, wallet_address } = investment;

      try {
        const receipt = await provider.getTransactionReceipt(tx_hash);

        if (!receipt) {
          // Transaction not mined yet
          logger.info(`Tx ${tx_hash} still pending`);
          continue;
        }

        if (receipt.status === 1) {
          // Transaction confirmed — parse the Investment event to get token_amount
          let tokenAmount = 0;
          for (const log of receipt.logs) {
            try {
              const parsed = iface.parseLog({ topics: log.topics as string[], data: log.data });
              if (parsed && parsed.name === "Investment") {
                tokenAmount = Number(ethers.formatUnits(parsed.args.tokenAmount, 18));
                break;
              }
            } catch {
              // Not our event, skip
            }
          }

          // Publish to investment.confirmed topic
          const topic = pubsub.topic("investment.confirmed");
          await topic.publishMessage({
            json: {
              investment_id: doc.id,
              invention_id,
              wallet_address,
              amount_usdc,
              token_amount: tokenAmount,
              block_number: receipt.blockNumber,
            },
          });

          logger.info(`Investment ${doc.id} CONFIRMED at block ${receipt.blockNumber}`);
        } else {
          // Transaction reverted
          await doc.ref.update({
            status: "FAILED",
            failed_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          logger.warn(`Investment ${doc.id} transaction REVERTED: ${tx_hash}`);
        }
      } catch (error) {
        logger.error(`Error checking tx ${tx_hash}:`, error);
      }
    }
  },
);
