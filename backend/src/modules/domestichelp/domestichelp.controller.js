const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const userService = require('../users/users.service');

const domestichelpController = {
  
  async createDomesticHelp(req, res) {
    const name = req.body.name;
    const phone = req.body.phone;
    
    try {
      const db = await prisma.$connect();

      // Create a user and domestic help entry
      const userId = await userService.createOrUpdateUser(db, { name, phone });

      return res.status(201).json({ id: userId });
    } catch (error) {
      console.error(error);
      return res.status(500).json({ message: 'Failed to create domestic help' });
    } finally {
      await prisma.$disconnect();
    }
  },
  
  async getCodeById(req, res) {
    const { id } = req.params;
    
    try {
      const db = await prisma.$connect();

      const code = await userService.getCodeByUserId(db, parseInt(id));
      
      return res.status(200).json({ code });
    } catch (error) {
      console.error(error);
      return res.status(500).json({ message: 'Failed to fetch domestic help' });
    } finally {
      await prisma.$disconnect();
    }
  },
};

module.exports = domestichelpController;
