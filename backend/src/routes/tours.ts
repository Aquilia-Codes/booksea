import { Router } from "express";
import { z } from "zod";
import { prisma, tourTotalsFor } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";
import { getAccessibleTour } from "../lib/authz";
import { serializeGroup, serializeTour } from "../lib/serialize";
import { HttpError } from "../lib/http-error";
import { wrap } from "../lib/wrap";
import { emitGroupsChanged, emitSummaryChanged, emitToursChanged } from "../lib/realtime";

const router = Router();
router.use(requireAuth);

const updateTourBody = z.object({
  tourName: z.string().min(1).optional(),
  typeImage: z.number().int().optional(),
  capacity: z.number().int().min(0).optional(),
  startTime: z.string().datetime().optional(),
  endTime: z.string().datetime().optional(),
  note: z.string().optional(),
  isBooked: z.boolean().optional(),
});

// updateTour -> PATCH /tours/:id
router.patch(
  "/:id",
  wrap(async (req, res) => {
    const tour = await getAccessibleTour(req.user!, req.params.id);
    const body = updateTourBody.parse(req.body);

    const updated = await prisma.tour.update({
      where: { id: tour.id },
      data: {
        ...body,
        startTime: body.startTime ? new Date(body.startTime) : undefined,
        endTime: body.endTime ? new Date(body.endTime) : undefined,
      },
      include: { tourType: true },
    });
    const totals = await tourTotalsFor([updated.id]);
    emitToursChanged(updated.boatId);
    res.json(serializeTour(updated, totals.get(updated.id)));
  }),
);

// deleteTour -> DELETE /tours/:id (cascades to groups via FK)
router.delete(
  "/:id",
  wrap(async (req, res) => {
    const tour = await getAccessibleTour(req.user!, req.params.id);
    await prisma.tour.delete({ where: { id: tour.id } });
    emitToursChanged(tour.boatId);
    emitSummaryChanged(tour.boatId);
    res.status(204).send();
  }),
);

// getGroups -> GET /tours/:id/groups
router.get(
  "/:id/groups",
  wrap(async (req, res) => {
    const tour = await getAccessibleTour(req.user!, req.params.id);
    const groups = await prisma.bookingGroup.findMany({
      where: { tourId: tour.id },
      orderBy: { createdAt: "asc" },
    });
    res.json(groups.map(serializeGroup));
  }),
);

const createGroupBody = z.object({
  groupName: z.string().min(1),
  adultCount: z.number().int().min(0),
  childCount: z.number().int().min(0).default(0),
  price: z.number().min(0),
  paymentStatus: z.enum(["paid", "reserved", "cancelled"]).default("paid"),
  mobileNumber: z.string().default(""),
  countryCode: z.string().default(""),
  countryDialogCode: z.string().default(""),
});

// createGroup -> POST /tours/:id/groups
router.post(
  "/:id/groups",
  wrap(async (req, res) => {
    const tour = await getAccessibleTour(req.user!, req.params.id);
    const { countryDialogCode, ...rest } = createGroupBody.parse(req.body);
    const bookerId = req.user!.id;

    const group = await prisma.$transaction(async (tx) => {
      // Lock the tour row so two concurrent bookings can't both read the
      // same `filled` and both pass the capacity check - see the capacity
      // race called out in docs/migration-notes.md.
      const [locked] = await tx.$queryRaw<{ capacity: number }[]>`
        select capacity from tours where id = ${tour.id}::uuid for update
      `;
      if (!locked) throw new HttpError(404, "Tour not found");

      const sum = await tx.bookingGroup.aggregate({
        where: { tourId: tour.id },
        _sum: { adultCount: true },
      });
      const filled = sum._sum.adultCount ?? 0;
      if (filled + rest.adultCount > locked.capacity) {
        throw new HttpError(409, "Group capacity exceeds tour capacity.");
      }

      return tx.bookingGroup.create({
        data: { ...rest, countryDialCode: countryDialogCode, tourId: tour.id, bookerId },
      });
    });

    emitGroupsChanged(tour.id);
    emitToursChanged(tour.boatId);
    emitSummaryChanged(tour.boatId);
    res.status(201).json(serializeGroup(group));
  }),
);

export default router;
