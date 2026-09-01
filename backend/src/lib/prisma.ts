import { PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient();

// filled/arrived/price are a derived view (tour_totals), not columns on
// `tours` - see docs/migration-notes.md. Prisma can't model a raw SQL view
// as a relation, so every route that needs these totals joins via $queryRaw.
export interface TourTotals {
  tour_id: string;
  filled: number;
  arrived: number;
  price: string;
}

export async function tourTotalsFor(tourIds: string[]): Promise<Map<string, TourTotals>> {
  if (tourIds.length === 0) return new Map();
  const rows = await prisma.$queryRaw<TourTotals[]>`
    select tour_id, filled, arrived, price
    from tour_totals
    where tour_id = any(${tourIds}::uuid[])
  `;
  return new Map(rows.map((row) => [row.tour_id, row]));
}
