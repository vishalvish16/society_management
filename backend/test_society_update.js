const societiesService = require('./src/modules/societies/societies.service');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function testUpdate() {
  try {
    // 1. Get an existing society
    const society = await prisma.society.findFirst();
    if (!society) {
      console.log('No society found to test update');
      return;
    }

    console.log('Original Society:', {
      name: society.name,
      address: society.address,
      city: society.city,
      contactPhone: society.contactPhone
    });

    const updateData = {
      name: society.name + ' Updated',
      address: 'New Address',
      city: 'New City',
      contactPhone: '1234567890'
    };

    const updated = await societiesService.updateSociety(society.id, updateData);
    console.log('Updated Society:', {
      name: updated.name,
      address: updated.address,
      city: updated.city,
      contactPhone: updated.contactPhone
    });

    // Verify in DB
    const verified = await prisma.society.findUnique({ where: { id: society.id } });
    console.log('Verified in DB:', {
      name: verified.name,
      address: verified.address,
      city: verified.city,
      contactPhone: verified.contactPhone
    });

  } catch (err) {
    console.error('Error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

testUpdate();
