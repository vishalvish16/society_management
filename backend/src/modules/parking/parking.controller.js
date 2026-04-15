const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// GET /api/parking/slots
exports.listSlots = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { type, assigned, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId, isActive: true };
    if (type) where.type = type;
    if (assigned === 'true') where.unitId = { not: null };
    if (assigned === 'false') where.unitId = null;

    const [slots, total] = await Promise.all([
      prisma.parkingSlot.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: { unit: { select: { fullCode: true, wing: true, unitNumber: true } } },
        orderBy: { slotNumber: 'asc' },
      }),
      prisma.parkingSlot.count({ where }),
    ]);

    return sendSuccess(res, { slots, total, page: parseInt(page), limit: parseInt(limit) }, 'Parking slots retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/slots
exports.createSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { slotNumber, type, notes } = req.body;

    if (!slotNumber || !type) {
      return sendError(res, 'slotNumber and type are required', 400);
    }

    const slot = await prisma.parkingSlot.create({
      data: { societyId, slotNumber, type, notes: notes || null },
    });

    return sendSuccess(res, slot, 'Parking slot created', 201);
  } catch (error) {
    if (error.code === 'P2002') return sendError(res, 'Slot number already exists in this society', 409);
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/slots/:id/assign
exports.assignSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { unitId } = req.body;

    if (!unitId) return sendError(res, 'unitId is required', 400);

    const slot = await prisma.parkingSlot.findUnique({ where: { id } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);
    if (slot.unitId) return sendError(res, 'Slot is already assigned', 400);

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) return sendError(res, 'Unit not found in your society', 404);

    const updated = await prisma.parkingSlot.update({
      where: { id },
      data: { unitId },
      include: { unit: { select: { fullCode: true } } },
    });

    return sendSuccess(res, updated, 'Parking slot assigned');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/slots/:id/unassign
exports.unassignSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const slot = await prisma.parkingSlot.findUnique({ where: { id } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);

    const updated = await prisma.parkingSlot.update({
      where: { id },
      data: { unitId: null },
    });

    return sendSuccess(res, updated, 'Parking slot unassigned');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/slots/:id
exports.updateSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { type, notes, isActive } = req.body;

    const slot = await prisma.parkingSlot.findUnique({ where: { id } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);

    const updateData = {};
    if (type !== undefined) updateData.type = type;
    if (notes !== undefined) updateData.notes = notes;
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);

    const updated = await prisma.parkingSlot.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Slot updated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
