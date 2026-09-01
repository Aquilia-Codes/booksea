# booksea-backend

Express + TypeScript + Prisma/PostgreSQL replacement for booksea_app's
Firebase backend. See [../docs/migration-notes.md](../docs/migration-notes.md)
for the full plan (schema reasoning, route map, phases).

## Setup

1. `npm install`
2. Copy `.env.example` to `.env` and fill in:
   - `DATABASE_URL` — from Render (or any Postgres) once provisioned.
   - `GOOGLE_OAUTH_CLIENT_IDS` — already filled with the client IDs pulled
     from `booksea_app/android/app/google-services.json`; add the iOS/web
     client id(s) too if `google_sign_in` uses them.
   - `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` — generate with
     `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`.
3. `npx prisma migrate deploy` to apply `prisma/migrations/20260901000000_init`
   (hand-written — see the comment at the top of that file for why).
4. `npm run dev`

## Status

Scaffolded 2026-09-01: schema, auth (Google idToken -> JWT, refresh
rotation, logout), all 19 data routes from the route map, and socket.io
rooms are implemented and typecheck clean (`npx tsc --noEmit`). **Not yet
tested against a real database** — no Postgres instance exists yet. Before
relying on this:

- Provision Postgres (Render or otherwise) and run the migration.
- Exercise each route against real data, in particular the capacity-race
  transaction in `POST /tours/:id/groups` and the tour-overlap 409 in
  `POST /boats/:id/tours`.
- Decide whether `PATCH /me` should stay this restrictive (see the comment in
  `src/routes/me.ts` — the old Firestore `setUser` could set
  `hasAccess`/`isAdmin`/`isOwner`, which isn't safe to expose to a plain
  self-service PATCH; nothing grants those flags yet).
