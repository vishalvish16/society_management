const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();
const SALT_ROUNDS = 12;

async function main() {
  console.log('Seeding database...');

  // ─── 1. Seed Plans ──────────────────────────────────────────────────
  // Pricing: totalMonthly = priceMonthly + (unitCount * pricePerUnit)
  // Yearly = 10 months (2 months free)
  // Only features that are actually enforced via checkPlanLimit middleware are listed.
  const plans = [
    {
      name: 'basic',
      displayName: 'Basic',
      priceMonthly: 999,
      pricePerUnit: 10,  // ₹10 per unit per month
      priceYearly: 9990, // 10 months
      maxUnits: 50,
      maxResidents: -1,
      maxWatchmen: 2,
      maxSecretaries: 1,
      features: {
        visitors: true,          // manual visitor log only (no QR)
        visitor_qr: false,       // QR invite disabled
        gate_passes: false,
        expenses: true,          // submit expenses
        expense_approval: false, // approval workflow disabled
        financial_reports: false,
        donations: false,
        complaint_assignment: false,
        society_gates: false,
        amenities: false,
        amenity_booking: false,
        parking_management: false,
        delivery_tracking: false,
        move_requests: false,
        attachments_count: 2,
      },
    },
    {
      name: 'standard',
      displayName: 'Standard',
      priceMonthly: 2499,
      pricePerUnit: 8,   // ₹8 per unit per month
      priceYearly: 24990,
      maxUnits: 200,
      maxResidents: -1,
      maxWatchmen: 5,
      maxSecretaries: 3,
      features: {
        visitors: true,
        visitor_qr: true,
        gate_passes: true,
        expenses: true,
        expense_approval: true,
        financial_reports: false,
        donations: true,
        complaint_assignment: true,
        society_gates: true,
        amenities: true,
        amenity_booking: false,
        parking_management: true,
        delivery_tracking: true,
        move_requests: true,
        attachments_count: 10,
      },
    },
    {
      name: 'premium',
      displayName: 'Premium',
      priceMonthly: 4999,
      pricePerUnit: 5,   // ₹5 per unit per month
      priceYearly: 49990,
      maxUnits: -1,      // unlimited
      maxResidents: -1,
      maxWatchmen: -1,
      maxSecretaries: -1,
      features: {
        visitors: true,
        visitor_qr: true,
        gate_passes: true,
        expenses: true,
        expense_approval: true,
        financial_reports: true,
        donations: true,
        complaint_assignment: true,
        society_gates: true,
        amenities: true,
        amenity_booking: true,
        parking_management: true,
        delivery_tracking: true,
        move_requests: true,
        attachments_count: -1, // unlimited
      },
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
