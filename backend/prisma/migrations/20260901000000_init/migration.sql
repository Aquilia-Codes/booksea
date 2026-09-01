-- Hand-written initial migration (no live database was available to generate
-- this via `prisma migrate dev`). Matches prisma/schema.prisma exactly, plus
-- the exclusion constraint and derived view Prisma cannot express natively.
-- See docs/migration-notes.md for the reasoning behind this schema.

create extension if not exists pgcrypto;
create extension if not exists btree_gist; -- for the tour overlap constraint

create type "CompanyStatus" as enum ('active', 'inactive', 'suspended');
create type "PaymentStatus" as enum ('unpaid', 'partial', 'paid');

create table "tiers" (
  "name"             text primary key,
  "max_boats"        int not null,
  "seats"            int not null,
  "additional_seats" int not null default 0
);

create table "companies" (
  "id"           uuid primary key default gen_random_uuid(),
  "name"         text not null,
  "company_code" text not null unique,
  "status"       "CompanyStatus" not null default 'active',
  "tier_name"    text not null references "tiers"("name"),
  "created_at"   timestamptz not null default now()
);

create table "users" (
  "id"           uuid primary key default gen_random_uuid(),
  "google_sub"   text unique,
  "email"        text not null unique,
  "nickname"     text not null default '',
  "phone_number" text,
  "company_id"   uuid references "companies"("id") on delete set null,
  "has_access"   boolean not null default false,
  "is_admin"     boolean not null default false,
  "is_owner"     boolean not null default false,
  "provision"    numeric(5,2) not null default 0,
  "created_at"   timestamptz not null default now()
);
create index on "users" ("company_id");

-- Not in the artifact's original schema - needed so POST /auth/logout can
-- actually revoke a refresh token instead of only trusting its expiry.
create table "refresh_tokens" (
  "id"         uuid primary key default gen_random_uuid(),
  "user_id"    uuid not null references "users"("id") on delete cascade,
  "token_hash" text not null,
  "expires_at" timestamptz not null,
  "revoked_at" timestamptz,
  "created_at" timestamptz not null default now()
);
create index on "refresh_tokens" ("user_id");

create table "boats" (
  "id"         uuid primary key default gen_random_uuid(),
  "company_id" uuid not null references "companies"("id") on delete cascade,
  "name"       text not null,
  "capacity"   int not null check ("capacity" >= 0),
  unique ("company_id", "name")
);

create table "user_boats" (
  "user_id" uuid not null references "users"("id") on delete cascade,
  "boat_id" uuid not null references "boats"("id") on delete cascade,
  primary key ("user_id", "boat_id")
);

create table "tour_types" (
  "id"              uuid primary key default gen_random_uuid(),
  "boat_id"         uuid not null references "boats"("id") on delete cascade,
  "type_name"       text not null,
  "price_per_adult" numeric(10,2) not null default 0,
  "price_per_child" numeric(10,2) not null default 0,
  "start_time"      time not null,
  "end_time"        time not null,
  "type_image"      int not null default 0,
  "options"         text[] not null default '{}',
  unique ("boat_id", "type_name")
);

create table "tours" (
  "id"           uuid primary key default gen_random_uuid(),
  "boat_id"      uuid not null references "boats"("id") on delete cascade,
  "tour_type_id" uuid references "tour_types"("id") on delete set null,
  "tour_name"    text not null,
  "type_image"   int not null default 0,
  "start_time"   timestamptz not null,
  "end_time"     timestamptz not null,
  "capacity"     int not null check ("capacity" >= 0),
  "is_booked"    boolean not null default false,
  "note"         text not null default '',
  "created_at"   timestamptz not null default now(),
  check ("end_time" > "start_time"),

  exclude using gist (
    "boat_id" with =,
    tstzrange("start_time", "end_time") with &&
  )
);
create index on "tours" ("boat_id", "start_time", "end_time");

create table "booking_groups" (
  "id"                uuid primary key default gen_random_uuid(),
  "tour_id"           uuid not null references "tours"("id") on delete cascade,
  "booker_id"         uuid references "users"("id") on delete set null,
  "group_name"        text not null,
  "adult_count"       int not null default 0 check ("adult_count" >= 0),
  "child_count"       int not null default 0 check ("child_count" >= 0),
  "price"             numeric(10,2) not null default 0,
  "payment_status"    "PaymentStatus" not null default 'unpaid',
  "mobile_number"     text not null default '',
  "country_code"      text not null default '',
  "country_dial_code" text not null default '',
  "has_arrived"       boolean not null default false,
  "created_at"        timestamptz not null default now()
);
create index on "booking_groups" ("tour_id");
create index on "booking_groups" ("booker_id");

-- the three counters (filled/arrived/price) are derived, never stored -
-- see docs/migration-notes.md "Three pre-existing bugs" for why
create view "tour_totals" as
select
  t."id" as "tour_id",
  coalesce(sum(g."adult_count"), 0)::int as "filled",
  coalesce(sum(g."adult_count") filter (where g."has_arrived"), 0)::int as "arrived",
  coalesce(sum(g."price"), 0)::numeric(10,2) as "price"
from "tours" t
left join "booking_groups" g on g."tour_id" = t."id"
group by t."id";
