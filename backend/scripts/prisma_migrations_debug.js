const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const fs = require('fs');

async function main() {
  const prisma = new PrismaClient();
  const migrationName = process.argv[2] || '20260428013000_gatepass_scan_logs';
  const sqlPath = process.argv[3] || `prisma/migrations/${migrationName}/migration.sql`;

  const sql = fs.readFileSync(sqlPath, 'utf8');
  const fileChecksum = crypto.createHash('sha256').update(sql).digest('hex');

  const rows = await prisma.$queryRawUnsafe(
    `SELECT migration_name, checksum, started_at, finished_at, rolled_back_at
     FROM _prisma_migrations
     WHERE migration_name = $1
     LIMIT 1`,
    migrationName
  );

  const unfinished = await prisma.$queryRawUnsafe(
    `SELECT migration_name, started_at, finished_at, rolled_back_at
     FROM _prisma_migrations
     WHERE finished_at IS NULL AND rolled_back_at IS NULL
     ORDER BY started_at DESC`
  );

  const gatePassLogs = await prisma.$queryRawUnsafe(
    `SELECT to_regclass('public.gate_pass_logs')::text AS gate_pass_logs`
  );

  console.log({
    migrationName,
    sqlPath,
    fileChecksum,
    dbRow: rows?.[0] ?? null,
    unfinished,
    gatePassLogs: gatePassLogs?.[0]?.gate_pass_logs ?? null,
  });
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

