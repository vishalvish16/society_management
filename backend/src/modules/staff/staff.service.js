const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const userService = require('../users/users.service');

const staffService = {
  
  async getAllStaffMembers(societyId) {
    const db = await prisma.$connect();

    try {
      return await prisma.staff.findMany({
        where: { society_id: societyId },
        include: { user: true }
      });
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
  
  async createStaffMember(userId, designation, phone) {
    const db = await prisma.$connect();

    try {
      return await userService.createOrUpdateUser(db, { id: userId });
    } catch (error) {
      console.error(error);
      throw error;
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = staffService;
