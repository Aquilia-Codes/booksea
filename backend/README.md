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

Scaffolded 2026-09-01, tested against a real local Postgres 2026-09-01.
`npx prisma migrate deploy` applies cleanly (verified: all tables, the
`tour_totals` view, `pgcrypto`/`btree_gist` extensions, and the gist
exclusion constraint on `tours` all land correctly).

Smoke-tested with `npm run seed:smoke` (seeds a tier/company/user/boat and
prints a ready-to-use access token — see `scripts/seed-smoke-test.ts`)
against a running `npm run dev`:

- `GET /me`, `GET /boats/:id`, `POST /boats/:id/tours` — working.
- Tour overlap correctly rejected with 409 (gist exclusion constraint).
- `POST /tours/:id/groups` capacity check (row-locked transaction) correctly
  allows a group within capacity and rejects one that would exceed it (409).
- Confirmed the three original Firestore bugs are fixed by the schema:
  `tour_totals` view correctly aggregates `filled`/`price` across groups
  (old bug: overwritten on edit), and `arrived` correctly drops back to 0
  when the arrived group is deleted (old bug: never decreased).
- **Found and fixed one real bug this testing caught that `tsc` didn't**:
  `POST /tours/:id/groups` spread the parsed request body (containing
  `countryDialogCode`, the Dart-facing field name) straight into
  `bookingGroup.create()`, which expects `countryDialCode`. TypeScript's
  excess-property checking doesn't apply through a spread, so this only
  surfaced as a Prisma runtime error, not a compile error. Fixed by
  destructuring the field and renaming it explicitly (same pattern already
  used in `PATCH /groups/:id`).

Still open:

- Google OAuth flow (`POST /auth/google`) not yet tested against a real
  Google idToken — needs the Flutter client wired up to try this end to end.
- Decide whether `PATCH /me` should stay this restrictive (see the comment in
  `src/routes/me.ts` — the old Firestore `setUser` could set
  `hasAccess`/`isAdmin`/`isOwner`, which isn't safe to expose to a plain
  self-service PATCH; nothing grants those flags yet).
- Render deployment itself not yet done (local Postgres only so far).
