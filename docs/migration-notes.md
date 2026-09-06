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
  incrementally, screen by screen, _after_ the app runs on the new backend.

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

| Old method                   | Endpoint                        | Notes                          |
| ---------------------------- | ------------------------------- | ------------------------------ |
| getUser                      | GET /me                         | From JWT subject               |
| setUser                      | PATCH /me                       |                                |
| writeCompanyIdToUserDocument | POST /me/company                | Body `{ companyCode }`         |
| companyExists                | —                               | Folded into the join above     |
| getTours                     | GET /boats/:id/tours            | `?from=&to=`                   |
| getToursStream               | GET /boats/:id/tours            | Same route + socket room       |
| getSumOfPriceStream          | GET /boats/:id/tours/summary    | Totals + this user's provision |
| searchTours                  | GET /boats/:id/tours/search     | `?types=&from=&to=&seats=`     |
| createTour                   | POST /boats/:id/tours           | 409 on overlap                 |
| updateTour                   | PATCH /tours/:id                |                                |
| deleteTour                   | DELETE /tours/:id               | Cascades to groups             |
| getGroups                    | GET /tours/:id/groups           | + socket room                  |
| getGroup                     | GET /groups/:id                 |                                |
| createGroup                  | POST /tours/:id/groups          | 409 over capacity              |
| updateGroup                  | PATCH /groups/:id               |                                |
| deleteGroup                  | DELETE /groups/:id              |                                |
| updateGroupHasArrived        | PATCH /groups/:id/arrival       | Body `{ hasArrived }`          |
| getTourTypesAndBoatInfo      | GET /boats/:id                  | Boat + its tour types          |
| getTypeInfo                  | GET /boats/:id/tour-types/:name |                                |
| createBoat                   | POST /companies/:id/boats       |                                |

Auth: `POST /auth/google` (verify idToken, issue JWTs), `POST /auth/refresh`,
`POST /auth/logout`.

## Realtime (socket.io)

| Room            | Server event    | Emitted after                      |
| --------------- | --------------- | ---------------------------------- |
| boat:\<boatId\> | tours:changed   | Tour create/update/delete          |
| boat:\<boatId\> | summary:changed | Any price-affecting write          |
| tour:\<tourId\> | groups:changed  | Group create/update/delete/arrival |

Rule 1: authenticate the socket handshake with the same JWT and refuse a room
join for a boat the user has no `user_boats` row for — otherwise rooms leak
data across companies. Rule 2: emit a change _signal_, not the changed data —
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
(`DEVELOPER_ERROR`) from Google's own sign-in SDK, on the _first_ attempt.
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
  addressed to _this_ client. The backend's `google-auth-library` check
  verifies the token's audience against `GOOGLE_OAUTH_CLIENT_IDS`, which
  must be a Web client id for this to work — the Android client's id
  doesn't work as a verifiable server-side audience the same way.

Updated to the new Web client id: `backend/.env` (local),
`backend/.env.example`, `render.yaml`, and the deployed Render service's
env var (done manually in the Render dashboard, not tracked in this repo).

**Caveat**: only the _local debug_ keystore's SHA-1 is registered so far.
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
- **No self-service tour _type_ creation**, same situation as company/boat
  creation - never existed, even in the old app. The "+" add-tour button
  needs at least one tour type to exist for the boat or its dropdown is
  empty. Added `backend/scripts/seed-tour-types.ts` (usage: company code,
  boat name) to seed a fixed set (Sunset/Panorama/Private, matching this
  project's actual boat) - same pattern as `bootstrap-company.ts`.
- **Found while building that script: a real timezone bug on the write
  side.** `new Date('1970-01-01T18:00:00')` (no trailing `Z`) parses as
  _local_ time in JS, but Postgres's timezone-naive `time` column round-trips
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
  handler - so it failed _silently_, printing to console but not crashing
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
and `google-services.json`). 7. Wire the sockets — replace polling/placeholder refetches with socket.io
rooms. Done last: the app is fully working before this phase; it only
makes updates faster. 8. Remove Firebase — drop `firebase_core`, `firebase_auth`, `cloud_firestore`
from `pubspec.yaml`, delete `google-services.json`, let the compiler find
anything left behind (including `kBypassFirebaseAuth` in
`auth_provider.dart`, added as a temporary testing shim on 2026-09-01).

## Flutter-side impact (by file)

