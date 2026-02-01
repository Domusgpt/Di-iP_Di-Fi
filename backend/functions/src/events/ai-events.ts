/**
 * AI Processing Event Handler
 * Listens on topic: `ai.processing.complete`
 * Triggered by The Brain (Python) when AI analysis is done.
 */

import { onMessagePublished } from "firebase-functions/v2/pubsub";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const db = admin.firestore();

/**
 * Triggered when The Brain finishes processing an invention.
 * Updates the Firestore document with the structured AI output.
 */
export const onAiProcessingComplete = onMessagePublished(
  { topic: "ai.processing.complete", region: "us-central1" },
  async (event) => {
    const data = event.data.message.json;
    const { invention_id, structured_data, action } = data;

    logger.info(`AI processing complete for invention ${invention_id}, action: ${action}`);

    if (action === "INITIAL_ANALYSIS_COMPLETE") {
      // The Brain has structured the raw idea into the canonical schema
      await db.collection("inventions").doc(invention_id).update({
        status: "REVIEW_READY",
        social_metadata: structured_data.social_metadata,
        technical_brief: structured_data.technical_brief,
        risk_assessment: structured_data.risk_assessment,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // TODO: Send push notification to the inventor
      // "Your campaign draft is ready for review."
    } else if (action === "CHAT_RESPONSE") {
      // The Brain responded to a follow-up question
      // Store the updated fields
      const updates: Record<string, unknown> = {
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (structured_data.technical_brief) {
        updates.technical_brief = structured_data.technical_brief;
      }
      if (structured_data.risk_assessment) {
        updates.risk_assessment = structured_data.risk_assessment;
      }
      if (structured_data.social_metadata) {
        updates.social_metadata = structured_data.social_metadata;
      }

      await db.collection("inventions").doc(invention_id).update(updates);
    }
  },
);
