# Backend Migration Notes (working log)

Running log of decisions and changes made while migrating Booksea off Firebase.
Purpose: source material for the final Croatian documentation (~15-20 pages,
with screenshots) once the migration is done. Not the documentation itself —
just the raw points to turn into prose later.

## Decided tech stack (2026-09-01)

- **Backend**: Express.js + TypeScript + Prisma ORM, PostgreSQL, deployed on
  Render (web service + managed Postgres). Confirmed 2026-09-01 as still the
  right call for now (matches the course-prescribed stack, maps cleanly onto
  the schema/API already built). Two caveats to plan around, not reasons to
  switch: Render's **free Postgres instance expires and is deleted after 30
  days** — fine during active development, but needs upgrading to paid (or
  periodic backup+recreate) before a semester-long project outlives it; and
  the **free web service sleeps after inactivity**, dropping open
  connections — already handled by socket.io's built-in reconnect plus a
  client refetch on reconnect, but expect a slow first request after idle
  periods when demoing.
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
3. ~~Drop `Timestamp` for `DateTime`~~ — done 2026-09-01. Turned out to be
   more than the artifact's original estimate of 6 usages: ~60 `.toDate()`
   call sites across `home.dart`, `search_and_filter.dart`, `qr_image.dart`
   and `firestore_database.dart`, plus the 6 `Timestamp.fromDate(...)`
   construction sites and the two model files. All mechanical — `TourModel`
   and `TypeModel` fields are now plain `DateTime`, `TourModel.fromMap`
   parses the ISO datetime strings the new backend sends,
   `TypeModel.fromMap` parses the `HH:mm:ss` time-only strings the backend
   sends (prefixed with a placeholder date, since only hour/minute are ever
   read via `TimeOfDay.fromDateTime`). `flutter analyze`: 0 errors (86
   pre-existing lint infos, unrelated). Also fixed in passing:
   `TourModel.toMap()` now writes `price` — this was bug #3 from the
   "defects in transit" list (see "Three pre-existing bugs" above), now
   fixed on the Flutter side too, not just the backend schema.
   `firestore_database.dart` still references `Timestamp` in its two Firestore
   `.where()` clauses — left as-is since that whole file is replaced by
   `ApiDatabase` in the next phase, not worth polishing dead code.
   Files touched: `models/tour_model.dart`, `models/type_model.dart`,
   `ui/home/home.dart`, `ui/home/qr_image.dart`,
   `ui/search/search_and_filter.dart`.
4. Build the backend — Express + Prisma against the schema above. Seed from a
   Firestore export so development happens against real bookings, not
   invented ones (see "Open items" below re: whether that export is possible).
