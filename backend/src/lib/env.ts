import "dotenv/config";
import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.string().min(1),
  GOOGLE_OAUTH_CLIENT_IDS: z
    .string()
    .min(1)
    .transform((value) => value.split(" ").filter(Boolean)),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_ACCESS_TTL: z.string().default("15m"),
  JWT_REFRESH_TTL: z.string().default("30d"),
  PORT: z.coerce.number().default(4000),
  CORS_ORIGIN: z.string().default("*"),
});

export const env = schema.parse(process.env);
