const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const staffController = {
  
  async getAllStaffMembers(req, res) {
    const societyId = parseInt(req.query.societyId);
    
    try {
      const db = await prisma.$connect();

      const staffMembers = await db.staff.findMany({
        where: { society_id: societyId },
        include: { user: true }
      });

      return res.status(200).json(staffMembers);
    } catch (error) {
      console.error(error);
      return res.status(500).json({ message: 'Failed to fetch staff members' });
    } finally {
      await prisma.$disconnect();
    }
  },
  
  async createStaffMember(req, res) {
    const { userId, designation, phone } = req.body;
    
    try {
      const newStaffMember = await prisma.staff.create({
        data: { user_id: userId, designation, phone },
      });

      return res.status(201).json(newStaffMember);
    } catch (error) {
      console.error(error);
      return res.status(500).json({ message: 'Failed to create staff member' });
    }
  },
  
  async deleteStaffMemberById(req, res) {
    const id = parseInt(req.params.id);

    try {
      await prisma.staff.delete({
        where: { id },
      });

      return res.status(204).send();
    } catch (error) {
      console.error(error);
      return res.status(500).json({ message: 'Failed to delete staff member' });
    }
  },
};

module.exports = staffController;
