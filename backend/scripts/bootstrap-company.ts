// One-off admin script: create a company + boat and grant an existing user
// (already created by signing in once via the app) full access to it.
// There's no in-app "create a company" flow (never was, even in the old
// Firestore version - see docs/migration-notes.md) and no admin API yet for
// granting hasAccess/isAdmin/isOwner, so this fills that gap for now.
//
// Usage: npx tsx scripts/bootstrap-company.ts <email> <companyName> <companyCode> <boatName> <boatCapacity>
import { prisma } from "../src/lib/prisma";

async function main() {
  const [email, companyName, companyCode, boatName, boatCapacityStr] = process.argv.slice(2);
  if (!email || !companyName || !companyCode || !boatName || !boatCapacityStr) {
    console.error(
      "Usage: npx tsx scripts/bootstrap-company.ts <email> <companyName> <companyCode> <boatName> <boatCapacity>",
    );
    process.exit(1);
  }
  const boatCapacity = Number(boatCapacityStr);

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    console.error(
      `No user with email ${email} - they need to sign in via the app at least once first (creates the user row).`,
    );
    process.exit(1);
  }

  const tier = await prisma.tier.upsert({
    where: { name: "starter" },
    update: {},
    create: { name: "starter", maxBoats: 5, seats: 20 },
  });

  const company = await prisma.company.upsert({
    where: { companyCode },
    update: {},
    create: { name: companyName, companyCode, tierName: tier.name },
  });

  const boat = await prisma.boat.upsert({
    where: { companyId_name: { companyId: company.id, name: boatName } },
    update: {},
    create: { companyId: company.id, name: boatName, capacity: boatCapacity },
  });

  await prisma.userBoat.upsert({
    where: { userId_boatId: { userId: user.id, boatId: boat.id } },
    update: {},
    create: { userId: user.id, boatId: boat.id },
  });

  const updatedUser = await prisma.user.update({
    where: { id: user.id },
    data: { companyId: company.id, hasAccess: true, isAdmin: true, isOwner: true },
  });

  console.log(`Granted ${updatedUser.email} owner+admin access to "${company.name}" (code ${company.companyCode}), boat "${boat.name}".`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
