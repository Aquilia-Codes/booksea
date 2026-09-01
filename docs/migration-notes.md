# Backend Migration Notes (working log)

Running log of decisions and changes made while migrating Booksea off Firebase.
Purpose: source material for the final Croatian documentation (~15-20 pages, with
screenshots) once the migration is done. Not the documentation itself — just the
raw points to turn into prose later.

## Status: planning / not started

The target backend has not been decided yet. Nothing in the codebase currently
talks to a replacement backend — `cloud_firestore` and `firebase_auth` are still
the only data/auth layer (see `pubspec.yaml`).

## What "Firebase is dead" means right now

Unconfirmed/untested as of 2026-09-01. The Firebase project is `aquilia-booksea`
(see `android/app/google-services.json`). Login was unreachable, so testing never
got past the auth gate — unclear whether Firestore reads/writes still work.
**TODO before the real migration:** check the Firebase console (billing/quota
status, project still exists?) to know exactly what's salvageable (e.g. can we
still export Firestore data for a one-time migration dump?).

## Temporary changes made for local testing (2026-09-01)

These are stopgaps to unblock UI testing, NOT part of the actual migration.
Must be reverted/removed once real auth against the new backend exists.

- `lib/providers/auth_provider.dart`: added `kBypassFirebaseAuth` (currently
  `true`). When on, `AuthProvider` skips `FirebaseAuth` entirely and
  auto-authenticates as a fake admin+owner user (`_fakeUser`) with full access,
  so every screen is reachable without a real login.
- `lib/main.dart`: wrapped `Firebase.initializeApp()` in try/catch so app boot
  doesn't crash if the Firebase project is unreachable.
- Note: only the auth gate was bypassed. Screens that read real data via
  `FirestoreDatabase`/`FirestoreService` (Home, Search, tours, bookings, etc.)
  still hit live Firestore — if Firestore itself is also unreachable, those
  screens will likely just spin/show empty rather than crash. Not yet mocked.

## Open decisions (need user input before real migration work starts)

- Target backend: candidates discussed were Supabase (Postgres, easiest
  like-for-like swap for Firestore+Auth), a custom REST/Node API, or a
  self-hosted BaaS (Appwrite/Pocketbase). Not decided yet.
- Whether to migrate existing Firestore data (companies, boats, tours, users,
  bookings) or start fresh — depends on whether the old project data is
  recoverable.
- Auth strategy for the new backend (email/password, Google sign-in again,
  magic link, etc.) — app currently only supports Google Sign-In.

## Architecture notes for later doc (context, not yet acted on)

- Data layer is organized as `FirestoreDatabase` (domain methods) ->
  `FirestoreService` (generic CRUD) -> `FirestorePath` (collection/doc path
  strings). This is a reasonable seam to swap the underlying client behind,
  if the migration keeps a similar repository-style structure.
- Auth flow: `AuthProvider` (lib/providers/auth_provider.dart) drives a
  `Status` enum (Uninitialized/Authenticated/Unauthenticated/Registering/
  NoCode/NoAccess) that `MyApp` (lib/my_app.dart) switches on to pick which
  screen to show. Any new backend's auth needs to feed into an equivalent
  status model, or `MyApp`'s routing switch needs to change too.
- Multi-tenant model: users belong to a `companyId`; access is gated by
  `hasAccess` + non-empty `boatIds` on the user doc (see
  `_userFromFirebase`/`onAuthStateChanged` in auth_provider.dart).
