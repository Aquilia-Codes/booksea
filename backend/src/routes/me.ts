import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";

const router = Router();
router.use(requireAuth);

function serializeUser(user: NonNullable<Express.Request["user"]>, boatIds: string[]) {
  return {
    uid: user.id,
    email: user.email,
    nickname: user.nickname,
    phoneNumber: user.phoneNumber,
    provision: Number(user.provision),
    hasAccess: user.hasAccess,
    isAdmin: user.isAdmin,
    isOwner: user.isOwner,
    companyId: user.companyId,
    boatIds,
  };
}

async function boatIdsFor(userId: string): Promise<string[]> {
  // Returns boat *names*, not the internal boat UUID - the Flutter client
  // treats "boatId" as a human-readable, dropdown-displayable string
  // throughout (see docs/migration-notes.md and authz.ts's getBoatByName).
  const rows = await prisma.userBoat.findMany({
    where: { userId },
    select: { boat: { select: { name: true } } },
  });
  return rows.map((row) => row.boat.name);
}

// getUser -> GET /me
router.get("/", async (req, res) => {
  const boatIds = await boatIdsFor(req.user!.id);
  res.json(serializeUser(req.user!, boatIds));
});

// setUser -> PATCH /me
// Deliberately narrower than the old Firestore setUser(), which could set
// hasAccess/isAdmin/isOwner/companyId on the same document a client could
// write to directly. Only self-editable profile fields go through here;
// company membership goes through POST /me/company and access/role flags
// are meant to be granted by an admin (not modeled yet - see migration notes).
router.patch("/", async (req, res) => {
  const body = z
    .object({
      nickname: z.string().min(1).optional(),
      phoneNumber: z.string().min(1).optional(),
    })
    .safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.flatten() });
    return;
  }

  const updated = await prisma.user.update({
    where: { id: req.user!.id },
    data: body.data,
  });
  const boatIds = await boatIdsFor(updated.id);
  res.json(serializeUser(updated, boatIds));
});

// writeCompanyIdToUserDocument -> POST /me/company
router.post("/company", async (req, res) => {
  const body = z.object({ companyCode: z.string().min(1) }).safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: "Missing companyCode" });
    return;
  }

  const company = await prisma.company.findUnique({
    where: { companyCode: body.data.companyCode },
  });
  if (!company) {
    res.status(404).json({ error: "No company with that code" });
    return;
  }

  const updated = await prisma.user.update({
    where: { id: req.user!.id },
    data: { companyId: company.id },
  });
  const boatIds = await boatIdsFor(updated.id);
  res.json(serializeUser(updated, boatIds));
});

export default router;
