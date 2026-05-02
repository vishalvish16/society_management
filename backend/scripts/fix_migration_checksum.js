const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const fs = require('fs');

async function main() {
  const prisma = new PrismaClient();
  const migrationName = process.argv[2];
  if (!migrationName) {
    console.error('Usage: node scripts/fix_migration_checksum.js <migration_name>');
    process.exit(1);
  }
  const sqlPath = `prisma/migrations/${migrationName}/migration.sql`;
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const checksum = crypto.createHash('sha256').update(sql).digest('hex');

  const before = await prisma.$queryRawUnsafe(
    `SELECT migration_name, checksum, finished_at, rolled_back_at
     FROM _prisma_migrations
     WHERE migration_name = $1
     LIMIT 1`,
    migrationName
  );

  await prisma.$executeRawUnsafe(
    `UPDATE _prisma_migrations
     SET checksum = $1
     WHERE migration_name = $2`,
    checksum,
    migrationName
  );

  const after = await prisma.$queryRawUnsafe(
    `SELECT migration_name, checksum, finished_at, rolled_back_at
     FROM _prisma_migrations
     WHERE migration_name = $1
     LIMIT 1`,
    migrationName
  );

  console.log({ migrationName, sqlPath, before: before?.[0] ?? null, after: after?.[0] ?? null });
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

