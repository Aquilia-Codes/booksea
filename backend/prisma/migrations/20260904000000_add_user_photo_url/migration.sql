-- Stores the Google account's profile picture URL server-side, so it
-- survives session restores (not just a freshly-interactive sign-in) -
-- see docs/migration-notes.md for why this was needed.
alter table "users" add column "photo_url" text;
