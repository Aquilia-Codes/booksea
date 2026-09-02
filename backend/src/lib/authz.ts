import type { Boat, User } from "@prisma/client";
import { prisma } from "./prisma";
import { HttpError } from "./http-error";

// companyId is always derived server-side from the authenticated user - a
// boat/tour/group id in the URL is only ever resolved and then checked
// against the caller's company, never the other way around. This is what
// stops one company reading or writing another's data (see route-map notes
// in docs/migration-notes.md).

async function assertBoatAccess(user: User, boat: Boat) {
  if (!user.isAdmin && !user.isOwner) {
    const membership = await prisma.userBoat.findUnique({
      where: { userId_boatId: { userId: user.id, boatId: boat.id } },
    });
    if (!membership) throw new HttpError(403, "No access to this boat");
  }
  return boat;
}

// For routes where the id in hand is already the real internal boat UUID -
// e.g. resolved from a tour's/group's boatId foreign key. Not for a raw
// value taken straight from a URL param (see getBoatByName below).
export async function getAccessibleBoat(user: User, boatId: string) {
  const boat = await prisma.boat.findUnique({ where: { id: boatId } });
  if (!boat || boat.companyId !== user.companyId) {
    throw new HttpError(404, "Boat not found");
  }
  return assertBoatAccess(user, boat);
}

// The old Firestore backend used a boat's *name* as its document id, and
// the Flutter client still treats "boatId" as a human-readable, dropdown-
// displayable string throughout (see AuthProvider.boatIds and the boat
// dropdowns in home.dart/search_and_filter.dart) - it was never actually a
// surrogate id. Rather than change that client-side contract, boat-facing
// routes resolve by (companyId, name) instead of by the real UUID primary
// key, so `boats.id` stays a normal UUID internally without the Flutter
// side needing to know the difference.
export async function getBoatByName(user: User, boatName: string) {
  if (!user.companyId) throw new HttpError(404, "Boat not found");
  const boat = await prisma.boat.findUnique({
    where: { companyId_name: { companyId: user.companyId, name: boatName } },
  });
  if (!boat) throw new HttpError(404, "Boat not found");
  return assertBoatAccess(user, boat);
}

export async function getAccessibleTour(user: User, tourId: string) {
  const tour = await prisma.tour.findUnique({ where: { id: tourId }, include: { boat: true } });
  if (!tour) throw new HttpError(404, "Tour not found");
  await getAccessibleBoat(user, tour.boatId);
  return tour;
}

export async function getAccessibleGroup(user: User, groupId: string) {
  const group = await prisma.bookingGroup.findUnique({
    where: { id: groupId },
    include: { tour: true },
  });
  if (!group) throw new HttpError(404, "Group not found");
  await getAccessibleBoat(user, group.tour.boatId);
  return group;
}