| File                             | Lines | Change                         |
| -------------------------------- | ----- | ------------------------------ |
| services/firestore_database.dart | 441   | Rewritten as api_database.dart |
| providers/auth_provider.dart     | 193   | Firebase Auth -> JWT           |
| services/firestore_service.dart  | 71    | Replaced by an HTTP client     |
| services/firestore_path.dart     | 39    | Becomes the route builder      |
| models/tour_model.dart           | 69    | Timestamp -> DateTime          |
| models/type_model.dart           | 60    | Timestamp -> DateTime          |
| auth_widget_builder.dart         | 49    | Stream source only             |
| ui/home/no_code_home.dart        | 91    | One currentUser call           |
| ui/home/home.dart                | 2,756 | Import + 4 Timestamp calls     |
| ui/search/search_and_filter.dart | 2,297 | Import + 2 Timestamp calls     |
| Everything else                  | 1,382 | Untouched                      |

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
  "New → Web Service" pointed at the same database's _Internal_ connection
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
  with the _local_ `JWT_ACCESS_SECRET` to _Render's_ backend, which has a
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
  indicator from one pill (`filled / capacity`) to _two_ pills side by side
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

## Root-caused the keyboard bug: a Future recreated on every keystroke (2026-09-04)

Two earlier attempts (external `FocusNode`, disabling `IntlPhoneField`'s
autovalidate) didn't fully fix it, which was the right signal to stop
patching the field itself and look at what else was happening around it.
Found a real, independently serious bug in all four group forms (create +
edit, in both `home.dart` and `search_and_filter.dart`): the price field's
`FutureBuilder` called `widget.firestoreDatabase.getTypeInfo(...)` **directly
inline** as its `future:` argument. A `StatefulWidget`'s `build()` runs on
every `setState()` - which every keystroke in _any_ field in the form
triggers (via `_updateButtonState`) - so this created a brand new `Future`
(and fired a brand new network request) on every keystroke across the whole
form, not just the phone field. `FutureBuilder` treats a new future
identity as needing to reset to its loading state, so the price field's
slot in the `Column` was flipping between a real `TextField` and a bare
`Text('')` continuously while typing anywhere in the form - a genuine
structural change to a sibling element on every keystroke. That kind of
churn during an active IME session is a very plausible explanation for why
the keyboard closed specifically on that first real interaction. It was
also a bug in its own right regardless of the keyboard symptom: constant
redundant network requests, and `_adultCountController.addListener(...)` /
`_childCountController.addListener(...)` being called again inside the
`builder` on every rebuild, permanently stacking duplicate listeners that
were never removed.

Fixed by caching the future once in `initState()` (matching the pattern
`HomeScreen` already used correctly elsewhere in the same file) and moving
the price-calculation listeners to be attached exactly once, reading from
state fields (`_pricePerAdult`/`_pricePerChild`) populated the first time
the cached future resolves, instead of re-deriving everything from
`snapshot.data` and re-attaching listeners on every `builder` call.
Verified: `flutter analyze` clean, full smoke-test script still passes
(API layer is unaffected by this - it's purely a widget rebuild-behavior
fix). This did **not** fix the keyboard symptom either - see below - but
was still a real, worthwhile fix on its own merits (the redundant network
spam and the leaking listeners were genuine bugs).

## The keyboard bug investigation, continued: live device debugging (2026-09-04)

Rather than keep guessing, added temporary diagnostic logging (`[KBDEBUG]`
tags: a build counter, and listeners printing `FocusNode.hasFocus` and the
controller's text on every change) and watched `flutter run`'s console live
against the physical device while the user reproduced the bug. This
produced hard evidence instead of more speculation, and it overturned the
starting assumption: **`FocusNode.hasFocus` never once flipped to `false`
during the failure.** The bug was never a Flutter-level focus loss at all -
every one of the fixes up to this point (external `FocusNode`, disabled
autovalidate, the cached-future fix above) was aimed at the wrong layer.
The actual signal in the log was Android's own IME tracker:
`onRequestHide ... reason HIDE_SOFT_INPUT_BY_INSETS_API` firing shortly
after the first keystroke, followed by `onHidden` - the _operating system_
hiding the keyboard on its own initiative, not Flutter dropping focus.

This reframing led to two more real bugs, found by reading exactly what
else was happening around that log line:

1. **`openTourPopup` (both files) showed `TourPopup` via `showDialog`,
   and `openGroupAddPopup` shows the group form via a _second_, nested
   `showDialog` on top of it while the first stays mounted underneath.**
   Flutter's `Dialog`/`AlertDialog` automatically pads itself by
   `MediaQuery.viewInsets.bottom` to stay clear of _any_ open keyboard -
   including one belonging to a completely different, layered-on-top
   dialog. `TourPopup`'s dialog has a fixed-size `SizedBox` (60% of full
   screen height, computed once, never intended to change), so when it
   tried to shrink for a keyboard it would never itself display, its
   content overflowed - confirmed directly in the log
   (`RenderFlex overflowed by 1.2 pixels`, then 35 on a later attempt) at
   the exact moment the nested dialog's keyboard was animating in. First
   fix attempt (`resizeToAvoidBottomInset: false` on the _inner_ Scaffold)
   was based on a wrong assumption about which layer was shrinking and
   had zero effect - the actual fix had to go one level up, wrapping the
   dialog's content in `MediaQuery.removeViewInsets(removeBottom: true)`
   in `openTourPopup` itself. This did eliminate the overflow exception.