5. ~~Swap the data layer~~ — done 2026-09-02. `services/api_database.dart`
   implements the same 19 method signatures as `FirestoreDatabase` (20 minus
   `companyExists`, dropped by design — see below), backed by
   `services/api_client.dart` (a thin `http`-based REST client with
   in-memory JWT storage and automatic refresh-on-401). Every
   `FirestoreDatabase` reference in the UI (`home.dart`,
   `search_and_filter.dart`, `qr_scanner_screen.dart`, `no_code_home.dart`,
   `auth_widget_builder.dart`, `my_app.dart`, `main.dart`, plus the stale
   `test/widget_test.dart`) was mechanically renamed to `ApiDatabase` and
   repointed to the new import — `auth_provider.dart` deliberately left
   alone, it still constructs the old `FirestoreDatabase` internally but
   that whole code path is dead while `kBypassFirebaseAuth` is on, and gets
   rewritten in phase 6 anyway. `companyExists` has no ApiDatabase
   equivalent: the backend folds that check into `POST /me/company` itself
   (404 if the code doesn't match), so there's nothing left to check
   separately.

   **Streams are polling placeholders** (`getToursStream`,
   `getSumOfPriceStream`, `getGroups`, `searchTours`): each re-runs the
   matching REST call every 5s via a shared `_pollStream` helper. Same
   `Stream<T>` signatures as before, so no `StreamBuilder` call site
   changes — phase 7 swaps the implementation for socket.io push without
   touching callers.

   **Verified against the real local backend**, not just typechecked:
   `flutter analyze` is 0 errors, and a throwaway script
   (`tool/smoke_test_api_database.dart`, run via `dart run ... <token>`,
   token from `backend/npm run seed:smoke`) exercised all the write/read
   paths — getUser, getTourTypesAndBoatInfo, createTour, getTours,
   createGroup, updateGroupHasArrived, getGroups, delete cleanup — against
   the live database. This caught three more real bugs before they could
   surface at runtime in the app:

   1. **Boat "id" was actually always a name.** The old Firestore backend
      used `boats.name` as the Firestore document id, so
      `AuthProvider.boatIds` (and every `boatId` parameter threaded through
      `FirestoreDatabase`) was always a human-readable string, used
      directly as both value and label in the two boat dropdowns. The new
      Postgres schema gave boats a real UUID `id`, which would have broken
      those dropdowns silently (they'd show/select UUIDs). Fixed on the
      **backend**, not the client: added `getBoatByName` in
      `backend/src/lib/authz.ts`, which resolves boat-facing routes
      (`GET/POST /boats/:id...`) by `(companyId, name)` instead of the
      primary key, and changed `/me`'s `boatIdsFor` to return
      `boat.name` instead of `userBoat.boatId`. Routes that already have a
      real boat UUID in hand (resolving a tour's/group's `boatId` foreign
      key) still use the original id-based `getAccessibleBoat` — only the
      URL-facing lookup changed. Zero Flutter-side changes needed.
   2. **`UserModel.fromMap`'s `companyId` would crash for a brand-new
      user.** The API sends `companyId: null` (nullable in Postgres) before
      someone joins a company; the field is non-nullable `String` in
      `UserModel`. Fixed with `data['companyId'] ?? ''`.
   3. **`TourModel`/`GroupModel`'s `price` field would crash on a
      whole-number price.** `double price` assigned directly from a decoded
      JSON number throws in Dart when that number has no decimal point
      (e.g. `0`, which decodes as `int`, not `double`) — exactly the value
      a freshly created tour/group has. `TypeModel` already guarded against
      this for its own price fields; `TourModel`/`GroupModel` didn't. Fixed
      both with `(data['price'] as num).toDouble()`. Also fixed
      `UserModel.provision` the same way (`.round()` instead, since it's an
      `int`) since the backend's `provision` column allows decimals even
      though the Dart model doesn't.

   Not yet tested: `PATCH /me`, `updateTour`, `updateGroup`, `deleteTour`
   cascade-to-groups, `searchTours`, `createBoat`, `writeCompanyIdToUserDocument`
   — the smoke script didn't cover every method, only enough to validate the
   client/server contract end to end. Full coverage happens naturally once
   the app itself is driven manually (phase 6+).
6. ~~Swap auth~~ — done 2026-09-02, with one caveat (see below).
   `AuthProvider` (`lib/providers/auth_provider.dart`) was rewritten from
   scratch: keeps the exact same `Status` enum and `Stream<UserModel> user`
   the UI already consumes, but underneath, `google_sign_in` gets an
   `idToken` and POSTs it to `/auth/google` instead of handing it to
   Firebase. Also added: session persistence across cold starts (the
   refresh token is stored in `SharedPreferences` and silently redeemed on
   startup via `ApiClient.refreshWithToken` — Firebase Auth used to give
   this for free, so it needed an explicit replacement), and
   `AuthProvider.refreshUser()` (public) replacing the old direct
   `onAuthStateChanged(firebaseUser)` re-trigger call in
   `no_code_home.dart` after a company code is submitted.
   `settings_screen.dart`'s `authUser?.photoURL` (a Firebase `User` field)
   became `authProvider.photoUrl`, populated straight from
   `GoogleSignInAccount.photoUrl` on sign-in — no backend round trip needed
   for it. **`google_sign_in` was NOT bumped to 7.x** — the artifact
   suggested reusing a migration "already solved in the BLoC repo", but no
   such repo/reference was available here, and 7.x is a real breaking API
   redesign (no more `GoogleSignIn()` constructor, different auth flow
   entirely). Given 6.2.2's `signIn()`/`.authentication`/`.idToken` still
   work fine and nothing forces the upgrade, it was left alone rather than
   risk an unverifiable rewrite of the login button on top of everything
   else in this phase. Worth revisiting later on its own.

   `flutter analyze`: 0 new errors (96 total, all pre-existing-pattern
   lint infos plus prints in throwaway test scripts). Verified for real,
   not just typechecked: exported `issueTokens` from `backend/src/routes/
   auth.ts` so `seed-smoke-test.ts` could mint a real access+refresh pair,
   then exercised `POST /auth/refresh` (rotates correctly; the old token
   is rejected with 401 immediately after) and `POST /auth/logout`
   (revokes; the revoked token can no longer refresh) directly against the
   live database — this is the first time those two endpoints were tested
   at all, not just `/auth/google`.

   **What's still genuinely untested: the interactive Google sign-in
   button itself** (`POST /auth/google` with a real idToken). That
   requires tapping through Google's actual OAuth consent screen on a
   running device/browser, which isn't something achievable in this
   environment — the code has been reviewed carefully (verifies the
   idToken with `google-auth-library` against `GOOGLE_OAUTH_CLIENT_IDS`,
   upserts the user by `googleSub`, issues tokens the same way the tested
   refresh/logout paths already validated) but hasn't been click-tested.
   **Please test the actual "Login" → Google button flow in a running app
   before considering this phase fully done.** `kBypassFirebaseAuth`
   (still in `auth_provider.dart`, default `false` now) is there as a
   fallback switch if that flow needs more work — flip it to `true` to go
   back to the fake-user bypass without losing anything.

## Google OAuth: moved to a fresh, independently-owned project (2026-09-04)

The click-test above surfaced a real problem: `ApiException: 10`
(`DEVELOPER_ERROR`) from Google's own sign-in SDK, on the *first* attempt.
This happens entirely client-side, before any request reaches our backend —
it means the certificate signing the app build isn't registered against an
OAuth client Google recognizes, so the sign-in screen refuses to open at
all.

The OAuth clients in the original `google-services.json` belong to the old
`aquilia-booksea` Firebase project, which a teammate (not this session's
user) owns access to. Rather than route every fingerprint change through
someone else — especially given that project is already being abandoned
(see "Decisions made 2026-09-01": Firestore export is off the table,
starting fresh) — registered a **new, independently-owned Google Cloud
project** with its own OAuth clients instead. Fully decoupled from the old
project; project number `865744272369` vs. the old `683257674665`.

Two OAuth clients were needed, not one — worth remembering why:
- **Android client** (package `codes.aquilia.booksea_app` + the local
  debug keystore's SHA-1 fingerprint) — this is what was actually missing,
  and what the `DEVELOPER_ERROR` was about. It's what lets Google's SDK
  agree to show the sign-in screen for this specific app build at all.
- **Web application client** (`865744272369-atobvfr5mo0s5prs63v99rg5872ehgp2.apps.googleusercontent.com`,
  no JS origins/redirect URIs needed — it's never used for an actual
  browser redirect flow) — passed as `serverClientId` to `GoogleSignIn()`
  in `lib/providers/auth_provider.dart`, so the idToken Google issues is
  addressed to *this* client. The backend's `google-auth-library` check
  verifies the token's audience against `GOOGLE_OAUTH_CLIENT_IDS`, which
  must be a Web client id for this to work — the Android client's id
  doesn't work as a verifiable server-side audience the same way.

Updated to the new Web client id: `backend/.env` (local),
`backend/.env.example`, `render.yaml`, and the deployed Render service's
env var (done manually in the Render dashboard, not tracked in this repo).

**Caveat**: only the *local debug* keystore's SHA-1 is registered so far.
A release build (Play Store, or any signed build handed to someone else)
uses a different certificate with a different SHA-1, which will hit the
same `DEVELOPER_ERROR` until that fingerprint is added too (same Android
OAuth client supports multiple fingerprints, or add a second client) —
not needed until a release build actually exists.

## First real login, and two bugs it surfaced (2026-09-04)

Google login confirmed working end to end on a physical device after the
OAuth project fix above. Two follow-on issues, both found by actually using
the app rather than by review:

- **No self-service company creation** — never existed, not even in the old
  Firestore app (`no_code_home.dart` only ever had "enter a code," no
  "create a company" flow), so a fresh user has nowhere to go after signing
  in. Added `backend/scripts/bootstrap-company.ts` (usage: email, company
  name, company code, boat name, boat capacity) as the stand-in for the
  admin-facing flow that doesn't exist yet (see "Open items"). Run once
  against the live Render database (via its External connection URL,
  temporarily set as `$env:DATABASE_URL` in the user's own terminal rather
  than shared in chat) to grant the real user owner+admin access to a
  "Booksea" company with a "Catamaran" boat.
- **Profile picture missing after any session restore, not just the first
  login.** `AuthProvider` was setting `photoUrl` from
  `GoogleSignInAccount.photoUrl` only inside `signInWithGoogle()` - fine
  for a fresh interactive sign-in, but `_tryRestoreSession()` (the normal
  path on every subsequent app open, using the saved refresh token) never
  went anywhere near `GoogleSignIn` and so never set it. Fixed at the
  source instead of patching around it: Google's verified idToken already
  carries a `picture` claim, so `POST /auth/google`
  (`backend/src/routes/auth.ts`) now stores it on the user row
  (`photo_url` column, migration `20260904000000_add_user_photo_url`),
  `GET /me` returns it, and `AuthProvider.photoUrl` reads it from the
  fetched `UserModel` instead of a separate ephemeral field. Works
  regardless of which path (fresh sign-in or restore) populated the
  session.

## Pre-existing (non-migration) bugs found while testing the running app (2026-09-04)

- **Date picker had a hardcoded, now-expired window.**
  `InfiniteDatePickerState` (`lib/ui/home/home.dart`) hardcoded
  `startDate = DateTime(2025, 1, 1)` / `endDate = DateTime(2026, 2, 1)` -
  once real time passed the fixed end date, the horizontal date scroller
  had nothing left to show, so "today" was literally unreachable. Not
  introduced by the migration (untouched by the Timestamp->DateTime pass),
  just invisible until now. Fixed to compute a rolling window (1 year
  back/forward from whenever the widget actually initializes) instead of
  fixed calendar dates.
- **No self-service tour *type* creation**, same situation as company/boat
  creation - never existed, even in the old app. The "+" add-tour button
  needs at least one tour type to exist for the boat or its dropdown is
  empty. Added `backend/scripts/seed-tour-types.ts` (usage: company code,
  boat name) to seed a fixed set (Sunset/Panorama/Private, matching this
  project's actual boat) - same pattern as `bootstrap-company.ts`.
- **Found while building that script: a real timezone bug on the write
  side.** `new Date('1970-01-01T18:00:00')` (no trailing `Z`) parses as
  *local* time in JS, but Postgres's timezone-naive `time` column round-trips
  through Prisma as UTC-anchored - so without the `Z`, every seeded time
  came back an hour off (18:00 in, 17:00 out) on this dev machine. Fixed by
  always constructing these as explicit UTC (`...T18:00:00Z`). Only affects
  this seed script for now since it's the only thing that writes tour type
  times - worth remembering if a real "create/edit tour type" endpoint gets
  built later.
- **`backend/tsconfig.json`'s `include` was `["src"]` only** - `scripts/`
  was never actually covered by any `tsc` invocation, including the
  "typecheck backend" step done after every other change so far in this
  migration. Added `tsconfig.scripts.json` (extends the base config,
  widens `rootDir`/`include` to cover `scripts/` too, `noEmit`) and a
  `npm run typecheck` that runs both. Once added, `scripts/` typechecked
  clean - the IDE-reported errors that prompted this (missing `process`,
  possibly-null `company`/`boat`) were artifacts of the IDE analyzing those
  files with no project config at all, not real bugs, but the coverage gap
  itself was real and is what mattered here.
- **`TypeModel.options` crashed on every parse** with
  `type 'List<dynamic>' is not a subtype of type 'List<String>?'` - JSON
  arrays always decode as `List<dynamic>`, which Dart doesn't implicitly
  narrow to `List<String>`. This fired on every Home screen load (via
  `getTourTypesAndBoatInfo`, called through a bare `.then()` with no error
  handler - so it failed *silently*, printing to console but not crashing
  visibly, leaving `types` empty) and again, visibly this time, whenever
  tour creation touched `getTypeInfo`. Fixed with an explicit
  `.cast<String>()`.
- **`TourModel.toMap()` sent a local-time string the backend always
  rejected.** The tour-creation UI builds `startTime`/`endTime` via the
  local `DateTime(...)` constructor (matches the picked date + time-of-day
  from the type), and `toMap()` called plain `.toIso8601String()` on it -
  which for a non-UTC `DateTime` omits any timezone marker entirely. The
  backend's `z.string().datetime()` (zod) requires one, so every
  `createTour`/`updateTour` call failed validation. This is exactly the
  kind of bug the `tool/smoke_test_api_database.dart` script was supposed
  to catch, and didn't - because that script builds its test tour with
  `DateTime.utc(...)`, sidestepping the exact code path the real UI uses.
  Fixed by adding `.toUtc()` before formatting; updated the smoke-test
  script to use a local `DateTime(...)` on purpose so it actually exercises
  this path.

## Polling-related bugs found once several screens were used together (2026-09-04)

Reported together, but all four traced back to one root cause:

- Tour cards visibly "blinking" on every refresh.
- Switching between two dates reloading all groups from scratch.
- Groups occasionally appearing to get wiped by a refresh.
- The whole app failing after a while with a 401 "missing bearer token"
  error, effectively logging the session out.

**Root cause of the 401**: several screens poll independently (tours,
summary, groups - each `ApiDatabase` stream call sets up its own timer, see
`_pollStream`), all sharing one `ApiClient` and therefore one access token.
That token expires for all of them at the same moment (~15 min after
login). Since refresh tokens rotate on use (old one revoked - see
`backend/src/routes/auth.ts`), if two pollers each hit 401 around the same
moment and each independently calls `POST /auth/refresh`, the first one's
rotation invalidates the refresh token before the second one's request
lands - so the second "fails" and wipes out the good tokens the first one
just obtained, via `clearTokens()`. Net effect: a working session
spontaneously logs itself out, with no error surfaced to the user beyond
a generic 401. Fixed in `lib/services/api_client.dart` by making refresh
single-flight (`_refreshOnce`/`_refreshInFlight`): concurrent 401s now
await one shared `/auth/refresh` call instead of racing separate ones.
This likely also explains the "groups wiped" report - not actual data
loss, but the auth failure making a poll tick briefly show an
error/empty state.

**Root cause of the blinking/reload feel**: `_pollStream` (`api_database.dart`)
unconditionally re-emitted a freshly-fetched value every 8s (was 5s),
even when it was identical to the last one - every tick rebuilt the
`StreamBuilder`, whether or not anything had actually changed. Added an
optional `fingerprint` function to `_pollStream` (JSON-encodes each
model's `.toMap()` for comparison) so a poll only emits when the data
actually differs from the last emission; wired into all four polling
methods (`getToursStream`, `getSumOfPriceStream`, `getGroups`,
`searchTours`). This is a real fix, not just a band-aid - genuine changes
(like a newly-created group) still propagate on the next tick as normal.
The per-date group reload on switching dates is expected given the current
per-widget polling design and wasn't specifically addressed - full
elimination of both the interval and any refetch-on-widget-rebuild waits
for phase 7 (socket.io push, see the phase list above), which these fixes
were always meant to be temporary standing for.

`firestore_database.dart`/`firestore_service.dart`/`firestore_path.dart`
are now fully orphaned — nothing imports them anymore — but left in
place rather than deleted, matching the plan's phase 8 ("remove
Firebase" comes last, together with dropping the pubspec dependencies
   and `google-services.json`).
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

## Decisions made 2026-09-01

- **Firestore data export: not possible.** The old `aquilia-booksea` Firebase
  project is off-limits (access lost). The new backend starts from an empty
  database — no seed/import step, backend dev and testing use fixtures.
- **Render is live** (deployed manually, not via the `render.yaml`
  blueprint — the Postgres instance was created by hand first via
  "New → PostgreSQL", so the web service was then also created by hand via
  "New → Web Service" pointed at the same database's *Internal* connection
  URL, rather than letting the blueprint provision a second, separate
  database). Root directory `backend`, build command
  `npm install && npm run prisma:generate && npm run build`, start command
  `npm run prisma:migrate && npm start` (chains the migration into every
  deploy — safe, `prisma migrate deploy` is idempotent). Live at
  `https://booksea.onrender.com`; `GET /health` returns `{"ok":true}` and
  `GET /me` correctly 401s without a token, confirming the deployed app,
  its Postgres connection, and the migration all worked. `ApiClient.baseUrl`
  (`booksea_app/lib/services/api_client.dart`) now points here instead of
  localhost/LAN — swap it back for local dev, see the comment on that field.
  Added a plain `GET /` handler to `backend/src/index.ts` (previously
  404'd, which looked broken when opening the bare URL in a browser -
  the CSP errors seen when doing that were Render's own interstitial page,
  not anything from our server).
  Caveat carried over from the free-tier notes above: this Postgres
  instance expires after 30 days unless upgraded.
- **Roles clarified**: a company can have multiple bookers (people who work
  for it and create/manage bookings); admins can grant a person `hasAccess`
  to join a company's group of bookers. This confirms the role model the
  schema already has (`hasAccess`, `isAdmin`, `isOwner` per user).
- **Multi-owner: leaning yes, not yet built.** User was unsure whether
  allowing more than one owner per company is safe, versus a single owner
  (some people don't want to handle setup themselves and hand it to someone
  else). Assessment: performance impact is negligible either way (`isOwner`
  is a single boolean check, O(1) per request). Security-wise the tradeoff is
  accountability, not raw risk — every owner has unrestricted control (delete
  company, reassign any role, see all financials), so more owners means more
  accounts whose compromise is total, with no single accountable person.
  Recommendation: allow multiple owners (serves the "delegate the setup"
  case directly), but only let an existing owner promote someone else to
  owner (never self-claimed), and log changes to `isOwner`/`isAdmin` for an
  audit trail. **Not implemented yet** — waiting on user confirmation before
  touching the schema/routes for this.

## Backend tested against a real database (2026-09-01)

Installed local PostgreSQL 18, applied the migration, ran the full
create/read/update/delete flow through the actual HTTP API using a seed
script (`backend/scripts/seed-smoke-test.ts`, `npm run seed:smoke`) that
creates a test tier/company/user/boat and prints a valid access token
(bypasses needing a real Google idToken for this kind of testing). See
`backend/README.md` "Status" for the full list of what was exercised.

Headline result: the three original Firestore bugs (tour total overwritten
on edit, arrived count never decreasing, price silently dropped) are
confirmed fixed by the `tour_totals` view design — verified by directly
reproducing the old bug scenarios and watching the numbers come out correct.

Also caught a real bug during this testing that `tsc` did not catch:
`POST /tours/:id/groups` spread the request body (which uses the
Dart-facing field name `countryDialogCode`) straight into Prisma's
`bookingGroup.create()`, which expects `countryDialCode`. TypeScript's
excess-property checking doesn't apply through an object spread, so the
mismatch only surfaced as a Prisma runtime validation error. Fixed by
destructuring and renaming the field explicitly, matching the pattern
already used in `PATCH /groups/:id`. Worth remembering as a general
lesson for the rest of this backend: any route that spreads a
Zod-validated body into a Prisma `data:` object is a place where a
Dart/Prisma field-name mismatch can hide from the type checker — worth
double-checking each one by hand rather than trusting `tsc --noEmit` alone.

## Group creation bugs found once the polling fixes let testing continue (2026-09-04)

- **Phone number field closed the keyboard after the first digit.** A known
  class of Flutter bug (see flutter/flutter#96345, "Focus is lost on
  TextField when executing setState(), when parent is changed between
  states"): the group forms call `setState()` from a controller listener on
  every keystroke (to enable/disable the submit button), and `IntlPhoneField`
  was left to create its own internal `FocusNode` - which isn't guaranteed
  to survive that rebuild pattern. Checked first whether `intl_phone_field`
  itself was outdated (it wasn't - `3.2.0` is the current latest on pub.dev)
  and read its actual source (no `didUpdateWidget` reset logic, so the bug
  wasn't inside the package itself). Fixed by giving each `IntlPhoneField`
  an externally-owned, stable `FocusNode` instead of letting it create its
  own - the standard mitigation for this bug class. Applied to both the
  create and edit group forms, in both `home.dart` and
  `search_and_filter.dart` (4 places total).
- **Every group creation failed validation - a real design mismatch, not a
  typo.** The backend's `PaymentStatus` enum was invented during initial
  schema design (`unpaid`/`partial`/`paid`) without checking what the
  Flutter UI's dropdown actually offered (`Paid`/`Reserved`/`Cancelled`,
  a booking-status concept, not just paid-or-not). Every submission was
  rejected by zod since the two value sets never overlapped at all. Fixed
  the **backend** to match the app's real, pre-existing design rather than
  changing the UI: `PaymentStatus` is now `paid`/`reserved`/`cancelled`
  (lowercase, migration `20260904010000_fix_payment_status_values` - drops
  and recreates the enum, clearing `booking_groups` first since only
  test/smoke data existed anywhere so far). Flutter side: dropdown labels
  and the `'Paid'` default are unchanged; the app lowercases the value when
  sending (`_paymentStatusController.text.toLowerCase()`) and capitalizes
  it back (new `_titleCase` helper) when loading an existing group into the
  edit form, so the dropdown's exact-case items still match. 4 call sites
  across both files.
- **The smoke-test tool itself gave a false failure signal while debugging
  the above** - `dart run tool/smoke_test_api_database.dart` failed every
  request with 401 even with a freshly-minted, curl-verified-valid token.
  Cause: `ApiClient.baseUrl` now defaults to the deployed Render backend
  (changed a few turns ago for the real app), and the script never
  overrode it back to `localhost:4000` - so it was sending a token signed
  with the *local* `JWT_ACCESS_SECRET` to *Render's* backend, which has a
  different secret and correctly rejected the signature. Not a code bug,
  a stale test fixture; fixed by having the script set
  `ApiClient.baseUrl = 'http://localhost:4000'` explicitly at startup,
  since its whole purpose is testing against a local backend.

  All of the above verified together via one full run of that corrected
  script against the local DB, after also applying the migration and
  updating `tours.ts`/`groups.ts`'s zod schemas: getUser, boat+type
  fetch, createTour (local-time DateTime, exercising the earlier
  `.toUtc()` fix), createGroup (with `paymentStatus: 'paid'`, exercising
  this fix), arrival update, and cleanup all passed end to end.

## UI fixes and a new feature, group-creation testing round 2 (2026-09-04)

- **Phone field keyboard-closing bug: only partially fixed.** The
  `FocusNode` fix (see above) didn't fully resolve it — user reports the
  keyboard still closes after the first digit, but the field is then usable
  normally after tapping back in. Deferred rather than continuing to guess
  without a live device to inspect (added to Open items below) — not a
  blocker, just an annoyance for now.
- **"Free spaces" pill overflowing once a tour has any arrivals.** In
  `home.dart`'s tour card, `tour.arrived > 0` switches the capacity
  indicator from one pill (`filled / capacity`) to *two* pills side by side
  (`arrived / filled` and `capacity - filled`) inside the same fixed
  `Expanded(flex: 1)` space that only ever fit one - the two pills plus
  their padding and gap don't fit, causing a classic Flutter "RenderFlex
  overflowed by N pixels" error. `search_and_filter.dart` has the same
  `arrived > 0` branch but only ever shows one pill there, so it wasn't
  affected. Fixed by wrapping the two-pill `Row` in
  `FittedBox(fit: BoxFit.scaleDown)`, which shrinks the pills to fit
  available space instead of overflowing - guaranteed not to error
  regardless of exact screen width/font metrics.
- **New feature: overbooking is now allowed, with confirmation.** Boats
  routinely get booked a little over nominal capacity in practice (smaller
  people, kids not taking a full seat) - the hard capacity block on group
  creation/editing didn't reflect how this is actually used. Added a
  confirmation popup ("This would put the tour at X / Y. Add the group
  anyway?") that appears only when the count would exceed capacity; on
  confirmation the request is sent with a new `allowOverbook: true` flag.
  Backend (`createGroupBody` in `tours.ts`) still rejects overbooking by
  default - `allowOverbook` has to be explicitly set, so this can't happen
  by accident, only by an informed choice at the point of booking. Applied
  to both create and edit group flows, in both `home.dart` and
  `search_and_filter.dart` (new shared `_confirmOverbook` helper per file).
  Verified via curl: the same request that 409s without the flag succeeds
  (201) with it.

## Open items (need user input)

- **Phone number field still briefly loses keyboard focus** on the first
  digit typed (tapping back in works fine after). The `FocusNode` fix above
  didn't fully resolve it; needs a live device to actually inspect what
  Flutter is doing on that first rebuild, which wasn't available while
  diagnosing this. Not blocking - just an annoyance.
- Confirm the multi-owner recommendation above (or pick single-owner) before
  it's built into the schema/`companies`/`users` routes.
- Who can grant `hasAccess`/`isAdmin`/boat assignments day-to-day — a real
  admin-facing endpoint doesn't exist yet, only the data model supports it.
- `kBypassFirebaseAuth` (auth_provider.dart) and the `Firebase.initializeApp()`
  try/catch (main.dart) are temporary testing shims from before this stack
  was decided — remove once real auth against the new backend lands (phase 6).
