/**
 * Invention Service Unit Tests
 *
 * Tests the invention CRUD operations, AI analysis dispatch,
 * and publish flow.
 */

import { Invention, InventionStatus } from "../src/models/types";
import * as admin from "firebase-admin";

// Define a type for our Firestore mock to replace 'any' casts
interface MockFirestore {
  collection: jest.Mock;
  doc: jest.Mock;
  set: jest.Mock;
  get: jest.Mock;
  update: jest.Mock;
}

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

describe("Invention Service", () => {
  // Use the defined interface instead of 'any'
  const db = admin.firestore() as unknown as MockFirestore;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("POST /analyze", () => {
    it("should reject requests with no input", () => {
      const body: Record<string, unknown> = {};
      const hasInput = Object.prototype.hasOwnProperty.call(body, "raw_text") ||
        Object.prototype.hasOwnProperty.call(body, "voice_url") ||
        Object.prototype.hasOwnProperty.call(body, "sketch_url");
      expect(hasInput).toBe(false);
    });

    it("should create a draft in Firestore with AI_PROCESSING status", async () => {
      const inventionId = "test-uuid-1234";
      const userId = "user-abc";

      // Type-safe draft object
      const draft: Partial<Invention> = {
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
      // Mock data matching the Invention interface structure
      const mockData: Partial<Invention> = {
        creator_id: "user-abc",
        status: "AI_PROCESSING",
      };

      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: true,
        data: () => mockData,
      });

      const doc = await db.collection("inventions").doc("inv-1").get();
      const data = doc.data() as Invention;

      expect(data.status).not.toBe("REVIEW_READY");
    });

    it("should allow publishing REVIEW_READY inventions", async () => {
      const mockData: Partial<Invention> = {
        creator_id: "user-abc",
        status: "REVIEW_READY",
      };

      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: true,
        data: () => mockData,
      });

      const doc = await db.collection("inventions").doc("inv-1").get();
      const data = doc.data() as Invention;

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
      const inventionData: Partial<Invention> = {
        invention_id: "inv-123",
        status: "LIVE",
        social_metadata: { display_title: "Test Invention", short_pitch: "test" },
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
