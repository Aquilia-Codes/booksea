import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";
import { serializeBoat, serializeMember } from "../lib/serialize";
import { HttpError } from "../lib/http-error";
import { wrap } from "../lib/wrap";
import { emitMeChanged } from "../lib/realtime";

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

// getCompanyBoats -> GET /companies/:id/boats
// The definitive list of a company's boats, by name (not just whatever
// boats the caller personally has a UserBoat row for) - needed by the
// Members screen's boat-assignment picker below, since even an owner's own
// boatIds (from GET /me) only reflects their own UserBoat rows, not
// necessarily every boat the company has.
router.get(
  "/:id/boats",
  wrap(async (req, res) => {
    if (req.user!.companyId !== req.params.id) {
      throw new HttpError(403, "Not a member of this company");
    }
    const boats = await prisma.boat.findMany({
      where: { companyId: req.params.id },
      orderBy: { name: "asc" },
    });
    res.json(boats.map(serializeBoat));
  }),
);

// Members management is owner-only (see docs/migration-notes.md "Members
// and performance" - admins stay operational, only owners handle
// access/roles/provision). A "pending" member is just a user with
// companyId set but hasAccess still false - the self-join flow
// (POST /me/company) already produces exactly that state, so there's no
// separate invite system: joining with the company code *is* the request,
// and this list is what an owner reviews to approve it.

async function boatNamesFor(userId: string): Promise<string[]> {
  const rows = await prisma.userBoat.findMany({
    where: { userId },
    select: { boat: { select: { name: true } } },
  });
  return rows.map((row) => row.boat.name);
}

function assertOwnerOfCompany(user: Express.Request["user"], companyId: string) {
  if (!user || user.companyId !== companyId) {
    throw new HttpError(403, "Not a member of this company");
  }
  if (!user.isOwner) {
    throw new HttpError(403, "Only an owner can manage members");
  }
}

// getCompanyMembers -> GET /companies/:id/members
router.get(
  "/:id/members",
  wrap(async (req, res) => {
    assertOwnerOfCompany(req.user, req.params.id);

    const members = await prisma.user.findMany({
      where: { companyId: req.params.id },
      orderBy: { createdAt: "asc" },
    });
    const serialized = await Promise.all(
      members.map(async (m) => serializeMember(m, await boatNamesFor(m.id))),
    );
    res.json(serialized);
  }),
);

const updateMemberBody = z.object({
  hasAccess: z.boolean().optional(),
  isAdmin: z.boolean().optional(),
  isOwner: z.boolean().optional(),
  provision: z.number().min(0).max(100).optional(),
  boatNames: z.array(z.string()).optional(),
});

// updateMember -> PATCH /companies/:id/members/:userId
router.patch(
  "/:id/members/:userId",
  wrap(async (req, res) => {
    assertOwnerOfCompany(req.user, req.params.id);

    const target = await prisma.user.findUnique({ where: { id: req.params.userId } });
    if (!target || target.companyId !== req.params.id) {
      throw new HttpError(404, "Member not found");
    }

    const { boatNames, ...flags } = updateMemberBody.parse(req.body);

    // Never let a company end up with zero owners - that would need a
    // direct database fix to recover from, so this is rejected outright
    // rather than merely warned about client-side.
    if (flags.isOwner === false && target.isOwner) {
      const otherOwners = await prisma.user.count({
        where: { companyId: req.params.id, isOwner: true, id: { not: target.id } },
      });
      if (otherOwners === 0) {
        throw new HttpError(409, "Cannot remove the company's last remaining owner");
      }
    }

    const updated = await prisma.$transaction(async (tx) => {
      const user = await tx.user.update({ where: { id: target.id }, data: flags });
      if (boatNames) {
        const boats = await tx.boat.findMany({
          where: { companyId: req.params.id, name: { in: boatNames } },
        });
        await tx.userBoat.deleteMany({ where: { userId: target.id } });
        if (boats.length > 0) {
          await tx.userBoat.createMany({
            data: boats.map((b) => ({ userId: target.id, boatId: b.id })),
          });
        }
      }
      return user;
    });

    // Lets the edited user's own device notice, even if it's a different
    // signed-in session than the owner's - see docs/migration-notes.md
    // "Push a me:changed signal on member edits". A PATCH here never goes
    // through /me, so without this their AuthProvider's cached UserModel
    // (what Settings displays) would otherwise stay stale until their next
    // sign-in.
    emitMeChanged(updated.id);

    res.json(serializeMember(updated, await boatNamesFor(updated.id)));
  }),
);

export default router;
