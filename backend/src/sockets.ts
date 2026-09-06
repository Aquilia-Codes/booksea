import type { Server, Socket } from "socket.io";
import { verifyAccessToken } from "./lib/jwt";
import { prisma } from "./lib/prisma";
import { getAccessibleTour, getBoatByName } from "./lib/authz";
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

    // Every socket automatically gets its own user room - unlike
    // boat/tour rooms, this needs no explicit join call or access check,
    // since a user always has access to their own data. See
    // lib/realtime.ts's emitMeChanged.
    socket.join(`user:${authed.data.user.id}`);

    // boatId here is the boat's *name*, not its UUID - every client caller
    // follows the same "boatId is really the name" convention the REST
    // routes use (see getBoatByName's comment in lib/authz.ts). Resolve it
    // the same way, and join using the resolved UUID so this matches the
    // room key the REST routes actually broadcast to (emitToursChanged etc.
    // are always called with the real boat.id, never the name).
    socket.on("join:boat", async (boatId: string, ack?: (ok: boolean) => void) => {
      try {
        const boat = await getBoatByName(authed.data.user, boatId);
        socket.join(`boat:${boat.id}`);
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

    // Same name->UUID resolution as join:boat, so this actually targets the
    // room the socket is really in. Best-effort: if the boat can't be
    // resolved (e.g. renamed/deleted mid-session) there's nothing to leave.
    socket.on("leave:boat", async (boatId: string) => {
      try {
        const boat = await getBoatByName(authed.data.user, boatId);
        socket.leave(`boat:${boat.id}`);
      } catch {
        // no-op
      }
    });
    socket.on("leave:tour", (tourId: string) => socket.leave(`tour:${tourId}`));
  });
}
