-- PaymentStatus was originally invented (unpaid/partial/paid) without
-- checking the Flutter app's actual dropdown (Paid/Reserved/Cancelled) -
-- every group submission failed validation until this was fixed. See
-- docs/migration-notes.md. Only test/smoke data exists in any environment
-- so far, so this clears booking_groups rather than trying to map old
-- values (there's no sensible mapping from "partial" to any of the new
-- three anyway).
delete from "booking_groups";

alter table "booking_groups" alter column "payment_status" drop default;
alter table "booking_groups" alter column "payment_status" type text;
drop type "PaymentStatus";
create type "PaymentStatus" as enum ('paid', 'reserved', 'cancelled');
alter table "booking_groups"
  alter column "payment_status" type "PaymentStatus" using "payment_status"::"PaymentStatus";
alter table "booking_groups" alter column "payment_status" set default 'paid';
