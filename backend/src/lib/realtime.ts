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
