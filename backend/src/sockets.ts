import type { Server, Socket } from "socket.io";
import { verifyAccessToken } from "./lib/jwt";
import { prisma } from "./lib/prisma";
import { getAccessibleBoat, getAccessibleTour } from "./lib/authz";
import type { User } from "@prisma/client";

interface AuthedSocket extends Socket {
  data: { user: User };
}

// Authenticate the handshake with the same access JWT the REST API uses,
// and only let a socket join a room for a boat/tour it's actually allowed
// to see - otherwise rooms are a data leak across companies (see
// docs/migration-notes.md "Realtime").
export function registerSockets(io: Server) {
  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) return next(new Error("Missing auth token"));
    try {
      const payload = verifyAccessToken(token);
      const user = await prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) return next(new Error("User not found"));
      (socket as AuthedSocket).data.user = user;
      next();
    } catch {
      next(new Error("Invalid or expired token"));
    }
  });

  io.on("connection", (socket) => {
    const authed = socket as AuthedSocket;

    socket.on("join:boat", async (boatId: string, ack?: (ok: boolean) => void) => {
      try {
        await getAccessibleBoat(authed.data.user, boatId);
        socket.join(`boat:${boatId}`);
        ack?.(true);
      } catch {
        ack?.(false);
      }
    });

    socket.on("join:tour", async (tourId: string, ack?: (ok: boolean) => void) => {
      try {
        await getAccessibleTour(authed.data.user, tourId);
        socket.join(`tour:${tourId}`);
        ack?.(true);
      } catch {
        ack?.(false);
      }
    });

    socket.on("leave:boat", (boatId: string) => socket.leave(`boat:${boatId}`));
    socket.on("leave:tour", (tourId: string) => socket.leave(`tour:${tourId}`));
  });
}
