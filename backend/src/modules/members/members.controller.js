const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getMembers = async (req, res) => {
  try {
    const { societyId } = req.user;
    const users = await prisma.user.findMany({
      where: { societyId, isActive: true, role: { not: 'super_admin' } },
      select: { id: true, name: true, email: true, phone: true, role: true,
                unitResidents: { select: { unit: { select: { fullCode: true } } } } },
    });
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const updateMember = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { name, email, phone } = req.body;
    const user = await prisma.user.updateMany({
      where: { id, societyId },
      data: { name, email, phone },
    });
    res.json({ updated: user.count });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const deleteMember = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    await prisma.user.updateMany({
      where: { id, societyId },
      data: { isActive: false, deletedAt: new Date() },
    });
    res.json({ message: 'Member deactivated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = { getMembers, updateMember, deleteMember };
