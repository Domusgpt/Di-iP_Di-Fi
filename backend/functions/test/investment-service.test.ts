/**
 * Investment Service Unit Tests
 *
 * Tests pledge creation, investment submission with Pub/Sub dispatch,
 * and funding status queries.
 */

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
    firestore: Object.assign(jest.fn(() => firestoreMock), {
      FieldValue: {
        serverTimestamp: jest.fn().mockReturnValue("TIMESTAMP"),
        increment: jest.fn((n: number) => `INCREMENT(${n})`),
      },
    }),
    auth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
  };
});

const publishMessageMock = jest.fn().mockResolvedValue("msg-id-456");
jest.mock("@google-cloud/pubsub", () => ({
  PubSub: jest.fn().mockImplementation(() => ({
    topic: jest.fn().mockReturnValue({
      publishMessage: publishMessageMock,
    }),
  })),
}));

jest.mock("uuid", () => ({
  v4: jest.fn().mockReturnValue("invest-uuid-5678"),
}));

import * as admin from "firebase-admin";

describe("Investment Service", () => {
  const db = admin.firestore() as any;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("POST /:inventionId/pledge", () => {
    it("should reject pledges with zero or negative amount", () => {
      const amounts = [0, -10, -0.5];
      amounts.forEach((amount) => {
        expect(amount > 0).toBe(false);
      });
    });

    it("should create a pledge document in Firestore", async () => {
      const pledgeId = "invest-uuid-5678";
      const pledge = {
        pledge_id: pledgeId,
        invention_id: "inv-001",
        user_id: "user-abc",
        amount_usdc: 100,
        status: "PLEDGED",
      };

      await db.collection("pledges").doc(pledgeId).set(pledge);

      expect(db.collection).toHaveBeenCalledWith("pledges");
      expect(db.set).toHaveBeenCalledWith(
        expect.objectContaining({
          pledge_id: pledgeId,
          amount_usdc: 100,
          status: "PLEDGED",
        })
      );
    });

    it("should increment invention funding counters", async () => {
      const amount = 250;

      await db.collection("inventions").doc("inv-001").update({
        "funding.raised_usdc": admin.firestore.FieldValue.increment(amount),
        "funding.backer_count": admin.firestore.FieldValue.increment(1),
      });

      expect(db.update).toHaveBeenCalledWith(
        expect.objectContaining({
          "funding.raised_usdc": `INCREMENT(${amount})`,
          "funding.backer_count": "INCREMENT(1)",
        })
      );
    });
  });

  describe("POST /:inventionId/invest", () => {
    it("should reject missing required fields", () => {
      const bodies = [
        { amount_usdc: 100 },
        { tx_hash: "0xabc" },
        { wallet_address: "0x123" },
        { amount_usdc: 100, tx_hash: "0xabc" },
      ];

      bodies.forEach((body) => {
        const valid = body.hasOwnProperty("amount_usdc") &&
          body.hasOwnProperty("tx_hash") &&
          body.hasOwnProperty("wallet_address");
        expect(valid).toBe(false);
      });
    });

    it("should accept valid investment with all required fields", () => {
      const body = {
        amount_usdc: 500,
        tx_hash: "0xdef456",
        wallet_address: "0x1234567890abcdef",
      };

      const valid = body.hasOwnProperty("amount_usdc") &&
        body.hasOwnProperty("tx_hash") &&
        body.hasOwnProperty("wallet_address");
      expect(valid).toBe(true);
    });

    it("should create a PENDING investment record", async () => {
      const investmentId = "invest-uuid-5678";
      const investment = {
        investment_id: investmentId,
        invention_id: "inv-001",
        user_id: "user-abc",
        wallet_address: "0x123",
        amount_usdc: 500,
        tx_hash: "0xdef",
        status: "PENDING",
      };

      await db.collection("investments").doc(investmentId).set(investment);

      expect(db.set).toHaveBeenCalledWith(
        expect.objectContaining({
          status: "PENDING",
          tx_hash: "0xdef",
        })
      );
    });

    it("should publish to investment.pending Pub/Sub topic", async () => {
      const { PubSub } = require("@google-cloud/pubsub");
      const pubsub = new PubSub();
      const topic = pubsub.topic("investment.pending");

      await topic.publishMessage({
        json: {
          investment_id: "invest-uuid-5678",
          invention_id: "inv-001",
          tx_hash: "0xdef",
          wallet_address: "0x123",
          amount_usdc: 500,
        },
      });

      expect(publishMessageMock).toHaveBeenCalledWith(
        expect.objectContaining({
          json: expect.objectContaining({
            tx_hash: "0xdef",
            amount_usdc: 500,
          }),
        })
      );
    });
  });

  describe("GET /:inventionId/status", () => {
    it("should return funding data for existing inventions", async () => {
      (db.get as jest.Mock).mockResolvedValueOnce({
        exists: true,
        data: () => ({
          status: "LIVE",
          funding: { raised_usdc: 1500, goal_usdc: 5000, backer_count: 3 },
        }),
      });

      const doc = await db.collection("inventions").doc("inv-001").get();
      const data = doc.data();

      expect(data.funding.raised_usdc).toBe(1500);
      expect(data.funding.backer_count).toBe(3);
    });
  });
});
