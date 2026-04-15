const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const userService = require('../users/users.service');

const gatepassService = {
  
  async createGatePass(userId, reason) {
    const db = await prisma.$connect();

    try {
      // Check if the user exists
      const user = await userService.getUserById(db, userId);

      if (!user) {
        throw new Error('User not found');
      }

      return await prisma.gatePass.create({
        data: { user_id: userId, reason },
      });
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = gatepassService;
