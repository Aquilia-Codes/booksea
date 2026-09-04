// One-off admin script: create tour types for a boat. There's no in-app
// "create a tour type" flow (never was - same situation as company/boat
// creation, see docs/migration-notes.md), so the "+" add-tour button has
// nothing to offer in its type dropdown until this is run at least once.
//
// Usage: npx tsx scripts/seed-tour-types.ts <companyCode> <boatName>
import { prisma } from "../src/lib/prisma";

interface TypeSeed {
  typeName: string;
  typeImage: number;
  pricePerAdult: number;
  pricePerChild: number;
  startTime: string; // "HH:mm"
  endTime: string;
}

// typeImage refers to booksea_app/assets/<n>.png - see pubspec.yaml assets.
const TYPES: TypeSeed[] = [
  { typeName: "Sunset", typeImage: 1, pricePerAdult: 20, pricePerChild: 10, startTime: "18:00", endTime: "20:00" },
  { typeName: "Panorama", typeImage: 5, pricePerAdult: 15, pricePerChild: 8, startTime: "10:00", endTime: "12:00" },
  { typeName: "Private", typeImage: 2, pricePerAdult: 0, pricePerChild: 0, startTime: "09:00", endTime: "17:00" },
];

async function main() {
  const [companyCode, boatName] = process.argv.slice(2);
  if (!companyCode || !boatName) {
    console.error("Usage: npx tsx scripts/seed-tour-types.ts <companyCode> <boatName>");
    process.exit(1);
  }

  const company = await prisma.company.findUnique({ where: { companyCode } });
  if (!company) {
    console.error(`No company with code ${companyCode}`);
    process.exit(1);
  }
  const boat = await prisma.boat.findUnique({
    where: { companyId_name: { companyId: company.id, name: boatName } },
  });
  if (!boat) {
    console.error(`No boat named "${boatName}" in company ${companyCode}`);
    process.exit(1);
  }

  for (const t of TYPES) {
    await prisma.tourType.upsert({
      where: { boatId_typeName: { boatId: boat.id, typeName: t.typeName } },
      update: {
        typeImage: t.typeImage,
        pricePerAdult: t.pricePerAdult,
        pricePerChild: t.pricePerChild,
        // The trailing Z is load-bearing: without it, JS parses a
        // date-time string as local time, which then gets shifted when
        // Postgres's timezone-naive `time` column round-trips it through
        // Prisma (which treats @db.Time as UTC-anchored). Verified this
        // was silently off by an hour without the Z.
        startTime: new Date(`1970-01-01T${t.startTime}:00Z`),
        endTime: new Date(`1970-01-01T${t.endTime}:00Z`),
      },
      create: {
        boatId: boat.id,
        typeName: t.typeName,
        typeImage: t.typeImage,
        pricePerAdult: t.pricePerAdult,
        pricePerChild: t.pricePerChild,
        // The trailing Z is load-bearing: without it, JS parses a
        // date-time string as local time, which then gets shifted when
        // Postgres's timezone-naive `time` column round-trips it through
        // Prisma (which treats @db.Time as UTC-anchored). Verified this
        // was silently off by an hour without the Z.
        startTime: new Date(`1970-01-01T${t.startTime}:00Z`),
        endTime: new Date(`1970-01-01T${t.endTime}:00Z`),
      },
    });
    console.log(`Upserted tour type "${t.typeName}" for boat "${boat.name}".`);
  }
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
