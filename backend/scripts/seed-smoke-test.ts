// One-off script for manual smoke testing without real Google OAuth.
// Creates a tier/company/user/boat and prints a valid access token.
// Not part of the app - safe to delete once real auth is wired up.
import { prisma } from "../src/lib/prisma";
import { signAccessToken } from "../src/lib/jwt";

async function main() {
  const tier = await prisma.tier.upsert({
    where: { name: "starter" },
    update: {},
    create: { name: "starter", maxBoats: 3, seats: 10 },
  });

  const company = await prisma.company.upsert({
    where: { companyCode: "SMOKE1" },
    update: {},
    create: { name: "Smoke Test d.o.o.", companyCode: "SMOKE1", tierName: tier.name },
  });

  const user = await prisma.user.upsert({
    where: { email: "smoke@test.local" },
    update: {},
    create: {
      email: "smoke@test.local",
      nickname: "Smoke Tester",
      companyId: company.id,
      hasAccess: true,
      isAdmin: true,
      isOwner: true,
    },
  });

  const boat = await prisma.boat.upsert({
    where: { companyId_name: { companyId: company.id, name: "Catamaran" } },
    update: {},
    create: { companyId: company.id, name: "Catamaran", capacity: 20 },
  });

  await prisma.userBoat.upsert({
    where: { userId_boatId: { userId: user.id, boatId: boat.id } },
    update: {},
    create: { userId: user.id, boatId: boat.id },
  });

  console.log("USER_ID=" + user.id);
  console.log("COMPANY_ID=" + company.id);
  console.log("BOAT_ID=" + boat.id);
  console.log("ACCESS_TOKEN=" + signAccessToken(user.id));
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
