# Backend Migration Notes (working log)

Running log of decisions and changes made while migrating Booksea off Firebase.
Purpose: source material for the final Croatian documentation (~15-20 pages,
with screenshots) once the migration is done. Not the documentation itself —
just the raw points to turn into prose later.

## Decided tech stack (2026-09-01)

- **Backend**: Express.js + TypeScript + Prisma ORM, PostgreSQL, deployed on
  Render (web service + managed Postgres).
- **Why Postgres over MongoDB**: the data is strongly relational — companies
  own boats, boats run tours, tours hold booking groups, all foreign keys and
  joins. MongoDB is a document store, same shape as Firestore, so it would
  reproduce the exact problem being migrated away from.
- **Auth**: keep `google_sign_in` on the Flutter client exactly as-is. Client
  sends the Google `idToken` to `POST /auth/google`; Express verifies it with
  `google-auth-library` (never trust an unverified token or a client-supplied
  user id) and issues its own access + refresh JWTs.
- **Realtime**: socket.io, replacing the 4 Firestore snapshot listeners that
  feed 7 `StreamBuilder`s in the Flutter UI. Dart-side `Stream<T>` method
  signatures stay the same — the socket just feeds a `StreamController` behind
  the same interface, so no UI rewrite is needed.
- **Repository pattern reused**: `booksea_app`'s Firebase code is already
  isolated in 4 files (`firestore_database.dart`, `firestore_service.dart`,
  `firestore_path.dart`, `auth_provider.dart`) totalling ~744 of the app's
  7,448 lines. The two largest screens (`home.dart` 2,756 lines,
  `search_and_filter.dart` 2,297 lines) each have exactly one Firebase-related
  import and nothing else. `firestore_path.dart` already lists every data
  location as a class of static path builders — effectively a REST route
  table drafted in advance. This is why a straight backend swap was chosen
  over the in-progress BLoC rewrite: BLoC would rebuild every screen to get
  back to functionality the app already has. BLoC is still worth doing later,
  incrementally, screen by screen, *after* the app runs on the new backend.

## Three pre-existing bugs the new schema fixes by design

All three share one root cause: `filled`, `arrived` and `price` were
denormalized counters hand-maintained across four Firestore methods with no
transaction. In Postgres these become a `tour_totals` view — an aggregate
over `booking_groups` — so they can't drift, and stop being possible to get
wrong:

1. **Tour total overwritten on group edit** — `firestore_database.dart:267`
   computed `pastPrice - pastPrice + group.price`, which reduces to just
   `group.price`, discarding every other group's contribution to the tour.
2. **Arrival count never decreases** — `deleteGroup` decremented `filled` and
   `price` but never `arrived`; deleting a checked-in group left the tour's
   arrival count permanently inflated.
3. **`TourModel.toMap()` silently dropped `price`** — `fromMap` read it,
   `toMap` never wrote it. Only survived because Firestore's `update()`
   ignores absent keys; a `NOT NULL` column would have rejected it outright.

Also replaced: the hand-rolled tour-overlap loop in `createTour` becomes a
Postgres `EXCLUDE USING gist` constraint the database enforces itself.
**Capacity is still a race condition** even with the view — two simultaneous
bookings can each read `filled` before either writes. Group creation must be
wrapped in a transaction with `SELECT ... FOR UPDATE` on the tour row before
checking capacity.

Two perf notes: `getToursStream` currently downloads the entire tours
collection and filters client-side in Dart; `searchTours` layers more
client-side filtering on top. Both become indexed `WHERE` clauses server-side.

## Postgres schema

Source of truth: `backend/prisma/schema.prisma` (Prisma) — mirrors the SQL
below, derived from the six existing Firestore models (`BoatModel`,
`CompanyModel`, `GroupModel`, `TierModel`, `TourModel`, `TypeModel`).

