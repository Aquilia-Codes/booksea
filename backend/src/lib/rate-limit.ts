import rateLimit from "express-rate-limit";

// General ceiling across the whole API - generous enough that normal usage
// (a handful of staff per company, each screen polling/socket-pushing, not
// hammering REST) never gets close to it, but bounds a flood of requests
// from a single IP. See docs/migration-notes.md "Basic DDoS/abuse
// mitigation" for why this exists at all - there was previously no rate
// limiting anywhere in this API.
export const generalRateLimiter = rateLimit({
  windowMs: 60_000,
  limit: 300,
  standardHeaders: true,
  legacyHeaders: false,
});

// Auth endpoints are more expensive per call (POST /google calls out to
// Google's own servers to verify the idToken; POST /refresh and /logout
// each do a couple of DB round-trips) and more sensitive to abuse (token
// churn, credential-stuffing-style attempts) than a typical GET, so they
// get their own tighter limit on top of the general one.
export const authRateLimiter = rateLimit({
  windowMs: 60_000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
});
