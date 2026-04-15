const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const gatepassService = {
  
  async createGatePass(userId, reason) {
    try {
      // Check if the user exists
      const user = await prisma.user.findUnique({ where: { id: userId } });

      if (!user) {
        throw new Error('User not found');
      }

      return await prisma.gatePass.create({
        data: { user_id: userId, reason },
      });
    } catch (error) {
      console.error(error);
      throw error;
    }
  },
};

module.exports = gatepassService;
