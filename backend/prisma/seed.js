const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();
const SALT_ROUNDS = 12;

async function main() {
  console.log('Seeding database...');

  // ─── 1. Seed Plans (VIDYRON) ─────────────────────────────────────────
  // Pricing: unitCount * pricePerUnit * months * (1 - durationDiscount)
  // NOTE: priceMonthly/priceYearly kept as 0 for now (not used for quotes).
  const plans = [
    {
      name: 'basic',
      displayName: 'Basic 🟢',
      priceMonthly: 0,
      priceYearly: 0,
      pricePerUnit: 5, // ₹5 per unit per month
      maxUnits: 100,
      maxUsers: 250,
      features: {
        visitors: false,
        visitor_qr: false,
        gate_passes: false,
        delivery_tracking: false,
        domestic_help: false,
        parking_management: false,
        society_gates: false,
        amenities: false,
        amenity_booking: false,
        move_requests: false,
        complaint_assignment: false,
        expenses: false,
        expense_approval: false,
        bill_schedules: false,
        financial_reports: false,
        donations: false,
        attachments_count: 2,
      },
    },
    {
      name: 'standard',
      displayName: 'Standard 🔵',
      priceMonthly: 0,
      priceYearly: 0,
      pricePerUnit: 8, // ₹8 per unit per month
      maxUnits: 500,
      maxUsers: 1200,
      features: {
        visitors: true,
        visitor_qr: true,
        gate_passes: true,
        delivery_tracking: true,
        domestic_help: true,
        parking_management: true,
        society_gates: true,
        amenities: true,
        amenity_booking: true,
        move_requests: true,
        complaint_assignment: true,
        // Finance/Admin off
        expenses: false,
        expense_approval: false,
        bill_schedules: false,
        financial_reports: false,
        donations: false,
        attachments_count: 10,
      },
    },
    {
      name: 'premium',
      displayName: 'Premium 🔴',
      priceMonthly: 0,
      priceYearly: 0,
      pricePerUnit: 12, // ₹12 per unit per month
      maxUnits: -1,
      maxUsers: -1,
      features: {
        visitors: true,
        visitor_qr: true,
        gate_passes: true,
        delivery_tracking: true,
        domestic_help: true,
        parking_management: true,
        society_gates: true,
        amenities: true,
        amenity_booking: true,
        move_requests: true,
        complaint_assignment: true,
        // Finance & Billing + Admin & Analytics on
        expenses: true,
        expense_approval: true,
        bill_schedules: true,
        financial_reports: true,
        donations: true,
        attachments_count: -1,
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
  const passwordHash = await bcrypt.hash('Admin@123', SALT_ROUNDS);

  await prisma.user.upsert({
    where: { email: 'admin@societymanager.in' },
    update: {
      name: 'Super Admin',
      email: 'admin@societymanager.in',
      phone: '9999999999',
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
  console.log('  Super Admin user upserted (email: admin@societymanager.in, password: Admin@123)');

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

  // ─── 4. Seed Sample Parking Slots ──────────────────────────────────
  // Only runs if at least one society exists and it has units.
  // Idempotent: skips slot creation if slotNumber already exists for that society.
  const societies = await prisma.society.findMany({
    where: { status: 'ACTIVE' },
    include: {
      units: { where: { deletedAt: null }, take: 10, select: { id: true } },
      vehicles: { take: 10, select: { id: true, unitId: true } },
    },
    take: 3,
  });

  for (const society of societies) {
    if (!society.units.length) continue;

    // Build slot definitions — covers apartment (basement+stilt+open) pattern
    const slotDefs = [
      // Basement level (-1) — covered
      ...['B-01', 'B-02', 'B-03', 'B-04', 'B-05'].map((n, i) => ({
        slotNumber: n, type: 'BASEMENT', zone: 'B', floor: -1,
        isHandicapped: i === 0, hasEVCharger: i === 1,
      })),
      // Stilt floor (0)
      ...['S-01', 'S-02', 'S-03', 'S-04'].map((n) => ({
        slotNumber: n, type: 'STILT', zone: 'A', floor: 0,
        isHandicapped: false, hasEVCharger: false,
      })),
      // Open parking
      ...['O-01', 'O-02', 'O-03'].map((n) => ({
        slotNumber: n, type: 'OPEN', zone: 'A', floor: null,
        isHandicapped: false, hasEVCharger: false,
      })),
      // Visitor slots
      ...['V-01', 'V-02'].map((n) => ({
        slotNumber: n, type: 'VISITOR', zone: null, floor: null,
        isHandicapped: false, hasEVCharger: false,
      })),
    ];

    let created = 0;
    let skipped = 0;
    const createdSlotIds = [];

    for (const def of slotDefs) {
      const existing = await prisma.parkingSlot.findUnique({
        where: { societyId_slotNumber: { societyId: society.id, slotNumber: def.slotNumber } },
      });
      if (existing) { skipped++; createdSlotIds.push(existing.id); continue; }

      const slot = await prisma.parkingSlot.create({
        data: {
          societyId: society.id,
          slotNumber: def.slotNumber,
          type: def.type,
          zone: def.zone,
          floor: def.floor,
          isHandicapped: def.isHandicapped,
          hasEVCharger: def.hasEVCharger,
          status: 'AVAILABLE',
        },
      });
      createdSlotIds.push(slot.id);
      created++;
    }

    console.log(`  Society "${society.name}": parking slots — ${created} created, ${skipped} skipped`);

    // Create sample allotments (link first 4 non-visitor slots to first 4 units)
    const nonVisitorSlotIds = createdSlotIds.slice(0, Math.min(4, society.units.length));
    const superAdmin = await prisma.user.findFirst({ where: { role: 'SUPER_ADMIN' } });
    const allottedById = superAdmin?.id ?? 'system';

    for (let i = 0; i < nonVisitorSlotIds.length; i++) {
      const slotId = nonVisitorSlotIds[i];
      const unitId = society.units[i]?.id;
      if (!unitId) continue;

      const existingAllotment = await prisma.parkingAllotment.findFirst({
        where: { slotId, status: 'ACTIVE' },
      });
      if (existingAllotment) continue;

      // Find a vehicle for this unit if any
      const vehicle = society.vehicles.find((v) => v.unitId === unitId);

      await prisma.$transaction([
        prisma.parkingAllotment.create({
          data: {
            societyId: society.id,
            slotId,
            unitId,
            vehicleId: vehicle?.id ?? null,
            allottedById,
            status: 'ACTIVE',
          },
        }),
        prisma.parkingSlot.update({ where: { id: slotId }, data: { status: 'OCCUPIED' } }),
      ]);
    }

    const allotmentCount = Math.min(nonVisitorSlotIds.length, society.units.length);
    console.log(`  Society "${society.name}": ${allotmentCount} sample allotments created`);
  }

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
