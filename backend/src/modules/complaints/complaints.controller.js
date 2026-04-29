const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');
const { sendSuccess, sendError } = require('../../utils/response');

const createComplaint = async (req, res) => {
  try {
    const { societyId, id: raisedById, role, unitId: activeUnitId } = req.user;
    const { title, description, category, unitId, priority } = req.body;
    if (!title || !category) return sendError(res, 'title and category are required', 400);

    // Residents/Members can only raise complaints for their active unit.
    const roleUpper = String(role || '').toUpperCase();
    const finalUnitId =
      (roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') && activeUnitId
        ? activeUnitId
        : (unitId || null);

    const complaint = await prisma.complaint.create({
      data: {
        societyId,
        raisedById,
        title,
        description,
        category: category.toUpperCase(),
        unitId: finalUnitId,
        priority: priority || 'medium',
      },
      include: { raisedBy: { select: { name: true } } },
    });

    if (req.files && req.files.length > 0) {
      const attachmentsData = req.files.map(f => ({
        complaintId: complaint.id,
        fileName: f.originalname,
        fileType: f.mimetype,
        fileSize: f.size,
        fileUrl: `/uploads/complaints/${f.filename}`,
      }));
      await prisma.complaintAttachment.createMany({ data: attachmentsData });
      // include attachments in the response
      complaint.attachments = await prisma.complaintAttachment.findMany({ where: { complaintId: complaint.id } });
    }

    // Notify admins about new complaint
    setImmediate(() => notificationsService.sendNotification(raisedById, societyId, {
      targetType: 'role',
      targetId: 'PRAMUKH',
      title: ' New Complaint Raised',
      body: `${complaint.raisedBy.name}: ${title}`,
      type: 'COMPLAINT',
      route: '/complaints'
    }));

    return sendSuccess(res, complaint, 'Complaint raised', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getComplaints = async (req, res) => {
  try {
    const { societyId, role, unitId: activeUnitId } = req.user;
    const { status, category, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    const normalizeFilter = (v) => {
      if (v === undefined || v === null) return null;
      const s = String(v).trim();
      if (!s) return null;
      const upper = s.toUpperCase();
      if (upper === 'ALL' || upper === 'NULL' || upper === 'UNDEFINED') return null;
      return upper;
    };

    const normalizedStatus = normalizeFilter(status);
    const normalizedCategory = normalizeFilter(category);
    if (normalizedStatus) where.status = normalizedStatus;
    if (normalizedCategory) where.category = normalizedCategory;
    // Residents/Members only see complaints for their active unit.
    const roleUpper = String(role || '').toUpperCase();
    if ((roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') && activeUnitId) {
      where.unitId = activeUnitId;
    }

    const [complaints, total] = await Promise.all([
      prisma.complaint.findMany({
        where, skip, take: parseInt(limit),
        include: {
          raisedBy: { select: { name: true, phone: true } },
          assignedTo: { select: { name: true } },
          updatedBy: { select: { name: true } },
          unit: { select: { fullCode: true } },
          attachments: true,
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
        updatedBy: { select: { name: true } },
        unit: { select: { fullCode: true } },
        attachments: true,
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
    const { societyId, id: currentUserId } = req.user;
    const { id } = req.params;
    const { status, assignedToId, resolutionNote, amount, paidAmount, paymentMethod, transactionId } = req.body;
    const userRole = req.user.role.toUpperCase();

    const complaint = await prisma.complaint.findUnique({
      where: { id },
      include: {
        raisedBy: { select: { id: true, name: true } },
        assignedTo: { select: { name: true } },
      },
    });
    if (!complaint || complaint.societyId !== societyId) return sendError(res, 'Complaint not found', 404);

    // Only PRAMUKH or CHAIRMAN can record manual payments
    if (paidAmount !== undefined && !['PRAMUKH', 'CHAIRMAN'].includes(userRole)) {
      return sendError(res, 'Only Pramukh or Chairman can record manual payments', 403);
    }

    const updateData = { updatedById: currentUserId };
    if (status) updateData.status = status.toUpperCase();
    if (assignedToId !== undefined) updateData.assignedToId = assignedToId || null;
    if (resolutionNote !== undefined) updateData.resolutionNote = resolutionNote;
    if (status?.toUpperCase() === 'RESOLVED') updateData.resolvedAt = new Date();
    // Auto-set ASSIGNED when assignee is set
    if (assignedToId && !status) updateData.status = 'ASSIGNED';

    if (amount !== undefined) updateData.amount = amount;
    if (paidAmount !== undefined) {
      updateData.paidAmount = paidAmount;
      updateData.paidAt = new Date();
      if (paymentMethod) updateData.paymentMethod = paymentMethod;
      if (transactionId) updateData.transactionId = transactionId;
    }

    // Recalculate payment status if relevant fields changed
    if (amount !== undefined || paidAmount !== undefined) {
      const curAmount = Number(amount !== undefined ? amount : complaint.amount);
      const curPaid = Number(paidAmount !== undefined ? paidAmount : complaint.paidAmount);
      if (curPaid >= curAmount && curAmount > 0) {
        updateData.paymentStatus = 'PAID';
      } else if (curPaid > 0) {
        updateData.paymentStatus = 'PARTIAL';
      } else {
        updateData.paymentStatus = 'UNPAID';
      }
    }

    const updated = await prisma.complaint.update({
      where: { id },
      data: updateData,
      include: {
        raisedBy: { select: { name: true, phone: true } },
        assignedTo: { select: { name: true } },
        updatedBy: { select: { name: true } },
        unit: { select: { fullCode: true } },
        attachments: true,
      },
    });

    // Notify the person who raised the complaint on status change
    if (status && complaint.raisedById) {
      const statusLabel = status.toUpperCase();
      const messages = {
        ASSIGNED:    { title: '👤 Complaint Assigned',    body: `Your complaint "${complaint.title}" has been assigned and will be addressed soon.` },
        IN_PROGRESS: { title: '🔧 Complaint In Progress', body: `Your complaint "${complaint.title}" is being worked on.` },
        RESOLVED:    { title: '✅ Complaint Resolved',    body: `Your complaint "${complaint.title}" has been resolved.` },
        CLOSED:      { title: '📋 Complaint Closed',      body: `Your complaint "${complaint.title}" has been closed.` },
      };
      const msg = messages[statusLabel];
      if (msg) {
        setImmediate(() => notificationsService.sendNotification(req.user.id, societyId, {
          targetType: 'user',
          targetId: complaint.raisedById,
          title: msg.title,
          body: msg.body,
          type: 'COMPLAINT',
          route: '/complaints'
        }));
      }
    }
    // Notify assignee when assigned
    if (assignedToId && assignedToId !== complaint.assignedToId) {
      setImmediate(() => notificationsService.sendNotification(req.user.id, societyId, {
        targetType: 'user',
        targetId: assignedToId,
        title: '📋 Complaint Assigned To You',
        body: `You have been assigned complaint: "${complaint.title}"`,
        type: 'COMPLAINT',
        route: '/complaints'
      }));
    }

    return sendSuccess(res, updated, 'Complaint updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const deleteComplaint = async (req, res) => {
  try {
    const { societyId, id: deletedById, name: deletedByName } = req.user;
    const { id } = req.params;
    const complaint = await prisma.complaint.findUnique({ where: { id } });
    if (!complaint || complaint.societyId !== societyId) return sendError(res, 'Complaint not found', 404);
    // Record who deleted before removing
    await prisma.complaint.update({ where: { id }, data: { deletedById } });
    await prisma.complaint.delete({ where: { id } });
    return sendSuccess(res, { deletedBy: deletedByName ?? null }, 'Complaint deleted');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { createComplaint, getComplaints, getComplaintById, updateComplaint, deleteComplaint };
