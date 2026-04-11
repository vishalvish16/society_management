const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const createNotice = async (req, res) => {
  try {
    const { societyId, id: postedById } = req.user;
    const { title, content, category } = req.body;
    const notice = await prisma.notice.create({
      data: { societyId, postedById, title, content, category },
    });
    res.status(201).json(notice);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const getNotices = async (req, res) => {
  try {
    const { societyId } = req.user;
    const notices = await prisma.notice.findMany({
      where: { societyId },
      include: { postedBy: { select: { name: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json(notices);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const updateNotice = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const updated = await prisma.notice.updateMany({
      where: { id, societyId },
      data: req.body,
    });
    res.json({ updated: updated.count });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const deleteNotice = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    await prisma.notice.deleteMany({ where: { id, societyId } });
    res.json({ message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = { createNotice, getNotices, updateNotice, deleteNotice };
