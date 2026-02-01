/**
 * Profile Service
 * Manages user profiles in Firestore.
 */

import { Router, Response } from "express";
import * as admin from "firebase-admin";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();
const db = admin.firestore();

/**
 * GET /api/profile
 * Get the authenticated user's profile.
 */
router.get("/", async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.uid;
  const doc = await db.collection("users").doc(userId).get();

  if (!doc.exists) {
    res.status(404).json({ error: "Profile not found" });
    return;
  }

  res.json(doc.data());
});

/**
 * PUT /api/profile
 * Update the authenticated user's profile.
 */
router.put("/", async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.uid;
  const allowedFields = ["display_name", "bio", "avatar_url", "role"];
  const updates: Record<string, unknown> = {};

  for (const field of allowedFields) {
    if (req.body[field] !== undefined) {
      updates[field] = req.body[field];
    }
  }

  if (Object.keys(updates).length === 0) {
    res.status(400).json({ error: "No valid fields to update" });
    return;
  }

  updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("users").doc(userId).update(updates);

  res.json({ status: "updated" });
});

/**
 * PUT /api/profile/wallet
 * Link a wallet address to the user's profile.
 */
router.put("/wallet", async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.uid;
  const { wallet_address } = req.body;

  if (!wallet_address) {
    res.status(400).json({ error: "wallet_address is required" });
    return;
  }

  await db.collection("users").doc(userId).update({
    wallet_address,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  res.json({ status: "wallet_linked" });
});

export const profileRoutes = router;
