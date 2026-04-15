const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const { pushToSociety } = require('../../utils/push');

// Schema: Notice { societyId, title, body, pinned, createdById, expiresAt }
// Relation: creator User @relation("createdNotices", fields:[createdById])

const createNotice = async (req, res) => {
  try {
    const { societyId, id: createdById } = req.user;
    const { title, body, pinned, expiresAt } = req.body;
    if (!title || !body) return sendError(res, 'title and body are required', 400);

    const notice = await prisma.notice.create({
      data: {
        societyId,
        createdById,
        title,
        body,
        pinned: Boolean(pinned),
        expiresAt: expiresAt ? new Date(expiresAt) : null,
      },
      include: { creator: { select: { id: true, name: true } } },
    });
    // Notify all society members about the new notice
    setImmediate(() => pushToSociety(societyId, {
      title: `📢 ${title}`,
      body: notice.body.length > 100 ? notice.body.slice(0, 97) + '...' : notice.body,
      data: { type: 'NOTICE_NEW', route: '/notices', id: notice.id },
    }, { excludeUserId: createdById }));

    return sendSuccess(res, notice, 'Notice posted', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getNotices = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { page = 1, limit = 20, pinned } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (pinned !== undefined) where.pinned = pinned === 'true';

    const [notices, total] = await Promise.all([
      prisma.notice.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: { creator: { select: { id: true, name: true } } },
        orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
      }),
      prisma.notice.count({ where }),
    ]);

    return sendSuccess(res, { notices, total, page: parseInt(page), limit: parseInt(limit) }, 'Notices retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const updateNotice = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { title, body, pinned, expiresAt } = req.body;

    const notice = await prisma.notice.findUnique({ where: { id } });
    if (!notice || notice.societyId !== societyId) return sendError(res, 'Notice not found', 404);

    const updateData = {};
    if (title !== undefined) updateData.title = title;
    if (body !== undefined) updateData.body = body;
    if (pinned !== undefined) updateData.pinned = Boolean(pinned);
    if (expiresAt !== undefined) updateData.expiresAt = expiresAt ? new Date(expiresAt) : null;

    const updated = await prisma.notice.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Notice updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const deleteNotice = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const notice = await prisma.notice.findUnique({ where: { id } });
    if (!notice || notice.societyId !== societyId) return sendError(res, 'Notice not found', 404);

    await prisma.notice.delete({ where: { id } });
    return sendSuccess(res, null, 'Notice deleted');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { createNotice, getNotices, updateNotice, deleteNotice };