2. **`GroupDataStream` (both files) had the exact same "future recreated
   in `build()`" bug as the price field, but for the _existing groups
   list_ shown on `TourPopup` itself** - `getGroups(...)` was called
   inline as the `StreamBuilder`'s `stream:` argument, in a
   `StatelessWidget`, so it fired a fresh network request and reset to a
   loading state on every rebuild of the underlying `TourPopup` route -
   which the nested dialog's keystrokes were still forcing, independent
   of the `MediaQuery` fix above (a `print(snapshot.data)` left in this
   code made the churn directly visible in the log as a repeating
   `[Instance of 'GroupModel', ...]`). Fixed by converting
   `GroupDataStream` to a `StatefulWidget` and caching the stream in
   `initState()`, same pattern as the price field fix.

**Neither of these fixed the actual keyboard symptom either** - confirmed
live, `HIDE_SOFT_INPUT_BY_INSETS_API` still fires right after the first
character, even with both applied. At this point the working hypothesis
changed: the test device's logs are full of `MiuiProcessManagerServiceStub`
and `HandWritingStubImpl` lines, meaning it's running **MIUI** (Xiaomi's
Android skin), which has documented community reports of exactly this
shape of bug - a keyboard that opens and immediately closes again on the
first interaction - tied to MIUI's own "secure keyboard" input handling or
its fullscreen-gesture ("knuckle") features, not to any particular app.
Asked the user to check Settings → Additional settings → Languages & Input
for a secure-keyboard toggle, and Settings → Additional settings →
Gestures for knuckle features, and disable both to test. **Unconfirmed as
of this note** - if disabling either setting fixes it, this was never an
app bug to begin with; if not, the investigation continues. Either way,
the four bugs found along the way (redundant `getTypeInfo`/`getGroups`
network calls with leaking listeners, and the dialog-level `MediaQuery`
overflow) were real and are staying fixed regardless of how the keyboard
question resolves.

The `[KBDEBUG]` diagnostic logging (build counters, focus/text listeners)
is still in `home.dart`'s `_GroupAddPopupState` as of this note - remove it
once the keyboard question is resolved one way or the other.

## The keyboard bug investigation, concluded: it was never MIUI (2026-09-05)

The MIUI/"secure keyboard" hypothesis above turned out to be a dead end. The
user made the observation that broke the case open: the group-add form has
several other numeric-keypad fields (Adult Count, Child Count, Price - plain
`TextField`s with `keyboardType: TextInputType.number`), and _none_ of them
exhibit the bug - only the Mobile Number field does. A device/OS/IME-app-wide
quirk would affect every numeric field equally, so the bug had to be specific
to something about the `IntlPhoneField` widget itself, not the platform.

Re-reading the package source
(`intl_phone_field-3.2.0/lib/intl_phone_field.dart`) with that framing
immediately found it: the internal `TextFormField` is built with
`autofillHints: widget.disableAutoFillHints ? null : [AutofillHints.telephoneNumberNational]`,
and `disableAutoFillHints` defaults to `false`. None of the plain `TextField`s
elsewhere in the form set any `autofillHints` at all - so the phone field was
the only one opted into Android's autofill framework. Autofill interception
happens at the platform-view layer, below Flutter's widget tree entirely,
which is exactly why the earlier `[KBDEBUG]` logs showed `FocusNode.hasFocus`
never going false while the OS still hid the IME via
`HIDE_SOFT_INPUT_BY_INSETS_API` - Android's autofill service was hiding the
keyboard to show (or check for) a save-prompt/suggestion overlay on the first
text change, independent of Flutter's own focus state, and independent of
which keyboard app or OS skin was involved.

