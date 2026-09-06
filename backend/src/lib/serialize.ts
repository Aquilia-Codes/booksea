import type { Boat, BookingGroup, Tour, TourType, User } from "@prisma/client";
import type { TourTotals } from "./prisma";

// Field names below match what the existing Dart models' fromMap() expect
// (TourModel, GroupModel, BoatModel, TypeModel in booksea_app/lib/models) -
// keeping the wire shape identical is what lets ApiDatabase be a drop-in
// replacement for FirestoreDatabase (see docs/migration-notes.md phase 5).

export function serializeBoat(boat: Boat) {
  return { id: boat.id, name: boat.name, capacity: boat.capacity };
}

export function serializeTourType(type: TourType) {
  return {
    id: type.id,
    typeName: type.typeName,
    pricePerAdult: Number(type.pricePerAdult),
    pricePerChild: Number(type.pricePerChild),
    startTime: type.startTime.toISOString().slice(11, 19),
    endTime: type.endTime.toISOString().slice(11, 19),
    typeImage: type.typeImage,
    options: type.options,
  };
}

export function serializeTour(tour: Tour & { tourType?: TourType | null }, totals?: TourTotals) {
  return {
    id: tour.id,
    startTime: tour.startTime.toISOString(),
    endTime: tour.endTime.toISOString(),
    tourName: tour.tourName,
    tourType: tour.tourType?.typeName ?? "",
    typeImage: tour.typeImage,
    capacity: tour.capacity,
    filled: totals?.filled ?? 0,
    arrived: totals?.arrived ?? 0,
    price: totals ? Number(totals.price) : 0,
    isBooked: tour.isBooked,
    note: tour.note,
  };
}

// Used by the owner-facing Members screen (GET/PATCH /companies/:id/members) -
// boatNames (not boat UUIDs) to match the same "boatId is really the name"
// convention the rest of the app uses (see authz.ts's getBoatByName).
export function serializeMember(user: User, boatNames: string[]) {
  return {
    id: user.id,
    email: user.email,
    nickname: user.nickname,
    hasAccess: user.hasAccess,
    isAdmin: user.isAdmin,
    isOwner: user.isOwner,
    provision: Number(user.provision),
    boatNames,
  };
}

export function serializeGroup(group: BookingGroup) {
  return {
    id: group.id,
    groupName: group.groupName,
    adultCount: group.adultCount,
    childCount: group.childCount,
    price: Number(group.price),
    paymentStatus: group.paymentStatus,
    bookerId: group.bookerId ?? "",
    mobileNumber: group.mobileNumber,
    countryCode: group.countryCode,
    countryDialogCode: group.countryDialCode,
    hasArrived: group.hasArrived,
  };
}
