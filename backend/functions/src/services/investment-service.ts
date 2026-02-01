/**
 * Investment Service
 * Handles investment-related API endpoints.
 * Integration Point: Publishes to `investment.pending` Pub/Sub topic.
 * The Vault (Rust) handles the actual blockchain transaction verification.
 */

import { Router, Response } from "express";
import * as admin from "firebase-admin";
import { PubSub } from "@google-cloud/pubsub";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();
const pubsub = new PubSub();
const db = admin.firestore();

/**
 * POST /api/investments/:inventionId/pledge
 * Record a pledge (Phase 1: non-binding mock investment).
 */
router.post("/:inventionId/pledge", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;
  const { amount_usdc } = req.body;
  const userId = req.user!.uid;

  if (!amount_usdc || amount_usdc <= 0) {
    res.status(400).json({ error: "Invalid amount" });
    return;
  }

  const pledgeId = uuidv4();
  const pledge = {
    pledge_id: pledgeId,
    invention_id: inventionId,
    user_id: userId,
    amount_usdc,
    status: "PLEDGED", // Non-binding in Phase 1
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection("pledges").doc(pledgeId).set(pledge);

  // Update invention's raised amount (optimistic for pledges)
  await db.collection("inventions").doc(inventionId).update({
    "funding.raised_usdc": admin.firestore.FieldValue.increment(amount_usdc),
    "funding.backer_count": admin.firestore.FieldValue.increment(1),
  });

  res.status(201).json({ pledge_id: pledgeId, status: "PLEDGED" });
});

/**
 * POST /api/investments/:inventionId/invest
 * Record a real investment intent (Phase 2: blockchain-backed).
 * This creates the PENDING state while the blockchain tx is processed.
 */
router.post("/:inventionId/invest", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;
  const { amount_usdc, tx_hash, wallet_address } = req.body;
  const userId = req.user!.uid;

  if (!amount_usdc || !tx_hash || !wallet_address) {
    res.status(400).json({ error: "amount_usdc, tx_hash, and wallet_address are required" });
    return;
  }

  const investmentId = uuidv4();
  const investment = {
    investment_id: investmentId,
    invention_id: inventionId,
    user_id: userId,
    wallet_address,
    amount_usdc,
    tx_hash,
    status: "PENDING", // Waiting for blockchain confirmation
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection("investments").doc(investmentId).set(investment);

  // Publish to Pub/Sub — The Vault will watch the chain for confirmation
  const topic = pubsub.topic("investment.pending");
  await topic.publishMessage({
    json: {
      investment_id: investmentId,
      invention_id: inventionId,
      tx_hash,
      wallet_address,
      amount_usdc,
    },
  });

  res.status(202).json({
    investment_id: investmentId,
    status: "PENDING",
    message: "Investment submitted. Waiting for blockchain confirmation.",
  });
});

/**
 * GET /api/investments/:inventionId/status
 * Get funding status for an invention.
 */
router.get("/:inventionId/status", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;

  const doc = await db.collection("inventions").doc(inventionId).get();
  if (!doc.exists) {
    res.status(404).json({ error: "Invention not found" });
    return;
  }

  const data = doc.data();
  res.json({
    invention_id: inventionId,
    funding: data?.funding || {},
    status: data?.status,
  });
});

export const investmentRoutes = router;
