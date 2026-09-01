import { Router } from "express";
import { randomUUID, createHash } from "crypto";
import { OAuth2Client } from "google-auth-library";
import { z } from "zod";
import { env } from "../lib/env";
import { prisma } from "../lib/prisma";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../lib/jwt";

const router = Router();
const googleClient = new OAuth2Client();

function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function refreshTtlMs(): number {
  // JWT_REFRESH_TTL is a jsonwebtoken-style duration string (e.g. "30d");
  // parse the same way jsonwebtoken/ms does for the common suffixes we use.
  const match = /^(\d+)([smhd])$/.exec(env.JWT_REFRESH_TTL);
  if (!match) return 30 * 24 * 60 * 60 * 1000;
  const value = Number(match[1]);
  const unit = match[2];
  const unitMs = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 }[unit]!;
  return value * unitMs;
}

async function issueTokens(userId: string) {
  const tokenId = randomUUID();
  const refreshToken = signRefreshToken(userId, tokenId);
  await prisma.refreshToken.create({
    data: {
      id: tokenId,
      userId,
      tokenHash: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + refreshTtlMs()),
    },
  });
  return { accessToken: signAccessToken(userId), refreshToken };
}

// Verify the Google idToken server-side and issue our own JWTs. Never trust
// a user id supplied by the client - the user is looked up/created from the
// verified idToken's payload only.
router.post("/google", async (req, res) => {
  const body = z.object({ idToken: z.string().min(1) }).safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: "Missing idToken" });
    return;
  }

  let payload;
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken: body.data.idToken,
      audience: env.GOOGLE_OAUTH_CLIENT_IDS,
    });
    payload = ticket.getPayload();
  } catch {
    res.status(401).json({ error: "Invalid Google idToken" });
    return;
  }

  if (!payload?.sub || !payload.email) {
    res.status(401).json({ error: "Invalid Google idToken" });
    return;
  }

  const user = await prisma.user.upsert({
    where: { googleSub: payload.sub },
    update: { email: payload.email },
    create: {
      googleSub: payload.sub,
      email: payload.email,
      nickname: payload.name ?? "",
    },
  });

  const tokens = await issueTokens(user.id);
  res.json(tokens);
});

router.post("/refresh", async (req, res) => {
  const body = z.object({ refreshToken: z.string().min(1) }).safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: "Missing refreshToken" });
    return;
  }

  let claims;
  try {
    claims = verifyRefreshToken(body.data.refreshToken);
  } catch {
    res.status(401).json({ error: "Invalid or expired refresh token" });
    return;
  }

  const stored = await prisma.refreshToken.findUnique({ where: { id: claims.jti } });
  if (
    !stored ||
    stored.userId !== claims.sub ||
    stored.revokedAt ||
    stored.expiresAt < new Date() ||
    stored.tokenHash !== hashToken(body.data.refreshToken)
  ) {
    res.status(401).json({ error: "Refresh token no longer valid" });
    return;
  }

  // Rotate: revoke the used token and issue a new pair, so a leaked/replayed
  // refresh token stops working the moment the legitimate client uses it.
  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { revokedAt: new Date() },
  });
  const tokens = await issueTokens(claims.sub);
  res.json(tokens);
});

router.post("/logout", async (req, res) => {
  const body = z.object({ refreshToken: z.string().min(1) }).safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: "Missing refreshToken" });
    return;
  }

  try {
    const claims = verifyRefreshToken(body.data.refreshToken);
    await prisma.refreshToken.updateMany({
      where: { id: claims.jti, userId: claims.sub },
      data: { revokedAt: new Date() },
    });
  } catch {
    // Already invalid/expired - logout is a no-op in that case, not an error.
  }
  res.status(204).send();
});

export default router;
