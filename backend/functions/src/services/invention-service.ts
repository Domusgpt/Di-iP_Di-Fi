/**
 * Invention Service
 * Handles CRUD for inventions and proxies AI analysis to The Brain.
 * Integration Point: Publishes to Pub/Sub topic `invention.created`
 */

import { Router, Request, Response } from "express";
import * as admin from "firebase-admin";
import { PubSub } from "@google-cloud/pubsub";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();
const pubsub = new PubSub();
const db = admin.firestore();

/**
 * POST /api/inventions/analyze
 * Accepts raw idea input and dispatches to The Brain for AI processing.
 */
router.post("/analyze", async (req: AuthenticatedRequest, res: Response) => {
  const { raw_text, voice_url, sketch_url } = req.body;
  const userId = req.user!.uid;

  if (!raw_text && !voice_url && !sketch_url) {
    res.status(400).json({ error: "At least one input (raw_text, voice_url, sketch_url) is required" });
    return;
  }

  const inventionId = uuidv4();

  // Create draft in Firestore (optimistic)
  const draft = {
    invention_id: inventionId,
    status: "AI_PROCESSING",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    creator_id: userId,
    social_metadata: {
      display_title: "Processing...",
      short_pitch: "AI is analyzing your idea",
    },
  };

  await db.collection("inventions").doc(inventionId).set(draft);

  // Publish to Pub/Sub for The Brain to pick up
  const topic = pubsub.topic("ai.processing");
  await topic.publishMessage({
    json: {
      invention_id: inventionId,
      creator_id: userId,
      raw_text,
      voice_url,
      sketch_url,
      action: "INITIAL_ANALYSIS",
    },
  });

  res.status(202).json({
    invention_id: inventionId,
    status: "AI_PROCESSING",
    message: "Your idea is being analyzed. You will be notified when the draft is ready.",
  });
});

/**
 * POST /api/inventions/:id/chat
 * Continue the AI agent conversation for refining an invention.
 */
router.post("/:id/chat", async (req: AuthenticatedRequest, res: Response) => {
  const { id } = req.params;
  const { message } = req.body;
  const userId = req.user!.uid;

  // Verify ownership
  const doc = await db.collection("inventions").doc(id).get();
  if (!doc.exists || doc.data()?.creator_id !== userId) {
    res.status(404).json({ error: "Invention not found" });
    return;
  }

  // Dispatch to The Brain
  const topic = pubsub.topic("ai.processing");
  await topic.publishMessage({
    json: {
      invention_id: id,
      creator_id: userId,
      message,
      action: "CONTINUE_CHAT",
    },
  });

  res.status(202).json({ status: "processing", message: "AI is processing your response" });
});

/**
 * POST /api/inventions/:id/publish
 * Move an invention from REVIEW_READY to LIVE on the feed.
 */
router.post("/:id/publish", async (req: AuthenticatedRequest, res: Response) => {
  const { id } = req.params;
  const userId = req.user!.uid;

  const doc = await db.collection("inventions").doc(id).get();
  if (!doc.exists || doc.data()?.creator_id !== userId) {
    res.status(404).json({ error: "Invention not found" });
    return;
  }

  if (doc.data()?.status !== "REVIEW_READY") {
    res.status(400).json({ error: "Invention must be in REVIEW_READY status to publish" });
    return;
  }

  await db.collection("inventions").doc(id).update({
    status: "LIVE",
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Notify the event bus
  const topic = pubsub.topic("invention.created");
  await topic.publishMessage({
    json: { invention_id: id, creator_id: userId, action: "PUBLISHED" },
  });

  res.json({ status: "LIVE", message: "Your invention is now live on the feed!" });
});

/**
 * GET /api/inventions/:id
 * Get full invention details.
 */
router.get("/:id", async (req: Request, res: Response) => {
  const { id } = req.params;
  const doc = await db.collection("inventions").doc(id).get();

  if (!doc.exists) {
    res.status(404).json({ error: "Invention not found" });
    return;
  }

  res.json(doc.data());
});

export const inventionRoutes = router;
