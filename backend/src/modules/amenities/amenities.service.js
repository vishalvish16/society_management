const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const amenityService = {
  
  async getAllAmenities(societyId) {
    const db = await prisma.$connect();

    try {
      return await amenityController.getAllAmenits(db);
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = amenityService;
