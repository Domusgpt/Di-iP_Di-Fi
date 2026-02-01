/**
 * Invention Pub/Sub Event Handlers
 * Listens on topic: `invention.created`
 */

import { onMessagePublished } from "firebase-functions/v2/pubsub";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { sendNotification } from "../services/notification-service";

const db = admin.firestore();

/**
 * Triggered when an invention is published to the feed.
 * Handles: feed indexing, notification to followers, reputation update.
 */
export const onInventionCreated = onMessagePublished(
  { topic: "invention.created", region: "us-central1" },
  async (event) => {
    const data = event.data.message.json;
    const { invention_id, creator_id, action } = data;

    logger.info(`Invention event: ${action} for ${invention_id}`);

    if (action === "PUBLISHED") {
      // Update the feed index (add to trending algorithm inputs)
      await db.collection("feed_index").doc(invention_id).set({
        invention_id,
        creator_id,
        published_at: admin.firestore.FieldValue.serverTimestamp(),
        engagement_score: 0,
        view_count: 0,
      });

      // Update creator's invention count and reputation
      await db.collection("users").doc(creator_id).update({
        inventions_count: admin.firestore.FieldValue.increment(1),
        reputation_score: admin.firestore.FieldValue.increment(10),
      });

      // Send push notification to creator's followers
      const inventionDoc = await db.collection("inventions").doc(invention_id).get();
      const inventionTitle = inventionDoc.data()?.social_metadata?.display_title || "a new invention";
      const creatorDoc = await db.collection("users").doc(creator_id).get();
      const creatorName = creatorDoc.data()?.display_name || "Someone";

      const followersSnapshot = await db
        .collection("followers")
        .doc(creator_id)
        .collection("user_followers")
        .limit(500)
        .get();

      if (!followersSnapshot.empty) {
        const notifications = followersSnapshot.docs.map((followerDoc) =>
          sendNotification({
            userId: followerDoc.id,
            title: `${creatorName} posted a new invention`,
            body: inventionTitle,
            type: "new_invention",
            data: { invention_id },
          })
        );
        await Promise.allSettled(notifications);
        logger.info(`Notified ${followersSnapshot.size} followers of ${creator_id}`);
      }
    }
  },
);
