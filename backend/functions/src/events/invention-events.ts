/**
 * Invention Pub/Sub Event Handlers
 * Listens on topic: `invention.created`
 */

import { onMessagePublished } from "firebase-functions/v2/pubsub";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

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

      // Update creator's invention count
      await db.collection("users").doc(creator_id).update({
        inventions_count: admin.firestore.FieldValue.increment(1),
      });

      // TODO: Send push notification to creator's followers
      // TODO: Update reputation score for creator
    }
  },
);
