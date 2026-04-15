const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Use raw SQL to bypass Prisma's enum validation during migration
  const count = await prisma.$executeRawUnsafe(
    "UPDATE users SET role = 'CHAIRMAN' WHERE role = 'PRAMUKH'"
  );
  console.log('Migrated users:', count);
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
