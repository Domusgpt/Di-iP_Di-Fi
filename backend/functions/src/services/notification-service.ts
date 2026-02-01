/**
 * Notification Service
 * Manages push notifications and in-app notification feed.
 * Uses Firebase Cloud Messaging (FCM) for push and Firestore for the feed.
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const db = admin.firestore();

export interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  type: "investment_confirmed" | "invention_funded" | "comment" | "like" | "draft_ready" | "patent_update" | "new_invention";
  data?: Record<string, string>;
}

/**
 * Send a notification to a user (both push + in-app feed).
 */
export async function sendNotification(payload: NotificationPayload): Promise<void> {
  const { userId, title, body, type, data } = payload;

  // 1. Store in Firestore notification feed (always)
  await db.collection("users").doc(userId).collection("notifications").add({
    title,
    body,
    type,
    data: data || {},
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Send push notification via FCM (if user has a token)
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcm_token;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: { type, ...(data || {}) },
        android: {
          priority: "high",
          notification: { channelId: "ideacapital_default" },
        },
        apns: {
          payload: { aps: { badge: 1, sound: "default" } },
        },
      });
      logger.info(`Push sent to ${userId}: ${title}`);
    }
  } catch (error) {
    // Push failures are non-critical — the in-app feed is the fallback
    logger.warn(`Push notification failed for ${userId}:`, error);
  }
}

/**
 * Send notification when an investment is confirmed.
 */
export async function notifyInvestmentConfirmed(
  userId: string,
  inventionTitle: string,
  amount: number,
  ownershipPercent: number,
): Promise<void> {
  await sendNotification({
    userId,
    title: "Investment Confirmed!",
    body: `You now own ${ownershipPercent.toFixed(2)}% of "${inventionTitle}"`,
    type: "investment_confirmed",
    data: { amount: amount.toString() },
  });
}

/**
 * Send notification when an invention reaches its funding goal.
 */
export async function notifyInventionFunded(
  inventorId: string,
  inventionTitle: string,
  totalRaised: number,
): Promise<void> {
  await sendNotification({
    userId: inventorId,
    title: "Your Invention is Funded!",
    body: `"${inventionTitle}" raised $${totalRaised.toFixed(0)} USDC. Time to build!`,
    type: "invention_funded",
    data: { total_raised: totalRaised.toString() },
  });
}

/**
 * Send notification when the AI draft is ready for review.
 */
export async function notifyDraftReady(
  userId: string,
  inventionId: string,
  inventionTitle: string,
): Promise<void> {
  await sendNotification({
    userId,
    title: "Your Campaign Draft is Ready!",
    body: `"${inventionTitle}" has been structured by the AI. Review and publish it.`,
    type: "draft_ready",
    data: { invention_id: inventionId },
  });
}
