/**
 * Investment Pub/Sub Event Handlers
 * Listens on topics: `investment.pending`, `investment.confirmed`
 *
 * This is the critical async bridge between the UI and the blockchain.
 * Flow: Flutter → investment.pending → Vault watches chain → investment.confirmed → Firestore update
 */

import { onMessagePublished } from "firebase-functions/v2/pubsub";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { notifyInvestmentConfirmed, notifyInventionFunded } from "../services/notification-service";

const db = admin.firestore();

/**
 * Triggered when a user submits an investment transaction.
 * The Vault (Rust) also subscribes to this to begin watching the chain.
 */
export const onInvestmentPending = onMessagePublished(
  { topic: "investment.pending", region: "us-central1" },
  async (event) => {
    const data = event.data.message.json;
    const { investment_id, invention_id, tx_hash } = data;

    logger.info(`Investment pending: ${investment_id} for invention ${invention_id}, tx: ${tx_hash}`);

    // Optimistically update the UI state
    await db.collection("inventions").doc(invention_id).update({
      "funding.pending_investments": admin.firestore.FieldValue.increment(1),
    });
  },
);

/**
 * Triggered when The Vault confirms a blockchain transaction.
 * This is the "Source of Truth sync" — blockchain confirmed, now update Firestore.
 */
export const onInvestmentConfirmed = onMessagePublished(
  { topic: "investment.confirmed", region: "us-central1" },
  async (event) => {
    const data = event.data.message.json;
    const {
      investment_id,
      invention_id,
      wallet_address,
      amount_usdc,
      token_amount,
      block_number,
    } = data;

    logger.info(`Investment CONFIRMED: ${investment_id}, amount: ${amount_usdc} USDC`);

    const batch = db.batch();

    // Update investment record
    const investmentRef = db.collection("investments").doc(investment_id);
    batch.update(investmentRef, {
      status: "CONFIRMED",
      block_number,
      token_amount,
      confirmed_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update invention funding totals
    const inventionRef = db.collection("inventions").doc(invention_id);
    batch.update(inventionRef, {
      "funding.raised_usdc": admin.firestore.FieldValue.increment(amount_usdc),
      "funding.backer_count": admin.firestore.FieldValue.increment(1),
      "funding.pending_investments": admin.firestore.FieldValue.increment(-1),
    });

    await batch.commit();

    // Send push notification to the investor
    const investmentDoc = await db.collection("investments").doc(investment_id).get();
    const investorUserId = investmentDoc.data()?.user_id;
    const inventionDoc = await db.collection("inventions").doc(invention_id).get();
    const inventionData = inventionDoc.data();
    const inventionTitle = inventionData?.social_metadata?.display_title || "an invention";
    const totalSupply = inventionData?.funding?.token_supply || 1;
    const ownershipPercent = (token_amount / totalSupply) * 100;

    if (investorUserId) {
      await notifyInvestmentConfirmed(investorUserId, inventionTitle, amount_usdc, ownershipPercent);
    }

    // Check if funding goal is reached → notify inventor
    const updatedDoc = await db.collection("inventions").doc(invention_id).get();
    const funding = updatedDoc.data()?.funding;
    if (funding && funding.raised_usdc >= funding.goal_usdc && funding.goal_usdc > 0) {
      const creatorId = updatedDoc.data()?.creator_id;
      if (creatorId) {
        await notifyInventionFunded(creatorId, inventionTitle, funding.raised_usdc);
      }
    }
  },
);
