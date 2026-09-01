import express, { type NextFunction, type Request, type Response } from "express";
import cors from "cors";
import { createServer } from "http";
import { Server } from "socket.io";
import { ZodError } from "zod";
import { env } from "./lib/env";
import { HttpError } from "./lib/http-error";
import { attachRealtime } from "./lib/realtime";
import { registerSockets } from "./sockets";

import authRoutes from "./routes/auth";
import meRoutes from "./routes/me";
import boatRoutes from "./routes/boats";
import tourRoutes from "./routes/tours";
import groupRoutes from "./routes/groups";
import companyRoutes from "./routes/companies";

const app = express();
app.use(cors({ origin: env.CORS_ORIGIN }));
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true }));

app.use("/auth", authRoutes);
app.use("/me", meRoutes);
app.use("/boats", boatRoutes);
app.use("/tours", tourRoutes);
app.use("/groups", groupRoutes);
app.use("/companies", companyRoutes);

// Central error handler - HttpError (thrown by auth/authz/validation
// throughout the routes above) maps to its intended status; anything else
// is an unexpected bug and stays a 500.
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof HttpError) {
    res.status(err.status).json({ error: err.message });
    return;
  }
  if (err instanceof ZodError) {
    res.status(400).json({ error: err.flatten() });
    return;
  }
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

const httpServer = createServer(app);
const io = new Server(httpServer, { cors: { origin: env.CORS_ORIGIN } });
attachRealtime(io);
registerSockets(io);

httpServer.listen(env.PORT, () => {
  console.log(`booksea-backend listening on :${env.PORT}`);
});
