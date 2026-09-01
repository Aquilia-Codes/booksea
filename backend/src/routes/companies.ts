import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";
import { serializeBoat } from "../lib/serialize";
import { HttpError } from "../lib/http-error";
import { wrap } from "../lib/wrap";

const router = Router();
router.use(requireAuth);

const createBoatBody = z.object({
  name: z.string().min(1),
  capacity: z.number().int().min(0),
});

// createBoat -> POST /companies/:id/boats
// :id is checked against the caller's own companyId, not trusted outright -
// same rule as everywhere else (see docs/migration-notes.md route-map notes).
router.post(
  "/:id/boats",
  wrap(async (req, res) => {
    const user = req.user!;
    if (user.companyId !== req.params.id) {
      throw new HttpError(403, "Not a member of this company");
    }
    if (!user.isAdmin && !user.isOwner) {
      throw new HttpError(403, "Only an admin or owner can add boats");
    }

    const body = createBoatBody.parse(req.body);
    const boat = await prisma.boat.create({
      data: { companyId: user.companyId, name: body.name, capacity: body.capacity },
    });
    res.status(201).json(serializeBoat(boat));
  }),
);

export default router;
