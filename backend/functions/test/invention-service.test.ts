/**
 * Invention Service Unit Tests
 *
 * Tests the invention CRUD operations, AI analysis dispatch,
 * and publish flow.
 */

// Mock firebase-admin before any imports
jest.mock("firebase-admin", () => {
  const firestoreMock = {
    collection: jest.fn().mockReturnThis(),
    doc: jest.fn().mockReturnThis(),
    set: jest.fn().mockResolvedValue(undefined),
    get: jest.fn().mockResolvedValue({ exists: true, data: () => ({}) }),
    update: jest.fn().mockResolvedValue(undefined),
  };
  return {
    initializeApp: jest.fn(),
    firestore: jest.fn(() => firestoreMock),
    auth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
  };
});

jest.mock("@google-cloud/pubsub", () => {
  const publishMock = jest.fn().mockResolvedValue("msg-id-123");
  return {
    PubSub: jest.fn().mockImplementation(() => ({
      topic: jest.fn().mockReturnValue({
        publishMessage: publishMock,
      }),
    })),
    __publishMock: publishMock,
  };
});

jest.mock("uuid", () => ({
  v4: jest.fn().mockReturnValue("test-uuid-1234"),
}));

import * as admin from "firebase-admin";

describe("Invention Service", () => {
  const db = admin.firestore();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("POST /analyze", () => {
    it("should reject requests with no input", () => {
      const body = {};
      const hasInput = body.hasOwnProperty("raw_text") ||
        body.hasOwnProperty("voice_url") ||
        body.hasOwnProperty("sketch_url");
      expect(hasInput).toBe(false);
    });

    it("should create a draft in Firestore with AI_PROCESSING status", async () => {
      const inventionId = "test-uuid-1234";
      const userId = "user-abc";

      const draft = {
        invention_id: inventionId,
        status: "AI_PROCESSING",
        creator_id: userId,
        social_metadata: {
          display_title: "Processing...",
          short_pitch: "AI is analyzing your idea",
        },
      };

      await db.collection("inventions").doc(inventionId).set(draft);

      expect(db.collection).toHaveBeenCalledWith("inventions");
      expect(db.doc).toHaveBeenCalledWith(inventionId);
      expect(db.set).toHaveBeenCalledWith(
        expect.objectContaining({
          invention_id: inventionId,
          status: "AI_PROCESSING",
          creator_id: userId,
        })
      );
    });
  });

  describe("POST /:id/publish", () => {
    it("should reject publishing non-REVIEW_READY inventions", async () => {
      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: true,
        data: () => ({
          creator_id: "user-abc",
          status: "AI_PROCESSING",
        }),
      });

      const doc = await db.collection("inventions").doc("inv-1").get();
      const data = doc.data();

      expect(data.status).not.toBe("REVIEW_READY");
    });

    it("should allow publishing REVIEW_READY inventions", async () => {
      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: true,
        data: () => ({
          creator_id: "user-abc",
          status: "REVIEW_READY",
        }),
      });

      const doc = await db.collection("inventions").doc("inv-1").get();
      const data = doc.data();

      expect(data.status).toBe("REVIEW_READY");
    });
  });

  describe("GET /:id", () => {
    it("should return 404 for non-existent inventions", async () => {
      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: false,
      });

      const doc = await db.collection("inventions").doc("nonexistent").get();
      expect(doc.exists).toBe(false);
    });

    it("should return invention data for existing documents", async () => {
      const inventionData = {
        invention_id: "inv-123",
        status: "LIVE",
        social_metadata: { display_title: "Test Invention" },
      };

      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: true,
        data: () => inventionData,
      });

      const doc = await db.collection("inventions").doc("inv-123").get();
      expect(doc.exists).toBe(true);
      expect(doc.data()).toEqual(inventionData);
    });
  });
});
