const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const domesticHelpService = {
  
  async createDomesticHelp(name, phone) {
    const db = await prisma.$connect();

    try {
      // Create a user and domestic help entry
      const userId = await userService.createOrUpdateUser(db, { name, phone });

      return { id: userId };
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
  
  async getCodeByUserId(userId) {
    const db = await prisma.$connect();

    try {
      // Fetch the code associated with the user ID
      return await userService.getCodeByUserId(db, userId);
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = domesticHelpService;
