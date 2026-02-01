/**
 * IdeaCapital Cloud Functions Entry Point
 *
 * This is the "Nervous System" — the TypeScript event bus that connects:
 * - The Face (Flutter) → via HTTPS callable functions
 * - The Vault (Rust)   → via Pub/Sub events
 * - The Brain (Python)  → via Pub/Sub events
 * - The Chain (Polygon) → via blockchain indexer
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// ---- HTTPS API Functions (Called by Flutter) ----
export { apiRouter } from "./api";

// ---- Pub/Sub Event Handlers ----
export { onInventionCreated } from "./events/invention-events";
export { onInvestmentPending, onInvestmentConfirmed } from "./events/investment-events";
export { onAiProcessingComplete } from "./events/ai-events";

// ---- Firestore Triggers ----
export { onUserCreated } from "./events/user-events";

// ---- Blockchain Indexer ----
export { blockchainIndexer } from "./events/chain-indexer";
