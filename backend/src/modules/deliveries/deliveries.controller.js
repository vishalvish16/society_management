const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const { pushToUnit } = require('../../utils/push');

// GET /api/deliveries
exports.getAllDeliveries = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { unitId, status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (unitId) where.unitId = unitId;
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

// POST /api/deliveries  (Watchman logs a delivery)
exports.createDelivery = async (req, res) => {
  try {
    const { societyId, id: loggedById } = req.user;
    const { unitId, agentName, company, description } = req.body;

    if (!unitId || !agentName) {
      return sendError(res, 'unitId and agentName are required', 400);
    }

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) {
      return sendError(res, 'Unit not found in your society', 404);
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
    setImmediate(() => pushToUnit(unitId, {
      title: '📦 Delivery Arrived',
      body: `${agentName}${company ? ` (${company})` : ''} has a delivery for ${unit.fullCode}. Please respond.`,
      data: { type: 'DELIVERY_NEW', route: '/deliveries', id: delivery.id },
    }, { excludeUserId: loggedById }));

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
    const { societyId, id: userId } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const unitResidents = await prisma.unitResident.findMany({ where: { userId }, select: { unitId: true } });
    const unitIds = unitResidents.map((ur) => ur.unitId);

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

// PATCH /api/deliveries/:id/respond  (Resident responds: allow/deny)
exports.respondToDelivery = async (req, res) => {
  try {
    const { societyId, id: respondedBy } = req.user;
    const { id } = req.params;
    const { action } = req.body; // 'ALLOWED' | 'DENIED'
    const ActionUpper = (action || '').toUpperCase();

    if (!['ALLOWED', 'DENIED'].includes(ActionUpper)) {
      return sendError(res, 'action must be allowed or denied', 400);
    }

    const delivery = await prisma.delivery.findUnique({ where: { id } });
    if (!delivery || delivery.societyId !== societyId) {
      return sendError(res, 'Delivery not found', 404);
    }
    if (delivery.status !== 'PENDING') {
      return sendError(res, `Delivery already ${delivery.status}`, 400);
    }

    const updated = await prisma.delivery.update({
      where: { id },
      data: { status: ActionUpper, respondedAt: new Date(), respondedBy },
    });

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

    const updated = await prisma.delivery.update({
      where: { id },
      data: { status: 'COLLECTED', collectedAt: new Date() },
    });

    return sendSuccess(res, updated, 'Delivery marked as collected');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
