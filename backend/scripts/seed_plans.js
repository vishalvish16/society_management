
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Seeding Pricing Plans...');

  const plans = [
    {
      name: 'basic',
      displayName: 'Basic 🟢',
      priceMonthly: 0,
      priceYearly: 0,
      pricePerUnit: 5.0,
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
      pricePerUnit: 8.0,
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
      pricePerUnit: 12.0,
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
        expenses: true,
        expense_approval: true,
        bill_schedules: true,
        financial_reports: true,
        donations: true,
        attachments_count: -1,
      },
    }
  ];

  for (const plan of plans) {
    await prisma.plan.upsert({
      where: { name: plan.name },
      update: plan,
      create: plan,
    });
    console.log(`Upserted plan: ${plan.name}`);
  }

  console.log('Plans seeded successfully.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
