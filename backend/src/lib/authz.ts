import type { User } from "@prisma/client";
import { prisma } from "./prisma";
import { HttpError } from "./http-error";

// companyId is always derived server-side from the authenticated user - a
// boat/tour/group id in the URL is only ever resolved and then checked
// against the caller's company, never the other way around. This is what
// stops one company reading or writing another's data (see route-map notes
// in docs/migration-notes.md).

export async function getAccessibleBoat(user: User, boatId: string) {
  const boat = await prisma.boat.findUnique({ where: { id: boatId } });
  if (!boat || boat.companyId !== user.companyId) {
    throw new HttpError(404, "Boat not found");
  }
  if (!user.isAdmin && !user.isOwner) {
    const membership = await prisma.userBoat.findUnique({
      where: { userId_boatId: { userId: user.id, boatId } },
    });
    if (!membership) throw new HttpError(403, "No access to this boat");
  }
  return boat;
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
