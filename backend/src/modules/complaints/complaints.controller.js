const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const { pushToUsers, pushToRole } = require('../../utils/push');

const createComplaint = async (req, res) => {
  try {
    const { societyId, id: raisedById } = req.user;
    const { title, description, category, unitId } = req.body;
    if (!title || !category) return sendError(res, 'title and category are required', 400);

    const complaint = await prisma.complaint.create({
      data: { societyId, raisedById, title, description, category: category.toUpperCase(), unitId: unitId || null },
      include: { raisedBy: { select: { name: true } } },
    });

    // Notify admins about new complaint
    setImmediate(() => pushToRole(societyId, 'PRAMUKH', {
      title: '🔔 New Complaint Raised',
      body: `${complaint.raisedBy.name}: ${title}`,
      data: { type: 'COMPLAINT_NEW', route: '/complaints', id: complaint.id },
    }));

    return sendSuccess(res, complaint, 'Complaint raised', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getComplaints = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { status, category, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (status) where.status = status.toUpperCase();
    if (category) where.category = category.toUpperCase();

    const [complaints, total] = await Promise.all([
      prisma.complaint.findMany({
        where, skip, take: parseInt(limit),
        include: {
          raisedBy: { select: { name: true, phone: true } },
          unit: { select: { fullCode: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.complaint.count({ where }),
    ]);

    return sendSuccess(res, { complaints, total, page: parseInt(page), limit: parseInt(limit) }, 'Complaints retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getComplaintById = async (req, res) => {
  try {
    const { societyId } = req.user;
    const complaint = await prisma.complaint.findUnique({
      where: { id: req.params.id },
      include: {
        raisedBy: { select: { name: true, phone: true } },
        assignedTo: { select: { name: true } },
        unit: { select: { fullCode: true } },
      },
    });
    if (!complaint || complaint.societyId !== societyId) return sendError(res, 'Complaint not found', 404);
    return sendSuccess(res, complaint);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const updateComplaint = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { status, assignedToId, resolutionNote } = req.body;

    const complaint = await prisma.complaint.findUnique({
      where: { id },
      include: { raisedBy: { select: { id: true, name: true } } },
    });
    if (!complaint || complaint.societyId !== societyId) return sendError(res, 'Complaint not found', 404);

    const updateData = {};
    if (status) updateData.status = status.toUpperCase();
    if (assignedToId !== undefined) updateData.assignedToId = assignedToId;
    if (resolutionNote !== undefined) updateData.resolutionNote = resolutionNote;
    if (status?.toLowerCase() === 'resolved') updateData.resolvedAt = new Date();

    const updated = await prisma.complaint.update({ where: { id }, data: updateData });

    // Notify the person who raised the complaint on status change
    if (status && complaint.raisedById) {
      const statusLabel = status.toUpperCase();
      const messages = {
        IN_PROGRESS: { title: '🔧 Complaint In Progress', body: `Your complaint "${complaint.title}" is being worked on.` },
        RESOLVED:    { title: '✅ Complaint Resolved',    body: `Your complaint "${complaint.title}" has been resolved.` },
        CLOSED:      { title: '📋 Complaint Closed',      body: `Your complaint "${complaint.title}" has been closed.` },
      };
      const msg = messages[statusLabel];
      if (msg) {
        setImmediate(() => pushToUsers([complaint.raisedById], {
          ...msg,
          data: { type: 'COMPLAINT_UPDATE', route: '/complaints', id: complaint.id },
        }));
      }
    }

    return sendSuccess(res, updated, 'Complaint updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const deleteComplaint = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const complaint = await prisma.complaint.findUnique({ where: { id } });
    if (!complaint || complaint.societyId !== societyId) return sendError(res, 'Complaint not found', 404);
    await prisma.complaint.delete({ where: { id } });
    return sendSuccess(res, null, 'Complaint deleted');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { createComplaint, getComplaints, getComplaintById, updateComplaint, deleteComplaint };
