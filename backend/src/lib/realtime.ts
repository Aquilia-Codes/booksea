import type { Server } from "socket.io";

// Set once from index.ts after the socket.io server is created, so route
// handlers (which don't otherwise have access to `io`) can emit change
// signals. See docs/migration-notes.md "Realtime" - we emit a signal, never
// the changed data itself; clients refetch the REST endpoint they already
// have, so there's one code path for reads.
let io: Server | null = null;

export function attachRealtime(server: Server) {
  io = server;
}

export function emitToursChanged(boatId: string) {
  io?.to(`boat:${boatId}`).emit("tours:changed");
}

export function emitSummaryChanged(boatId: string) {
  io?.to(`boat:${boatId}`).emit("summary:changed");
}

export function emitGroupsChanged(tourId: string) {
  io?.to(`tour:${tourId}`).emit("groups:changed");
}

// Every authenticated socket auto-joins its own `user:<id>` room at
// connection time (see sockets.ts) - unlike the boat/tour rooms, this
// needs no explicit join call or access check, since a user always has
// "access" to their own data. Used so a device notices when someone else
// (an owner, via PATCH /companies/:id/members/:userId) changes this user's
// own access/role/provision - AuthProvider has no other way to learn that
// happened, since it wasn't a change made through /me.
export function emitMeChanged(userId: string) {
  io?.to(`user:${userId}`).emit("me:changed");
}
