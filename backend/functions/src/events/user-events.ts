/**
 * User Firestore Triggers
 * Automatically creates a user profile when a new Firebase Auth user is created.
 */

import { beforeUserCreated } from "firebase-functions/v2/identity";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const db = admin.firestore();

/**
 * Triggered when a new user signs up via Firebase Auth.
 * Creates a default profile in Firestore.
 */
export const onUserCreated = beforeUserCreated(
  { region: "us-central1" },
  async (event) => {
    const user = event.data;
    logger.info(`New user created: ${user.uid}`);

    await db.collection("users").doc(user.uid).set({
      uid: user.uid,
      display_name: user.displayName || user.email?.split("@")[0] || "Anonymous",
      email: user.email,
      avatar_url: user.photoURL || null,
      bio: null,
      role: "both",
      reputation_score: 0,
      badges: [],
      wallet_address: null,
      inventions_count: 0,
      investments_count: 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);
