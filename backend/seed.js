
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const prisma = new PrismaClient();

async function main() {
  const hash = await bcrypt.hash('Admin@123', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@society.com' },
    update: {},
    create: { name: 'Super Admin', phone: '9999999999', email: 'admin@society.com', passwordHash: hash, role: 'SUPER_ADMIN' },
  });
  console.log('super_admin:', admin.email, admin.phone);

  let plan = await prisma.plan.findFirst();
  if (!plan) {
    plan = await prisma.plan.create({
      data: { name: 'basic', displayName: 'Basic Plan', priceMonthly: 999, priceYearly: 9999, maxUnits: 50, maxSecretaries: 2, features: {} },
    });
  }

  let society = await prisma.society.findFirst();
  if (!society) {
    society = await prisma.society.create({
      data: { name: 'Green Valley CHS', city: 'Mumbai', planId: plan.id, planStartDate: new Date(), planRenewalDate: new Date(Date.now() + 365*24*60*60*1000) },
    });
  }

  await prisma.user.upsert({
    where: { email: 'pramukh@society.com' },
    update: {},
    create: { name: 'Rajesh Pramukh', phone: '9888888888', email: 'pramukh@society.com', passwordHash: hash, role: 'PRAMUKH', societyId: society.id },
  });
  console.log('pramukh: 9888888888');

  await prisma.user.upsert({
    where: { email: 'resident@society.com' },
    update: {},
    create: { name: 'Priya Resident', phone: '9777777777', email: 'resident@society.com', passwordHash: hash, role: 'RESIDENT', societyId: society.id },
  });
  console.log('resident: 9777777777');

  console.log('All users created. Password: Admin@123');
}

main().catch(console.error).finally(() => prisma.$disconnect());
