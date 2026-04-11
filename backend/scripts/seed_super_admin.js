const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const SALT_ROUNDS = 12;

async function seed() {
  try {
    const email = 'vishal.vish16@gmail.com';
    const phone = '7405309724';
    const password = 'Admin@123';

    // Check if user already exists
    const existing = await prisma.user.findFirst({
      where: {
        OR: [{ email }, { phone }]
      }
    });

    if (existing) {
      console.log('User with this email or phone already exists!');
      process.exit(0);
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const superAdmin = await prisma.user.create({
      data: {
        name: 'Vishal (Super Admin)',
        email,
        phone,
        passwordHash,
        role: 'SUPER_ADMIN',
        isActive: true
      }
    });

    console.log('Super Admin created successfully:', superAdmin.id);
  } catch (error) {
    console.error('Error seeding super admin:', error);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