Fix: pass `disableAutoFillHints: true` to both `IntlPhoneField` usages in
`home.dart` and both in `search_and_filter.dart`. We don't rely on
system-level phone-number autofill anywhere in this app, so this costs
nothing. **Confirmed fixed on the user's physical device** - the keyboard no
longer closes after the first digit. The `[KBDEBUG]` diagnostic logging
(build counter, focus/text listeners) has been removed from
`_GroupAddPopupState` now that the bug is resolved.

## Phase 7: Flutter connected to socket.io, polling removed (2026-09-05)

The backend half of "Realtime (socket.io)" above (`sockets.ts`, `lib/realtime.ts`,
the emit calls in every mutating route) was already built and already
deployed to Render as part of the initial backend scaffold - confirmed via
`git log` showing it in the very first backend commit, with local `main`
matching `origin/main`. So this phase was entirely client-side: replacing
`ApiDatabase`'s `_pollStream` (a `while(true)` loop refetching every 8s
regardless of whether anything changed) with a real push path.

Added `socket_io_client: ^3.1.6` and a new `RealtimeClient`
(`lib/services/realtime_client.dart`) wrapping the one Socket.IO connection:

- Connects with `OptionBuilder().setAuthFn((cb) => cb({'token': ...}))` -
  `setAuthFn`, not `setAuth`, so the access token is read fresh on every
  (re)connection attempt rather than baked in once, since it rotates
  independently (see `ApiClient._refreshOnce`).
- `joinBoat`/`joinTour`/`leaveBoat`/`leaveTour` are reference-counted, not a
  plain join/leave - home.dart watches a boat's tour list and its price
  summary at the same time, both scoped to the same `boat:<id>` room, so one
  of those two leaving must not evict the other still listening.
- Rooms don't survive a reconnect (a new server-side socket session gets a
  fresh id), so `onConnect` rejoins every currently-tracked room, and
  exposes its own `onConnected` stream as a second refetch trigger alongside
  the named `*:changed` events - a signal fired while briefly disconnected
  is simply lost otherwise, and this is what catches up on it.
- `disconnect()` is called from `AuthProvider.signOut()` so a stale,
  now-unauthenticated socket doesn't linger (and so the next signed-in user
  doesn't inherit the previous session's joined rooms).

`ApiDatabase` gained one generic `_realtimeStream<T>` helper (join room on
`StreamController.onListen`, refetch on either the `changes` event or
`onConnected`, leave room on `onCancel`, same fingerprint-based dedup the
old `_pollStream` used) and all four stream methods
(`getSumOfPriceStream`/`getToursStream`/`getGroups`/`searchTours`) were
rewritten on top of it with **no signature changes** -
`searchTours` doesn't map to its own room (it's an ad-hoc filtered query),
so it reuses the boat's `tours:changed` as a proxy trigger instead.

Because `onListen`/`onCancel` line up exactly with a `StreamBuilder`
subscribing/disposing, and every call site already caches its `Stream<T>`
in `initState()` (from the polling-era rebuild fixes), **zero changes were
needed in home.dart or search_and_filter.dart** - the UI layer has no idea
the transport underneath changed from polling to push.

Verified against a local backend (Postgres running locally, `npm run dev`)
with two throwaway checks: the existing `tool/smoke_test_api_database.dart`
(exercises the initial join+fetch path via `getGroups(...).first` - also
needed a `RealtimeClient.instance.disconnect(); exit(0);` added at the end,
since an open socket connection otherwise keeps the Dart VM alive and the
script never exits) and a temporary script that subscribed to `getGroups`
as a live stream, waited for the initial empty emission, then created a
group through a _separate_ REST call and confirmed a second emission
arrived within 5 seconds purely from the socket signal - proving the push
path works, not just the initial fetch. That script was deleted after use.

Not yet done: trying this in the actual running app on a device/emulator
(only the Dart-level API surface has been verified so far, not the
`StreamBuilder`-driven UI actually re-rendering on a push).

## Phase 7 follow-up: a real join:boat bug, plus the remaining uncached streams (2026-09-05)

