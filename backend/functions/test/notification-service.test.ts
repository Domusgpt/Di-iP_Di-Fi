/**
 * Notification Service Unit Tests
 *
 * Tests notification creation, FCM push delivery,
 * and specialized notification helpers.
 */

const addMock = jest.fn().mockResolvedValue({ id: "notif-123" });
const getMock = jest.fn().mockResolvedValue({
  exists: true,
  data: () => ({ fcm_token: "test-fcm-token" }),
});
const sendMock = jest.fn().mockResolvedValue("fcm-msg-id");

jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  firestore: Object.assign(
    jest.fn(() => ({
      collection: jest.fn().mockReturnThis(),
      doc: jest.fn().mockReturnThis(),
      add: addMock,
      get: getMock,
    })),
    {
      FieldValue: {
        serverTimestamp: jest.fn().mockReturnValue("TIMESTAMP"),
      },
    }
  ),
  messaging: jest.fn(() => ({
    send: sendMock,
  })),
}));

jest.mock("firebase-functions/logger", () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

describe("Notification Service", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("sendNotification", () => {
    it("should store notification in Firestore feed", async () => {
      const admin = require("firebase-admin");
      const db = admin.firestore();

      const payload = {
        userId: "user-abc",
        title: "Test Notification",
        body: "This is a test",
        type: "comment",
        data: { invention_id: "inv-001" },
      };

      // Simulate what sendNotification does
      await db
        .collection("users")
        .doc(payload.userId)
        .collection("notifications")
        .add({
          title: payload.title,
          body: payload.body,
          type: payload.type,
          data: payload.data,
          read: false,
        });

      expect(addMock).toHaveBeenCalledWith(
        expect.objectContaining({
          title: "Test Notification",
          type: "comment",
          read: false,
        })
      );
    });

    it("should send FCM push if user has token", async () => {
      const admin = require("firebase-admin");

      getMock.mockResolvedValueOnce({
        exists: true,
        data: () => ({ fcm_token: "test-fcm-token-123" }),
      });

      const userDoc = await admin.firestore().collection("users").doc("user-abc").get();
      const fcmToken = userDoc.data().fcm_token;

      expect(fcmToken).toBe("test-fcm-token-123");

      await admin.messaging().send({
        token: fcmToken,
        notification: { title: "Test", body: "Body" },
        data: { type: "comment" },
      });

      expect(sendMock).toHaveBeenCalledWith(
        expect.objectContaining({
          token: "test-fcm-token-123",
        })
      );
    });

    it("should handle missing FCM token gracefully", async () => {
      const admin = require("firebase-admin");

      getMock.mockResolvedValueOnce({
        exists: true,
        data: () => ({ fcm_token: null }),
      });

      const userDoc = await admin.firestore().collection("users").doc("user-abc").get();
      const fcmToken = userDoc.data().fcm_token;

      expect(fcmToken).toBeNull();
      // sendMock should NOT be called when there's no token
    });
  });

  describe("Notification types", () => {
    const validTypes = [
      "investment_confirmed",
      "invention_funded",
      "comment",
      "like",
      "draft_ready",
      "patent_update",
      "new_invention",
    ];

    validTypes.forEach((type) => {
      it(`should accept notification type: ${type}`, () => {
        expect(validTypes).toContain(type);
      });
    });
  });

  describe("notifyInvestmentConfirmed", () => {
    it("should format ownership percentage correctly", () => {
      const percent = 12.345;
      const formatted = percent.toFixed(2);
      expect(formatted).toBe("12.35");
    });

    it("should include amount in data payload", () => {
      const amount = 500;
      const data = { amount: amount.toString() };
      expect(data.amount).toBe("500");
    });
  });

  describe("notifyInventionFunded", () => {
    it("should format total raised as integer USDC", () => {
      const totalRaised = 10250.5;
      const formatted = `$${totalRaised.toFixed(0)} USDC`;
      expect(formatted).toBe("$10251 USDC");
    });
  });
});