Tables: `tiers`, `companies`, `users`, `boats`, `user_boats` (join table,
replaces `UserModel.boatIds`), `tour_types`, `tours` (with a `gist` exclusion
constraint on `(boat_id, tstzrange(start_time, end_time))` for overlap),
`booking_groups`. Derived view `tour_totals` computes `filled`/`arrived`/
`price` per tour. Indexes on `tours(boat_id, start_time, end_time)`,
`booking_groups(tour_id)`, `booking_groups(booker_id)`, `users(company_id)`.

`company_id` is deliberately dropped from most API paths/params — it's
derived server-side from the authenticated user's JWT, never trusted from the
URL, which is what stops one company reading another's data.

## Route map (FirestoreDatabase method -> Express endpoint)

| Old method | Endpoint | Notes |
|---|---|---|
| getUser | GET /me | From JWT subject |
| setUser | PATCH /me | |
| writeCompanyIdToUserDocument | POST /me/company | Body `{ companyCode }` |
| companyExists | — | Folded into the join above |
| getTours | GET /boats/:id/tours | `?from=&to=` |
| getToursStream | GET /boats/:id/tours | Same route + socket room |
| getSumOfPriceStream | GET /boats/:id/tours/summary | Totals + this user's provision |
| searchTours | GET /boats/:id/tours/search | `?types=&from=&to=&seats=` |
| createTour | POST /boats/:id/tours | 409 on overlap |
| updateTour | PATCH /tours/:id | |
| deleteTour | DELETE /tours/:id | Cascades to groups |
| getGroups | GET /tours/:id/groups | + socket room |
| getGroup | GET /groups/:id | |
| createGroup | POST /tours/:id/groups | 409 over capacity |
| updateGroup | PATCH /groups/:id | |
| deleteGroup | DELETE /groups/:id | |
| updateGroupHasArrived | PATCH /groups/:id/arrival | Body `{ hasArrived }` |
| getTourTypesAndBoatInfo | GET /boats/:id | Boat + its tour types |
| getTypeInfo | GET /boats/:id/tour-types/:name | |
| createBoat | POST /companies/:id/boats | |

Auth: `POST /auth/google` (verify idToken, issue JWTs), `POST /auth/refresh`,
`POST /auth/logout`.

## Realtime (socket.io)

| Room | Server event | Emitted after |
|---|---|---|
| boat:\<boatId\> | tours:changed | Tour create/update/delete |
| boat:\<boatId\> | summary:changed | Any price-affecting write |
| tour:\<tourId\> | groups:changed | Group create/update/delete/arrival |

Rule 1: authenticate the socket handshake with the same JWT and refuse a room
join for a boat the user has no `user_boats` row for — otherwise rooms leak
data across companies. Rule 2: emit a change *signal*, not the changed data —
the client refetches the REST endpoint it already has, so there's one code
path for reads and no risk of socket/REST payloads drifting apart.

Render note: WebSockets work on the free tier, but a free service sleeps
after inactivity and drops connections — client needs reconnect-with-backoff
(socket.io does this) plus a refetch on reconnect (we handle this part).

## Migration phases (ordered by dependency; each phase leaves the app runnable)

1. ~~Commit what's already open~~ — done 2026-09-01 (toolchain upgrade +
   Flutter deprecated-API fixes committed as `bce81a8`; temp auth bypass +
   these notes as `73c047e`).
2. ~~Upgrade the toolchain~~ — done, was already in the uncommitted diff:
   Gradle 8.0→9.7.1, AGP 8.1.0→9.3.0, Kotlin 2.1.0→2.4.10, google-services
   4.4.2→4.5.0, flex_color_scheme/intl bumps for Flutter 3.35.
3. Drop `Timestamp` for `DateTime` — 6 usages in the UI (all
   `Timestamp.fromDate(...)`) plus `tour_model.dart` and `type_model.dart`.
   `tour_model.dart` already parses both Timestamps and ISO strings, so it's
   half done. This is the prerequisite for `cloud_firestore` leaving later.
   Files: `models/tour_model.dart`, `models/type_model.dart`,
   `ui/home/home.dart`, `ui/search/search_and_filter.dart`.
