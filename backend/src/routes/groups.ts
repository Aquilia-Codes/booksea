import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";
import { getAccessibleGroup } from "../lib/authz";
import { serializeGroup } from "../lib/serialize";
import { wrap } from "../lib/wrap";
import { emitGroupsChanged, emitSummaryChanged, emitToursChanged } from "../lib/realtime";

const router = Router();
router.use(requireAuth);

// getGroup -> GET /groups/:id
router.get(
  "/:id",
  wrap(async (req, res) => {
    const group = await getAccessibleGroup(req.user!, req.params.id);
    res.json(serializeGroup(group));
  }),
);

const updateGroupBody = z.object({
  groupName: z.string().min(1).optional(),
  adultCount: z.number().int().min(0).optional(),
  childCount: z.number().int().min(0).optional(),
  price: z.number().min(0).optional(),
  paymentStatus: z.enum(["paid", "reserved", "cancelled"]).optional(),
  mobileNumber: z.string().optional(),
  countryCode: z.string().optional(),
  countryDialogCode: z.string().optional(),
});

// updateGroup -> PATCH /groups/:id
// filled/price/arrived are the tour_totals view aggregated live over
// booking_groups, so editing this row is all that's needed - no hand-rolled
// tour-counter arithmetic like the old firestore_database.dart:267 bug.
router.patch(
  "/:id",
  wrap(async (req, res) => {
    const group = await getAccessibleGroup(req.user!, req.params.id);
    const { countryDialogCode, ...rest } = updateGroupBody.parse(req.body);

    const updated = await prisma.bookingGroup.update({
      where: { id: group.id },
      data: {
        ...rest,
        countryDialCode: countryDialogCode,
      },
    });
    emitGroupsChanged(group.tourId);
    emitToursChanged(group.tour.boatId);
    emitSummaryChanged(group.tour.boatId);
    res.json(serializeGroup(updated));
  }),
);

// deleteGroup -> DELETE /groups/:id
router.delete(
  "/:id",
  wrap(async (req, res) => {
    const group = await getAccessibleGroup(req.user!, req.params.id);
    await prisma.bookingGroup.delete({ where: { id: group.id } });
    emitGroupsChanged(group.tourId);
    emitToursChanged(group.tour.boatId);
    emitSummaryChanged(group.tour.boatId);
    res.status(204).send();
  }),
);

// updateGroupHasArrived -> PATCH /groups/:id/arrival
router.patch(
  "/:id/arrival",
  wrap(async (req, res) => {
    const group = await getAccessibleGroup(req.user!, req.params.id);
    const body = z.object({ hasArrived: z.boolean() }).parse(req.body);

    const updated = await prisma.bookingGroup.update({
      where: { id: group.id },
      data: { hasArrived: body.hasArrived },
    });
    emitGroupsChanged(group.tourId);
    emitToursChanged(group.tour.boatId);
    res.json(serializeGroup(updated));
  }),
);

export default router;