After testing on a device, the user reported a brief freeze and general
sluggishness. That specific report was never conclusively root-caused (could
plausibly be ordinary debug-build/shader-compilation overhead), but chasing
it surfaced two real, worth-fixing issues.

**1. `TourDataStream` (home.dart) and the search results list
(search_and_filter.dart) were still recreating their streams inline in
`build()`**, the same "Future/Stream recreated on every rebuild" anti-pattern
fixed everywhere else earlier in phase 7. Under the old polling this was
just wasteful; under socket rooms it meant a real leave+rejoin network
round-trip on every rebuild - `TourDataStream` on every date-picker change,
and the search screen on _every single filter tap_ (passenger count,
tour-type chips, dates), which is a much hotter path.

Fixed differently in each case, since the right shape of fix differs:

- `TourDataStream` was converted from `StatelessWidget` to a proper
  `StatefulWidget` caching both streams in `initState`/`didUpdateWidget`,
  only re-deriving them when `boatId` or the selected day actually changed -
  the same pattern used elsewhere in the file (`GroupDataStream`, the group
  popups' cached futures).
- The search screen's case is different: a filter change is _supposed_ to
  produce a new search, so recomputing the fetch on every rebuild is
  correct, not a bug - `searchTours` was changed from a
  `Stream<List<TourModel>>` (which owned a join + a fixed fetch) to a plain
  one-shot `Future<List<TourModel>>`, wired to a `FutureBuilder` exactly
  like the original inline call, just without the socket-room cost per
  call. A new `ApiDatabase.watchBoatTourChanges(boatId)` was added
  separately - joins the boat's room once for the screen's lifetime (via
  `initState`/`dispose`, rejoining only when the boat dropdown actually
  changes) and just triggers an empty `setState()` on a signal, which is
  what makes the already-inline `searchTours` call re-run.

**2. While re-verifying end to end, found that `getToursStream` and
`getSumOfPriceStream` had never actually been receiving push updates at
all**, despite phase 7's own verification passing. That verification only
exercised `getGroups` (joins by `tourId`, a real UUID everywhere in this
app) - it never exercised the `joinBoat` path at all, which is what
`getToursStream`/`getSumOfPriceStream`/`searchTours` all depend on. The bug:
`sockets.ts`'s `join:boat` handler called `getAccessibleBoat`, which looks a
boat up **by its UUID primary key** - but every client caller passes the
boat's _name_ (`"Catamaran"`), matching the same "boatId is really the
name" convention the REST boat routes already handle via `getBoatByName`
(see `lib/authz.ts`). So `join:boat` was silently failing (caught, acked
`false`) on every call, the socket never actually entered the
`boat:<uuid>` room, and `emitToursChanged`/`emitSummaryChanged` (which
always broadcast using the real UUID) never reached it. The initial fetch
still worked fine (plain REST, independent of socket state), which is
exactly why this went unnoticed - the tour list and price summary loaded
correctly, they just silently never got a single push update afterwards.

Fixed by resolving `join:boat`/`leave:boat` with `getBoatByName` instead of
`getAccessibleBoat`, and joining/leaving using the _resolved_ UUID so the
room key actually matches what the REST routes broadcast to. Re-verified
both the search screen's `watchBoatTourChanges` and, specifically,
`getToursStream` itself (the one home.dart actually uses) with the same
kind of throwaway "subscribe, then trigger a REST change, confirm a push
emission arrives" script used in phase 7 - both now pass. Lesson for next
time: when a stream/room is boat-scoped, verify with a boat-scoped
call specifically - the tour-scoped one passing proved nothing about it.

## Phase 8: Firebase removed entirely (2026-09-06)

With auth and realtime both fully proven against the new backend, removed
Firebase from the app completely rather than leaving it as unused dead
weight.

**Removed:**

- `pubspec.yaml`: `cloud_firestore`, `firebase_core`, `firebase_auth`.
- `lib/main.dart`: the `Firebase.initializeApp()` try/catch (it was already
  just a "keep booting if unreachable" shim from mid-migration).
- `lib/providers/auth_provider.dart`: the `kBypassFirebaseAuth` flag and its
  fake-user bypass branch - its own doc comment said to remove it "once
  confirmed working end to end," which today's testing satisfied.
- Three fully dead files: `lib/services/firestore_database.dart`,
  `firestore_service.dart`, `firestore_path.dart` - confirmed unreferenced
  by anything except each other before deleting (`ApiDatabase` replaced
  `FirestoreDatabase` everywhere back in phase 4-5).
- `android/app/google-services.json`, the `com.google.gms.google-services`
  Gradle plugin (both its `apply false` declaration in the root
  `android/build.gradle` and its application in `android/app/build.gradle`),
  and the native `firebase-bom`/`firebase-analytics`/`firebase-messaging`
  dependencies in `android/app/build.gradle` - none of the latter two had
  any corresponding Flutter plugin in `pubspec.yaml` to begin with, so they
  were already dead weight even before today. Kept `play-services-auth`/
  `play-services-base` - those back `google_sign_in`, not Firebase.
- Incidentally found and fixed a pre-existing typo while in
  `android/app/build.gradle`: its `plugins {` block was actually written as
  `herplugins {`, which is not valid Gradle syntax. Unrelated to Firebase,
  but on the exact line being edited anyway, and would have broken the
  build the next time Gradle's configuration cache was invalidated (a clean
  build, a cache clear, CI) even if left alone.

