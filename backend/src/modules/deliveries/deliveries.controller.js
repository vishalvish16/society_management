const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');
const { sendSuccess, sendError } = require('../../utils/response');
const { isResidentLikeRole, userHasUnit, unitIdsForUser } = require('../../utils/unitResident');

// GET /api/deliveries
exports.getAllDeliveries = async (req, res) => {
  try {
    const { societyId, id: userId, role } = req.user;
    const { unitId, status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (isResidentLikeRole(role)) {
      const ids = await unitIdsForUser(userId, societyId);
      if (!ids.length) {
        return sendSuccess(
          res,
          { deliveries: [], total: 0, page: parseInt(page), limit: parseInt(limit) },
          'Deliveries retrieved'
        );
      }
      if (unitId && !ids.includes(unitId)) {
        return sendError(res, 'You can only view deliveries for your own unit', 403);
      }
      where.unitId = unitId ? unitId : { in: ids };
    } else if (unitId) {
      where.unitId = unitId;
    }
    if (status) where.status = status.toUpperCase();

    const [deliveries, total] = await Promise.all([
      prisma.delivery.findMany({
        where,
        skip,
        take: parseInt(limit),
        orderBy: { createdAt: 'desc' },
        include: { unit: { select: { fullCode: true } } },
      }),
      prisma.delivery.count({ where }),
    ]);

    return sendSuccess(res, { deliveries, total, page: parseInt(page), limit: parseInt(limit) }, 'Deliveries retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/deliveries  (Watchman logs a delivery; residents log for their own unit)
exports.createDelivery = async (req, res) => {
  try {
    const { societyId, id: loggedById, role } = req.user;
    const { unitId, agentName, company, description } = req.body;

    if (!unitId || !agentName) {
      return sendError(res, 'unitId and agentName are required', 400);
    }

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) {
      return sendError(res, 'Unit not found in your society', 404);
    }

    if (isResidentLikeRole(role)) {
      const allowed = await userHasUnit(loggedById, societyId, unitId);
      if (!allowed) {
        return sendError(res, 'You can only log deliveries for your own unit', 403);
      }
    }

    const delivery = await prisma.delivery.create({
      data: {
        societyId,
        unitId,
        loggedById,
        agentName,
        company: company || null,
        description: description || null,
        status: 'PENDING',
        notifiedAt: new Date(),
      },
    });

    // Notify unit residents about the delivery (exclude the watchman who logged it)
    setImmediate(() => notificationsService.sendNotification(loggedById, societyId, {
      targetType: 'unit',
      targetId: unitId,
      title: '📦 Delivery Arrived',
      body: `${agentName}${company ? ` (${company})` : ''} has a delivery for ${unit.fullCode}. Please respond.`,
      type: 'DELIVERY',
      route: '/deliveries',
      excludeUserId: loggedById
    }));

    return sendSuccess(res, delivery, 'Delivery logged', 201);
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/deliveries/today  (Watchman sees today's deliveries)
exports.getTodayDeliveries = async (req, res) => {
  try {
    const { societyId } = req.user;
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const deliveries = await prisma.delivery.findMany({
      where: { societyId, createdAt: { gte: startOfDay } },
      orderBy: { createdAt: 'desc' },
      include: { unit: { select: { fullCode: true } } },
    });
    return sendSuccess(res, deliveries, "Today's deliveries retrieved");
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/deliveries/mine  (Resident sees own unit deliveries)
exports.getMyDeliveries = async (req, res) => {
  try {
    const { societyId, id: userId, unitId: activeUnitId } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Strict: scope to the active unit for this login if available.
    // Fallback: all units for this user within this society.
    let unitIds = [];
    if (activeUnitId) {
      unitIds = [activeUnitId];
    } else {
      const unitResidents = await prisma.unitResident.findMany({
        where: { userId, unit: { societyId } },
        select: { unitId: true },
      });
      unitIds = unitResidents.map((ur) => ur.unitId);
    }

    const where = { societyId, unitId: { in: unitIds } };
    if (status) where.status = status;

    const [deliveries, total] = await Promise.all([
      prisma.delivery.findMany({
        where, skip, take: parseInt(limit),
        orderBy: { createdAt: 'desc' },
        include: { unit: { select: { fullCode: true } } },
      }),
      prisma.delivery.count({ where }),
    ]);

    return sendSuccess(res, { deliveries, total, page: parseInt(page), limit: parseInt(limit) }, 'Your deliveries retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/deliveries/:id/respond  (Resident responds: allow/deny/left_at_gate)
exports.respondToDelivery = async (req, res) => {
  try {
    const { societyId, id: respondedBy, role } = req.user;
    const { id } = req.params;
    const { action } = req.body; // 'ALLOWED' | 'DENIED' | 'LEFT_AT_GATE'
    const ActionUpper = (action || '').toUpperCase();

    if (!['ALLOWED', 'DENIED', 'LEFT_AT_GATE'].includes(ActionUpper)) {
      return sendError(res, 'action must be ALLOWED, DENIED, or LEFT_AT_GATE', 400);
    }

    const delivery = await prisma.delivery.findUnique({
      where: { id },
      include: { unit: { select: { fullCode: true } } },
    });
    if (!delivery || delivery.societyId !== societyId) {
      return sendError(res, 'Delivery not found', 404);
    }

    if (isResidentLikeRole(role)) {
      const allowed = await userHasUnit(respondedBy, societyId, delivery.unitId);
      if (!allowed) {
        return sendError(res, 'You can only respond to deliveries for your own unit', 403);
      }
    }
    if (delivery.status !== 'PENDING') {
      return sendError(res, `Delivery already ${delivery.status}`, 400);
    }

    const updated = await prisma.delivery.update({
      where: { id },
      data: { status: ActionUpper, respondedAt: new Date(), respondedBy },
    });

    // Notify watchman via socket when resident chooses LEFT_AT_GATE
    if (ActionUpper === 'LEFT_AT_GATE') {
      const io = req.app.get('io');
      if (io) {
        io.to(`society_${societyId}_watchman`).emit('delivery_drop_at_gate', {
          deliveryId: id,
          agentName: delivery.agentName,
          unitCode: delivery.unit?.fullCode,
          message: 'Resident chose "Drop at Gate" — please take a photo of the parcel.',
        });
      }

      setImmediate(() => notificationsService.sendNotification(respondedBy, societyId, {
        targetType: 'role',
        targetId: 'WATCHMAN',
        title: '📦 Drop at Gate',
        body: `${delivery.agentName} delivery for ${delivery.unit?.fullCode} — resident chose Drop at Gate. Please photograph the parcel.`,
        type: 'DELIVERY',
        route: '/deliveries',
      }));
    }

    return sendSuccess(res, updated, `Delivery ${action}`);
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/deliveries/:id/collect  (Watchman marks collected)
exports.markCollected = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const delivery = await prisma.delivery.findUnique({ where: { id } });
    if (!delivery || delivery.societyId !== societyId) {
      return sendError(res, 'Delivery not found', 404);
    }
    if (!['PENDING', 'ALLOWED'].includes(delivery.status)) {
      return sendError(res, `Delivery is already ${delivery.status}`, 400);
    }

    const updated = await prisma.delivery.update({
      where: { id },
      data: { status: 'COLLECTED', collectedAt: new Date() },
    });

    return sendSuccess(res, updated, 'Delivery marked as collected');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/deliveries/:id/return  (Watchman marks returned to sender)
exports.markReturned = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const delivery = await prisma.delivery.findUnique({ where: { id } });
    if (!delivery || delivery.societyId !== societyId) {
      return sendError(res, 'Delivery not found', 404);
    }
    if (!['PENDING', 'DENIED'].includes(delivery.status)) {
      return sendError(res, `Delivery is already ${delivery.status}`, 400);
    }

    const updated = await prisma.delivery.update({
      where: { id },
      data: { status: 'RETURNED', returnedAt: new Date() },
    });

    return sendSuccess(res, updated, 'Delivery marked as returned');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/deliveries/:id/drop-photo  (Watchman uploads parcel photo for LEFT_AT_GATE)
exports.uploadDropPhoto = async (req, res) => {
  try {
    const { societyId, id: watchmanId } = req.user;
    const { id } = req.params;

    const delivery = await prisma.delivery.findUnique({
      where: { id },
      include: { unit: { select: { fullCode: true } } },
    });
    if (!delivery || delivery.societyId !== societyId) {
      return sendError(res, 'Delivery not found', 404);
    }
    if (delivery.status !== 'LEFT_AT_GATE') {
      return sendError(res, 'Parcel photo only applies to LEFT_AT_GATE deliveries', 400);
    }
    if (!req.file) {
      return sendError(res, 'Photo is required', 400);
    }

    const photoUrl = `/uploads/deliveries/${req.file.filename}`;
    const updated = await prisma.delivery.update({
      where: { id },
      data: { photoUrl, droppedAt: new Date() },
    });

    // Notify unit residents the parcel has been left and photographed
    setImmediate(() => notificationsService.sendNotification(watchmanId, societyId, {
      targetType: 'unit',
      targetId: delivery.unitId,
      title: '📦 Parcel Left at Gate',
      body: `Your parcel from ${delivery.agentName} has been left at the gate and photographed by the watchman.`,
      type: 'DELIVERY',
      route: '/deliveries',
    }));

    return sendSuccess(res, updated, 'Parcel photo uploaded');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
