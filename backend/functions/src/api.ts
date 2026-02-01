/**
 * HTTPS API Router
 * Exposed as a single Cloud Function, routes internally via Express.
 * This is the gateway between Flutter and the backend services.
 */

import { onRequest } from "firebase-functions/v2/https";
import express from "express";
import cors from "cors";
import { inventionRoutes } from "./services/invention-service";
import { profileRoutes } from "./services/profile-service";
import { investmentRoutes } from "./services/investment-service";
import { authMiddleware } from "./middleware/auth";

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

// Public routes
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", service: "ideacapital-functions", timestamp: new Date().toISOString() });
});

// Authenticated routes
app.use("/api/inventions", authMiddleware, inventionRoutes);
app.use("/api/profile", authMiddleware, profileRoutes);
app.use("/api/investments", authMiddleware, investmentRoutes);

export const apiRouter = onRequest(
  { region: "us-central1", memory: "512MiB", timeoutSeconds: 120 },
  app,
);