**Verified:**

- `flutter analyze`: clean, no errors.
- `flutter pub get`: resolves cleanly; `pubspec.lock` confirmed to contain
  zero firebase/cloud_firestore packages afterward.
- `flutter build apk --debug`: succeeds - this is the real test of the
  Gradle surgery (typo fix, plugin removal, dependency removal), since none
  of that is checked by `flutter analyze` at all.
- `flutter run -d windows`: app launches and reaches the running state
  (theme provider initializes, no crash) with `Firebase.initializeApp()`
  gone entirely - confirms `main.dart`'s change doesn't break startup.
- **Not yet verified**: the actual Google Sign-In handshake on a real
  Android device (no device was connected during this pass - desktop can't
  exercise it, `google_sign_in`'s Android implementation is a separate code
  path). This should still work - `google_sign_in` talks to Play Services
  directly via `serverClientId`, never through Firebase - but it's the one
  piece of this removal that genuinely needs a real device to confirm.

### Old (Firebase) vs. new (self-hosted) - structure and dataflow compared

**Data model.** Firestore was a nested document tree, walked by hand-built
path strings (`lib/services/firestore_path.dart`, now deleted):
`company/{companyId}/boats/{boatId}/tours/{tourId}/groups/{groupId}`, a
parallel `.../tourTypes/{tourTypeId}` subcollection, and a flat top-level
`users/{userId}` collection. There was no schema enforcement beyond
whatever the client happened to write - which is exactly how the three
pre-existing bugs noted earlier in this log (missing `price` field, string
vs. number counters, etc.) went unnoticed for so long. The new backend is a
normal relational schema (`backend/prisma/schema.prisma`): `companies`,
`boats`, `tours`, `booking_groups`, `tour_types`, `users` as real tables
with foreign keys, a Postgres enum for `payment_status`, a derived SQL view
(`tour_totals`) instead of hand-maintained counters, and a `gist` exclusion
constraint that makes overlapping tours on the same boat impossible to
insert at the database level rather than merely discouraged by client code.

**Auth.** The old `AuthProvider` held a live `FirebaseAuth` instance and
exposed `_auth.authStateChanges()` directly as its `user` stream - Firebase
managed the session token, its refresh, and change notification entirely
inside the SDK; the app just reacted to whatever `User?` came out the other
end. Google sign-in produced a Firebase `UserCredential` via
`GoogleAuthProvider.credential(...)`. The new flow has no such SDK backing
it: `signInWithGoogle()` gets a Google idToken exactly as before, but now
POSTs it to `/auth/google`, which this app's own backend verifies and
exchanges for this app's own JWT access/refresh pair (`backend/src/routes/auth.ts`).
Everything Firebase used to do invisibly - persisting the session,
refreshing an expiring token, deduplicating concurrent refreshes - is now
explicit application code: the refresh token in `SharedPreferences`
(`AuthProvider._persistRefreshToken`/`_tryRestoreSession`), and the
single-flight refresh dedup in `ApiClient._refreshOnce`.

