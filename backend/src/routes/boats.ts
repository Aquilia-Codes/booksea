import { Router } from "express";
import { z } from "zod";
import { prisma, tourTotalsFor } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";
import { getAccessibleBoat } from "../lib/authz";
import { serializeBoat, serializeTour, serializeTourType } from "../lib/serialize";
import { HttpError } from "../lib/http-error";
import { wrap } from "../lib/wrap";
import { emitToursChanged, emitSummaryChanged } from "../lib/realtime";

const router = Router();
router.use(requireAuth);

const rangeQuery = z.object({
  from: z.string().datetime(),
  to: z.string().datetime(),
});

// getTourTypesAndBoatInfo -> GET /boats/:id
router.get(
  "/:id",
  wrap(async (req, res) => {
    const boat = await getAccessibleBoat(req.user!, req.params.id);
    const tourTypes = await prisma.tourType.findMany({ where: { boatId: boat.id } });
    res.json({
      boatInfo: serializeBoat(boat),
      tourTypes: tourTypes.map(serializeTourType),
    });
  }),
);

// getTypeInfo -> GET /boats/:id/tour-types/:name
router.get(
  "/:id/tour-types/:name",
  wrap(async (req, res) => {
    const boat = await getAccessibleBoat(req.user!, req.params.id);
    const type = await prisma.tourType.findUnique({
      where: { boatId_typeName: { boatId: boat.id, typeName: req.params.name } },
    });
    if (!type) throw new HttpError(404, "Tour type not found");
    res.json(serializeTourType(type));
  }),
);

// getTours / getToursStream (initial snapshot; live updates via the
// boat:<id> socket room, see docs/migration-notes.md) -> GET /boats/:id/tours
router.get(
  "/:id/tours",
  wrap(async (req, res) => {
    const boat = await getAccessibleBoat(req.user!, req.params.id);
    const query = rangeQuery.parse(req.query);
    const from = new Date(query.from);
    const to = new Date(query.to);

    const tours = await prisma.tour.findMany({
      where: { boatId: boat.id, startTime: { lte: to }, endTime: { gte: from } },
      include: { tourType: true },
      orderBy: { startTime: "asc" },
    });
    const totals = await tourTotalsFor(tours.map((t) => t.id));
    res.json(tours.map((tour) => serializeTour(tour, totals.get(tour.id))));
  }),
);

// getSumOfPriceStream -> GET /boats/:id/tours/summary
router.get(
  "/:id/tours/summary",
  wrap(async (req, res) => {
    const boat = await getAccessibleBoat(req.user!, req.params.id);
    const query = rangeQuery.parse(req.query);
    const from = new Date(query.from);
    const to = new Date(query.to);

    const tours = await prisma.tour.findMany({
      where: { boatId: boat.id, startTime: { lte: to }, endTime: { gte: from } },
      include: { groups: { select: { bookerId: true } } },
    });
    const totals = await tourTotalsFor(tours.map((t) => t.id));

    let totalPrice = 0;
    let totalProvision = 0;
    const provisionRate = Number(req.user!.provision) / 100;
    for (const tour of tours) {
      const price = Number(totals.get(tour.id)?.price ?? 0);
      totalPrice += price;
      if (tour.groups.some((g) => g.bookerId === req.user!.id)) {
        totalProvision += price * provisionRate;
      }
    }
    res.json({ totalPrice, totalProvision });
  }),
);

// searchTours -> GET /boats/:id/tours/search?types=a,b&from=&to=&seats=
router.get(
  "/:id/tours/search",
  wrap(async (req, res) => {
    const boat = await getAccessibleBoat(req.user!, req.params.id);
    const query = z
      .object({
        types: z.string().min(1),
        from: z.string().datetime(),
        to: z.string().datetime(),
        seats: z.coerce.number().int().positive(),
      })
      .parse(req.query);
    const typeNames = query.types.split(",").filter(Boolean);
    const from = new Date(query.from);
    const to = new Date(query.to);

    const tours = await prisma.tour.findMany({
      where: {
        boatId: boat.id,
        startTime: { gt: from },
        endTime: { lt: to },
        tourType: { typeName: { in: typeNames } },
      },
      include: { tourType: true },
      orderBy: { startTime: "asc" },
    });
    const totals = await tourTotalsFor(tours.map((t) => t.id));
    const withSeats = tours.filter((tour) => {
      const filled = totals.get(tour.id)?.filled ?? 0;
      return tour.capacity - filled >= query.seats;
    });
    res.json(withSeats.map((tour) => serializeTour(tour, totals.get(tour.id))));
  }),
);

const createTourBody = z.object({
  tourName: z.string().min(1),
  tourType: z.string().optional(),
  typeImage: z.number().int().default(0),
  capacity: z.number().int().min(0),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  note: z.string().default(""),
  isBooked: z.boolean().default(false),
});

// createTour -> POST /boats/:id/tours
router.post(
  "/:id/tours",
  wrap(async (req, res) => {
    const boat = await getAccessibleBoat(req.user!, req.params.id);
    const body = createTourBody.parse(req.body);

    let tourTypeId: string | null = null;
    if (body.tourType) {
      const type = await prisma.tourType.findUnique({
        where: { boatId_typeName: { boatId: boat.id, typeName: body.tourType } },
      });
      tourTypeId = type?.id ?? null;
    }

    const start = new Date(body.startTime);
    const end = new Date(body.endTime);

    // Pre-check for a friendly 409 in the common case. The `tours` table's
    // gist exclusion constraint (see migration.sql) is the real guarantee
    // against overlap under concurrent requests - this check just avoids
    // surfacing that as an opaque 500 on the non-concurrent happy path.
    const overlapping = await prisma.tour.findFirst({
      where: { boatId: boat.id, startTime: { lt: end }, endTime: { gt: start } },
    });
    if (overlapping) {
      throw new HttpError(409, "A tour already exists in this time range.");
    }

    try {
      const tour = await prisma.tour.create({
        data: {
          boatId: boat.id,
          tourTypeId,
          tourName: body.tourName,
          typeImage: body.typeImage,
          capacity: body.capacity,
          startTime: start,
          endTime: end,
          note: body.note,
          isBooked: body.isBooked,
        },
        include: { tourType: true },
      });
      emitToursChanged(boat.id);
      emitSummaryChanged(boat.id);
      res.status(201).json(serializeTour(tour, undefined));
    } catch (err: unknown) {
      // Fallback for the race the pre-check can't close: two requests pass
      // the check simultaneously and the gist exclusion constraint (Postgres
      // error 23P01) rejects the second insert at the database level.
      const message = err instanceof Error ? err.message : "";
      if (message.includes("23P01") || message.toLowerCase().includes("exclu")) {
        throw new HttpError(409, "A tour already exists in this time range.");
      }
      throw err;
    }
  }),
);

export default router;
