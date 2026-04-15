const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const userService = require('../users/users.service');

const bookingService = {
  
  async createBooking(amenityId, userId) {
    try {
      // Check if the user exists
      const db = await prisma.$connect();
      const user = await userService.getUserById(db, userId);

      if (!user) {
        throw new Error('User not found');
      }

      return await prisma.amenityBooking.create({
        data: { amenity_id: amenityId, user_id: userId },
      });
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = bookingService;