4. Build the backend — Express + Prisma against the schema above. Seed from a
   Firestore export so development happens against real bookings, not
   invented ones (see "Open items" below re: whether that export is possible).
5. Swap the data layer — write `ApiDatabase` in
   `services/api_database.dart` with the same 20 method signatures as
   `FirestoreDatabase`, then change the one call site that constructs it.
   Nothing that calls it needs to change.
6. Swap auth — `AuthProvider` keeps its `Status` enum and `Stream<UserModel>`;
   underneath, Firebase Auth becomes the new JWT flow. Also bump
   `google_sign_in` 6.2.2 → 7.x.
7. Wire the sockets — replace polling/placeholder refetches with socket.io
   rooms. Done last: the app is fully working before this phase; it only
   makes updates faster.
8. Remove Firebase — drop `firebase_core`, `firebase_auth`, `cloud_firestore`
   from `pubspec.yaml`, delete `google-services.json`, let the compiler find
   anything left behind (including `kBypassFirebaseAuth` in
   `auth_provider.dart`, added as a temporary testing shim on 2026-09-01).

## Flutter-side impact (by file)

| File | Lines | Change |
|---|---|---|
| services/firestore_database.dart | 441 | Rewritten as api_database.dart |
| providers/auth_provider.dart | 193 | Firebase Auth -> JWT |
| services/firestore_service.dart | 71 | Replaced by an HTTP client |
| services/firestore_path.dart | 39 | Becomes the route builder |
| models/tour_model.dart | 69 | Timestamp -> DateTime |
| models/type_model.dart | 60 | Timestamp -> DateTime |
| auth_widget_builder.dart | 49 | Stream source only |
| ui/home/no_code_home.dart | 91 | One currentUser call |
| ui/home/home.dart | 2,756 | Import + 4 Timestamp calls |
| ui/search/search_and_filter.dart | 2,297 | Import + 2 Timestamp calls |
| Everything else | 1,382 | Untouched |

Roughly 900 lines are genuinely rewritten; the ~5,053 lines of screen code
(calendar, filters, booking forms, QR scanner) are touched only where they
construct a `Timestamp`.

## Backend scaffold (2026-09-01) — phase 4 in progress

Created `backend/` (Express + TypeScript + Prisma): schema, migration SQL,
Google idToken -> JWT auth with refresh rotation, all 19 data routes from the
route map, and socket.io rooms. Typechecks clean but **has not been run
against a real database** — see `backend/README.md` "Status" for exactly
what's untested. Two deviations from the artifact's plan worth noting for the
docs later:

- Added a `refresh_tokens` table (not in the original schema) so
  `POST /auth/logout` can actually revoke a token instead of only relying on
  expiry, and so refresh tokens rotate on use (old one revoked, new pair
  issued) — standard practice, closes a replay window the plan didn't spell
  out.
- `PATCH /me` is deliberately narrower than the old Firestore `setUser`: only
  `nickname`/`phoneNumber` are self-editable. The old method could set
  `hasAccess`/`isAdmin`/`isOwner`/`companyId` on the same document a client
  wrote to directly, which isn't safe to expose behind a plain authenticated
  PATCH. Nothing grants those flags yet — needs a decision (admin
  endpoint? manual DB grant for now?) before any company is usable beyond
  the owner's own account.

## Open items (need user input)

- Firestore data export: is the old `aquilia-booksea` Firebase project
  reachable at all for a one-time data dump, or are we starting fresh? Ties
  into whether backend dev seeds from real data or fixtures.
- Render account + Postgres instance not yet provisioned — needed for a real
  `DATABASE_URL` to actually test the backend above.
- Who can grant `hasAccess`/`isAdmin`/`isOwner`/company boat assignments,
  now that `PATCH /me` can't? (see "Backend scaffold" above)
- `kBypassFirebaseAuth` (auth_provider.dart) and the `Firebase.initializeApp()`
  try/catch (main.dart) are temporary testing shims from before this stack
  was decided — remove once real auth against the new backend lands (phase 6).
