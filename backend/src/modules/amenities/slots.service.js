const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const slotService = {
  
  async createSlot(amenityId, startTime, endTime) {
    const db = await prisma.$connect();

    try {
      // Check if the amenity exists
      const amenity = await userService.getAmenityById(db, amenityId);

      if (!amenity) {
        throw new Error('Amenity not found');
      }

      return await prisma.parkingSlot.create({
        data: { amenity_id: amenityId, startTime, endTime },
      });
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = slotService;
