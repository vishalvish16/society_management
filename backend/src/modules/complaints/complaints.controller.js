const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const createComplaint = async (req, res) => {
  try {
    const { societyId, id: raisedById } = req.user;
    const { title, description, category, unitId } = req.body;
    const complaint = await prisma.complaint.create({
      data: { societyId, raisedById, title, description, category, unitId },
    });
    res.status(201).json(complaint);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const getComplaints = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { status } = req.query;
    const complaints = await prisma.complaint.findMany({
      where: { societyId, ...(status ? { status } : {}) },
      include: { raisedBy: { select: { name: true, phone: true } },
                 unit: { select: { fullCode: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json(complaints);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const updateComplaint = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const updated = await prisma.complaint.updateMany({
      where: { id, societyId },
      data: req.body,
    });
    res.json({ updated: updated.count });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const deleteComplaint = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    await prisma.complaint.deleteMany({ where: { id, societyId } });
    res.json({ message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = { createComplaint, getComplaints, updateComplaint, deleteComplaint };
