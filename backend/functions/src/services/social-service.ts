/**
 * Social Service
 * Handles comments, likes, and social interactions on inventions.
 * All data lives in Firestore (fast read, high volume, low financial risk).
 */

import { Router, Response } from "express";
import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();
const db = admin.firestore();

// ---- Comments ----

/**
 * GET /api/social/:inventionId/comments
 * Get comments for an invention, paginated.
 */
router.get("/:inventionId/comments", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
  const startAfter = req.query.startAfter as string;

  let query = db
    .collection("inventions")
    .doc(inventionId)
    .collection("comments")
    .orderBy("created_at", "desc")
    .limit(limit);

  if (startAfter) {
    const startDoc = await db
      .collection("inventions")
      .doc(inventionId)
      .collection("comments")
      .doc(startAfter)
      .get();
    if (startDoc.exists) {
      query = query.startAfter(startDoc);
    }
  }

  const snapshot = await query.get();
  const comments = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  res.json({ comments, hasMore: comments.length === limit });
});

/**
 * POST /api/social/:inventionId/comments
 * Add a comment to an invention.
 */
router.post("/:inventionId/comments", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;
  const { text, parent_id } = req.body;
  const userId = req.user!.uid;

  if (!text || text.trim().length === 0) {
    res.status(400).json({ error: "Comment text is required" });
    return;
  }

  if (text.length > 2000) {
    res.status(400).json({ error: "Comment must be 2000 characters or less" });
    return;
  }

  // Verify invention exists
  const inventionDoc = await db.collection("inventions").doc(inventionId).get();
  if (!inventionDoc.exists) {
    res.status(404).json({ error: "Invention not found" });
    return;
  }

  // Fetch commenter profile for denormalized display
  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.data();

  const commentId = uuidv4();
  const comment = {
    comment_id: commentId,
    user_id: userId,
    display_name: userData?.display_name || "Anonymous",
    avatar_url: userData?.avatar_url || null,
    text: text.trim(),
    parent_id: parent_id || null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    like_count: 0,
  };

  await db
    .collection("inventions")
    .doc(inventionId)
    .collection("comments")
    .doc(commentId)
    .set(comment);

  res.status(201).json({ comment_id: commentId, ...comment });
});

/**
 * DELETE /api/social/:inventionId/comments/:commentId
 * Delete own comment.
 */
router.delete("/:inventionId/comments/:commentId", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId, commentId } = req.params;
  const userId = req.user!.uid;

  const commentRef = db
    .collection("inventions")
    .doc(inventionId)
    .collection("comments")
    .doc(commentId);

  const commentDoc = await commentRef.get();
  if (!commentDoc.exists) {
    res.status(404).json({ error: "Comment not found" });
    return;
  }

  if (commentDoc.data()?.user_id !== userId) {
    res.status(403).json({ error: "Can only delete your own comments" });
    return;
  }

  await commentRef.delete();
  res.json({ status: "deleted" });
});

// ---- Likes ----

/**
 * POST /api/social/:inventionId/like
 * Like an invention (toggle).
 */
router.post("/:inventionId/like", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;
  const userId = req.user!.uid;

  const likeRef = db
    .collection("inventions")
    .doc(inventionId)
    .collection("likes")
    .doc(userId);

  const likeDoc = await likeRef.get();

  if (likeDoc.exists) {
    // Unlike
    await likeRef.delete();
    await db.collection("inventions").doc(inventionId).update({
      like_count: admin.firestore.FieldValue.increment(-1),
    });
    res.json({ liked: false });
  } else {
    // Like
    await likeRef.set({
      user_id: userId,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection("inventions").doc(inventionId).update({
      like_count: admin.firestore.FieldValue.increment(1),
    });
    res.json({ liked: true });
  }
});

/**
 * GET /api/social/:inventionId/like
 * Check if current user has liked an invention.
 */
router.get("/:inventionId/like", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;
  const userId = req.user!.uid;

  const likeDoc = await db
    .collection("inventions")
    .doc(inventionId)
    .collection("likes")
    .doc(userId)
    .get();

  res.json({ liked: likeDoc.exists });
});

/**
 * GET /api/social/:inventionId/like/count
 * Get like count for an invention.
 */
router.get("/:inventionId/like/count", async (req: AuthenticatedRequest, res: Response) => {
  const { inventionId } = req.params;

  const inventionDoc = await db.collection("inventions").doc(inventionId).get();
  res.json({ count: inventionDoc.data()?.like_count || 0 });
});

export const socialRoutes = router;