**Realtime.** `FirestoreService.collectionStream`/`documentStream` wrapped
Firestore's native `.snapshots()` - a live, per-query subscription
maintained entirely by Google's infrastructure, reconnecting on its own,
requiring zero server-side code at all. Losing access to the Firebase
project meant losing that mechanism entirely, with nothing to fall back on
but re-fetching. The replacement had to be built from scratch: an initial
polling stand-in (phases 4-6), then real push via a self-hosted Socket.IO
server (phase 7) - authenticated by hand with the same JWT, scoped by hand
into per-boat/per-tour rooms, triggered by hand from each mutating route.
Firestore's version needed no application code and scaled/reconnected
transparently; the new version needed all of that written and (as phase
7's follow-up bug showed) is easy to get subtly wrong in a way that fails
silently instead of loudly.

**Authorization.** Firestore access was governed by declarative Security
Rules living in the Firebase project itself. The new backend has no
equivalent declarative layer - every route explicitly calls into
`backend/src/lib/authz.ts` (`getAccessibleBoat`/`getAccessibleTour`/
`getAccessibleGroup`) to check the caller's company/boat membership before
touching data, and the socket layer (`sockets.ts`) reuses those exact same
functions rather than any separate ruleset. More verbose, but also fully
visible and versioned in this repo rather than living in a separate
console.

**Hosting.** Firebase was fully managed - no server to run, patch, or
restart, but also no visibility into it and (as this whole migration
proves) no guaranteed continued access. The new stack is self-hosted on
Render: a real Node process that can crash, sleep (free tier), or need a
manual restart, and a real Postgres instance this project is now
responsible for backing up and eventually paying for past the 30-day free
trial - full control traded for full ownership of the operational burden.

## Members and performance (2026-09-06)

First feature built on top of the finished migration rather than as part of
it - multi-owner support, an owner-facing screen to approve/configure
company members, and a performance view (tickets/price/provision booked,
by date range). Decided multi-owner (a company can have more than one
`isOwner=true` user); needed no schema change at all - `isOwner`,
`provision`, and the `user_boats` join table already existed with no
uniqueness constraint prohibiting it, and `booking_groups.bookerId` already
linked every booking to whoever made it. All of it was purely new routes
and screens on top of an already-adequate data model.

**Design decisions** (asked and answered before building):
- Only an **owner** (not admin) can approve access, change roles, or set
  provision - keeps admins operational, owners handle people/money.
- Boat access is assigned **per member, per boat** now (not deferred) -
  uses the existing `user_boats` table properly rather than a company-wide
  on/off switch.
- Performance is **date-range filterable** from the start, not just
  all-time totals.
- Each user sees only **their own** performance; an owner additionally sees
  **everyone's** (a "team" view) - individual numbers stay private between
  staff otherwise.
- Removing a company's **last remaining owner is hard-blocked server-side**
  (409), not just a client-side warning - an ownerless company would need a
  direct database fix to recover from.

**No invite system was built.** The self-join flow already in place
(`POST /me/company`, wired to the existing company-code screen) sets a
user's `companyId` but leaves `hasAccess=false` - that's already exactly
the "pending member" state. So "adding a user" doesn't require inventing an
invite/email flow at all: joining with the code *is* the request, and the
new Members screen is simply where an owner reviews and approves it.

**Backend** (`backend/src/routes/companies.ts`, `boats.ts`,
`lib/serialize.ts`):
- `GET /companies/:id/boats` - the company's full boat list by name. Needed
  because even an owner's own `boatIds` (from `GET /me`) only reflects
  their personal `user_boats` rows, not necessarily every boat the company
  has - there was no existing "list all boats in my company" endpoint.
- `GET /companies/:id/members` / `PATCH /companies/:id/members/:userId` -
  owner-only; list and update `hasAccess`/`isAdmin`/`isOwner`/`provision`/
  boat assignments. The PATCH counts other owners before allowing
  `isOwner: false` on someone who currently has it, rejecting with 409 if
  it would hit zero.
- `GET /boats/:id/performance?from=&to=` - the caller's own ticket count/
  total booked price/provision earned, computed per-`booking_group` (not
  per-tour - each group's own price feeds the calculation, so a booker's
  number reflects only what they personally booked, not everyone's on a
  tour they happened to touch).
- `GET /boats/:id/performance/team?from=&to=` - owner-only, same shape
  grouped by every booker who has activity on that boat in the range.
- **Found but not fixed**: the existing `GET /boats/:id/tours/summary`
  endpoint's `totalProvision` calculation looks buggy by the same standard -
  it attributes a tour's *entire* price to a booker's provision if they
  booked even one group within that tour (`tour.groups.some(...)`), rather
  than just the price of their own group(s). Left alone since it predates
  this feature and wasn't part of what was asked for, but it's the same
  class of bug the new performance endpoints were deliberately built to
  avoid, and would give a visibly wrong number next to the new "your
  provision" figure if a booker ever shares a tour with someone else.

**Flutter**: new `MemberModel`/`PerformanceModel`/`TeamPerformanceEntry`,
matching `ApiDatabase` methods, and two new screens - `members_screen.dart`
(list + edit sheet with access/role/provision switches and a boat
`FilterChip` picker) and `performance_screen.dart` (date-range pickers, own
stats card, owner-only team list). Both reached from new buttons on
`settings_screen.dart`, gated on `isOwner` from the already-in-scope
`UserModel` stream where relevant - no `AuthProvider` changes needed.

**Verified** against a local backend with throwaway scripts (deleted after
use): confirmed `GET /companies/:id/boats` lists the test boat; confirmed
demoting a company's sole owner is rejected with 409 and the exact expected
message; confirmed approving a pending member (access + provision + boat
assignment) applies correctly; confirmed promoting a second user to owner
then makes demoting the *original* owner succeed (proving the "last owner"
count, not a blanket rule); confirmed a demoted owner's own token
immediately loses permission to manage members on the very next call
(re-checked per-request from the JWT-resolved user row, not cached) - this
surfaced as a test-script bug (tried to "undo" its own demotion with the
now-non-owner token) rather than a real one, and was fixed by restoring
state with the new owner's token instead; and confirmed the performance
math itself end-to-end with a real booking (3 adults + 1 child, price 300,
provision 20% → `getMyPerformance` and `getTeamPerformance` both returned
exactly tickets=4, totalPrice=300, provision=60).

Not yet tested: the actual Flutter UI on a device (only the API surface was
exercised, same caveat as every other phase's initial pass).

## Two more bugs found and fixed the same day (2026-09-06)

**1. The `totalProvision` bug flagged above is fixed.** `GET
/boats/:id/tours/summary` now sums `group.price` only for the groups the
caller themselves booked, instead of crediting the tour's entire price as
soon as they'd booked anything on it. Verified with two different accounts
booking on the *same* tour (mine: price 200, theirs: price 500, my
provision 20%) - `totalPrice` correctly stayed at 700 (the whole tour,
unaffected), while `totalProvision` came back as 40 (200 × 20%, just my own
group) instead of the old bug's 140 (700 × 20%, the whole tour). Both
accounts' groups deleted and provision reset back to 0 after.

**2. `SettingsScreen` has never actually shown a signed-in user's
nickname/provision at all** - found while investigating why the new
Members/Performance buttons weren't appearing after testing locally (user's
first guess was "I haven't committed yet," which doesn't apply: a local
`flutter run` builds straight from the working directory, not from git -
commit status only matters for what's *deployed*, e.g. to Render). The real
cause: `AuthProvider._userController` is a plain broadcast
`StreamController`, which - unlike Firebase's old `authStateChanges()` that
this replaced - never replays its last value to a subscriber that starts
listening late. `SettingsScreen`'s `StreamBuilder` only starts listening
when the user actually taps over to that tab, well after the one emission
for the current session already fired during sign-in, so it saw
`snapshot.hasData == false` forever and rendered nothing - not just the two
new buttons (which live in that same `if (snapshot.hasData)` branch), but
the nickname/provision content that's supposedly existed since before this
migration. Confirmed with the user this has "never" worked, not a
regression from today. Fixed by adding `AuthProvider.currentUser` (a
synchronous getter for the already-known current value) and passing it as
`StreamBuilder(initialData: currentUser, ...)` - `user` (the stream) is
only ever consumed in this one file, so this was safe to fix in isolation.

## Open items (need user input)

- ~~Confirm the multi-owner recommendation~~ - decided (multi-owner) and
  built, see "Members and performance."
- ~~Who can grant `hasAccess`/`isAdmin`/boat assignments day-to-day~~ - done,
  the owner-only Members screen, see "Members and performance."
- ~~`kBypassFirebaseAuth` (auth_provider.dart) and the `Firebase.initializeApp()`
  try/catch (main.dart)~~ - done, see phase 8.
- ~~The pre-existing `totalProvision` bug in `GET /boats/:id/tours/summary`~~
  - fixed, see "Two more bugs found and fixed the same day."
- The new Members/Performance screens (and the settings-screen fix) haven't
  been tried in the actual running app on a device yet, only the API
  surface for the former.
