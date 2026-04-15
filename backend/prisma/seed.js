const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();
const SALT_ROUNDS = 12;

async function main() {
  console.log('Seeding database...');

  // ─── 1. Seed Plans ──────────────────────────────────────────────────
  const plans = [
    {
      name: 'basic',
      displayName: 'Basic',
      priceMonthly: 999,
      priceYearly: 9990,
      maxUnits: 50,
      maxSecretaries: 1,
      features: { visitor_qr: false, expense_approval: true, attachments_count: 3, whatsapp: true, pdf_receipts: false },
    },
    {
      name: 'standard',
      displayName: 'Standard',
      priceMonthly: 2499,
      priceYearly: 24990,
      maxUnits: 200,
      maxSecretaries: 3,
      features: { visitor_qr: true, expense_approval: true, attachments_count: 10, whatsapp: true, pdf_receipts: true },
    },
    {
      name: 'premium',
      displayName: 'Premium',
      priceMonthly: 4999,
      priceYearly: 49990,
      maxUnits: -1, // unlimited
      maxSecretaries: -1, // unlimited
      features: { visitor_qr: true, expense_approval: true, attachments_count: -1, whatsapp: true, pdf_receipts: true },
    },
  ];

  for (const plan of plans) {
    await prisma.plan.upsert({
      where: { name: plan.name },
      update: plan,
      create: plan,
    });
    console.log(`  Plan "${plan.displayName}" upserted`);
  }

  // ─── 2. Seed Super Admin ───────────────────────────────────────────
  const passwordHash = await bcrypt.hash('SuperAdmin@123', SALT_ROUNDS);

  await prisma.user.upsert({
    where: { email: 'admin@societymanager.in' },
    update: {
      name: 'Super Admin',
      email: 'admin@societymanager.in',
      role: 'SUPER_ADMIN',
      passwordHash,
      isActive: true,
      deletedAt: null,
    },
    create: {
      name: 'Super Admin',
      phone: '9999999999',
      email: 'admin@societymanager.in',
      role: 'SUPER_ADMIN',
      passwordHash,
      isActive: true,
    },
  });
  console.log('  Super Admin user upserted (email: admin@societymanager.in, password: SuperAdmin@123)');

  // ─── 3. Seed Platform Settings ──────────────────────────────────────
  const platformSettings = [
    {
      key: 'visitor_qr_max_hrs',
      value: '3',
      label: 'Max QR Expiry (hours)',
      dataType: 'number',
    },
  ];

  for (const setting of platformSettings) {
    await prisma.platformSetting.upsert({
      where: { key: setting.key },
      update: {}, // never overwrite an SA-customised value on re-seed
      create: { ...setting, updatedBy: null },
    });
  }
  console.log('  Platform settings seeded (visitor_qr_max_hrs = 3)');

  console.log('Seeding complete.');
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
