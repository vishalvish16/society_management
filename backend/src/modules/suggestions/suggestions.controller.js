const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');
const { sendSuccess, sendError } = require('../../utils/response');

const createSuggestion = async (req, res) => {
  try {
    const { societyId, id: raisedById, role, unitId: activeUnitId } = req.user;
    const { title, description, category, unitId, priority } = req.body;
    if (!title || !category || !unitId) return sendError(res, 'title, category, and unitId are required', 400);

    // Residents/Members can only submit suggestions for their active unit.
    const roleUpper = String(role || '').toUpperCase();
    const finalUnitId =
      (roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') && activeUnitId
        ? activeUnitId
        : unitId;

    const suggestion = await prisma.suggestion.create({
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
      const attachmentsData = req.files.map((f) => ({
        suggestionId: suggestion.id,
        fileName: f.originalname,
        fileType: f.mimetype,
        fileSize: f.size,
        fileUrl: `/uploads/suggestions/${f.filename}`,
      }));
      await prisma.suggestionAttachment.createMany({ data: attachmentsData });
      suggestion.attachments = await prisma.suggestionAttachment.findMany({ where: { suggestionId: suggestion.id } });
    }

    // Notify admins about new suggestion (reuse role PRAMUKH as primary notifier)
    setImmediate(() =>
      notificationsService
        .sendNotification(raisedById, societyId, {
          targetType: 'role',
          targetId: 'PRAMUKH',
          title: '💡 New Suggestion Submitted',
          body: `${suggestion.raisedBy.name}: ${title}`,
          type: 'SUGGESTION',
          route: '/suggestions',
        })
        .catch(() => {})
    );

    return sendSuccess(res, suggestion, 'Suggestion submitted', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getSuggestions = async (req, res) => {
  try {
    const { societyId, role, unitId: activeUnitId } = req.user;
    const { status, category, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (status) where.status = status.toUpperCase();
    if (category) where.category = category.toUpperCase();
    // Residents/Members only see suggestions for their active unit.
    const roleUpper = String(role || '').toUpperCase();
    if ((roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') && activeUnitId) {
      where.unitId = activeUnitId;
    }

    const [suggestions, total] = await Promise.all([
      prisma.suggestion.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          raisedBy: { select: { name: true, phone: true } },
          assignedTo: { select: { name: true } },
          updatedBy: { select: { name: true } },
          unit: { select: { fullCode: true } },
          attachments: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.suggestion.count({ where }),
    ]);

    return sendSuccess(res, { suggestions, total, page: parseInt(page), limit: parseInt(limit) }, 'Suggestions retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getSuggestionById = async (req, res) => {
  try {
    const { societyId } = req.user;
    const suggestion = await prisma.suggestion.findUnique({
      where: { id: req.params.id },
      include: {
        raisedBy: { select: { name: true, phone: true } },
        assignedTo: { select: { name: true } },
        updatedBy: { select: { name: true } },
        unit: { select: { fullCode: true } },
        attachments: true,
      },
    });
    if (!suggestion || suggestion.societyId !== societyId) return sendError(res, 'Suggestion not found', 404);
    return sendSuccess(res, suggestion);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const updateSuggestion = async (req, res) => {
  try {
    const { societyId, id: currentUserId } = req.user;
    const { id } = req.params;
    const { status, assignedToId, resolutionNote, amount, paidAmount, paymentMethod, transactionId } = req.body;
    const userRole = req.user.role.toUpperCase();

    const suggestion = await prisma.suggestion.findUnique({
      where: { id },
      include: { raisedBy: { select: { id: true, name: true } } },
    });
    if (!suggestion || suggestion.societyId !== societyId) return sendError(res, 'Suggestion not found', 404);

    // Only PRAMUKH or CHAIRMAN can record manual payments
    if (paidAmount !== undefined && !['PRAMUKH', 'CHAIRMAN'].includes(userRole)) {
      return sendError(res, 'Only Pramukh or Chairman can record manual payments', 403);
    }

    const updateData = { updatedById: currentUserId };
    if (status) updateData.status = status.toUpperCase();
    if (assignedToId !== undefined) updateData.assignedToId = assignedToId || null;
    if (resolutionNote !== undefined) updateData.resolutionNote = resolutionNote;
    if (status?.toUpperCase() === 'RESOLVED') updateData.resolvedAt = new Date();
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
      const curAmount = Number(amount !== undefined ? amount : suggestion.amount);
      const curPaid = Number(paidAmount !== undefined ? paidAmount : suggestion.paidAmount);
      if (curPaid >= curAmount && curAmount > 0) {
        updateData.paymentStatus = 'PAID';
      } else if (curPaid > 0) {
        updateData.paymentStatus = 'PARTIAL';
      } else {
        updateData.paymentStatus = 'UNPAID';
      }
    }

    const updated = await prisma.suggestion.update({
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

    // Notify submitter on status change
    if (status && suggestion.raisedById) {
      const statusLabel = status.toUpperCase();
      const messages = {
        ASSIGNED: { title: '👤 Suggestion Assigned', body: `Your suggestion "${suggestion.title}" has been assigned.` },
        IN_PROGRESS: { title: '🔧 Suggestion In Progress', body: `Your suggestion "${suggestion.title}" is being reviewed.` },
        RESOLVED: { title: '✅ Suggestion Resolved', body: `Your suggestion "${suggestion.title}" has been resolved.` },
        CLOSED: { title: '📋 Suggestion Closed', body: `Your suggestion "${suggestion.title}" has been closed.` },
      };
      const msg = messages[statusLabel];
      if (msg) {
        setImmediate(() =>
          notificationsService
            .sendNotification(req.user.id, societyId, {
              targetType: 'user',
              targetId: suggestion.raisedById,
              title: msg.title,
              body: msg.body,
              type: 'SUGGESTION',
              route: '/suggestions',
            })
            .catch(() => {})
        );
      }
    }

    // Notify assignee when assigned
    if (assignedToId && assignedToId !== suggestion.assignedToId) {
      setImmediate(() =>
        notificationsService
          .sendNotification(req.user.id, societyId, {
            targetType: 'user',
            targetId: assignedToId,
            title: '💡 Suggestion Assigned To You',
            body: `You have been assigned a suggestion: "${suggestion.title}"`,
            type: 'SUGGESTION',
            route: '/suggestions',
          })
          .catch(() => {})
      );
    }

    return sendSuccess(res, updated, 'Suggestion updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const deleteSuggestion = async (req, res) => {
  try {
    const { societyId, id: deletedById, name: deletedByName } = req.user;
    const { id } = req.params;
    const suggestion = await prisma.suggestion.findUnique({ where: { id } });
    if (!suggestion || suggestion.societyId !== societyId) return sendError(res, 'Suggestion not found', 404);
    await prisma.suggestion.update({ where: { id }, data: { deletedById } });
    await prisma.suggestion.delete({ where: { id } });
    return sendSuccess(res, { deletedBy: deletedByName ?? null }, 'Suggestion deleted');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { createSuggestion, getSuggestions, getSuggestionById, updateSuggestion, deleteSuggestion };

