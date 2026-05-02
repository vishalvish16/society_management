const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const parkingNotify = require('./parking.notifications');
const notificationsService = require('../notifications/notifications.service');
const billsService = require('../bills/bills.service');

const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN', 'ASSISTANT_SECRETARY'];

// ─── SLOT MANAGEMENT ─────────────────────────────────────────────────────────

// GET /api/parking/slots
exports.listSlots = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { type, status, zone, floor, hasEVCharger, isHandicapped, page = 1, limit = 50, includeInactive } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (includeInactive !== 'true') where.isActive = true;
    if (type) where.type = type;
    if (status) where.status = status;
    if (zone) where.zone = zone;
    if (floor !== undefined) where.floor = parseInt(floor);
    if (hasEVCharger !== undefined) where.hasEVCharger = hasEVCharger === 'true';
    if (isHandicapped !== undefined) where.isHandicapped = isHandicapped === 'true';

    const [slots, total] = await Promise.all([
      prisma.parkingSlot.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          allotments: {
            where: { status: 'ACTIVE' },
            include: {
              unit: { select: { fullCode: true, wing: true, unitNumber: true } },
              vehicle: { select: { numberPlate: true, type: true, brand: true, colour: true } },
            },
          },
        },
        orderBy: [{ zone: 'asc' }, { floor: 'asc' }, { slotNumber: 'asc' }],
      }),
      prisma.parkingSlot.count({ where }),
    ]);

    return sendSuccess(res, { slots, total, page: parseInt(page), limit: parseInt(limit) }, 'Parking slots retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/parking/slots/available
exports.listAvailableSlots = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { type, zone, floor } = req.query;

    const where = { societyId, isActive: true, status: 'AVAILABLE' };
    if (type) where.type = type;
    if (zone) where.zone = zone;
    if (floor !== undefined) where.floor = parseInt(floor);

    const slots = await prisma.parkingSlot.findMany({
      where,
      orderBy: [{ zone: 'asc' }, { floor: 'asc' }, { slotNumber: 'asc' }],
      select: { id: true, slotNumber: true, type: true, zone: true, floor: true, hasEVCharger: true, isHandicapped: true },
    });

    return sendSuccess(res, slots, 'Available slots retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/parking/slots/:id
exports.getSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const slot = await prisma.parkingSlot.findUnique({
      where: { id },
      include: {
        allotments: {
          include: {
            unit: { select: { fullCode: true, wing: true, unitNumber: true } },
            vehicle: { select: { numberPlate: true, type: true, brand: true, colour: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
        sessions: {
          where: { status: 'ACTIVE' },
          include: {
            vehicle: { select: { numberPlate: true, type: true } },
            linkedUnit: { select: { fullCode: true } },
          },
        },
      },
    });

    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);

    return sendSuccess(res, slot, 'Slot retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/slots
exports.createSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { slotNumber, type, zone, floor, isHandicapped, hasEVCharger, length, width, notes } = req.body;

    if (!slotNumber || !type) return sendError(res, 'slotNumber and type are required', 400);

    const validTypes = ['COVERED', 'OPEN', 'BASEMENT', 'VISITOR', 'STILT', 'RESERVED'];
    if (!validTypes.includes(type)) return sendError(res, `type must be one of: ${validTypes.join(', ')}`, 400);

    const existingSlot = await prisma.parkingSlot.findUnique({
      where: { societyId_slotNumber: { societyId, slotNumber } },
    });

    if (existingSlot) {
      if (!existingSlot.isActive) {
        return sendError(res, `Slot number ${slotNumber} already exists but is deactivated. Please restore it instead of creating a new one.`, 409);
      }
      return sendError(res, 'Slot number already exists in this society', 409);
    }

    const slot = await prisma.parkingSlot.create({
      data: {
        societyId,
        slotNumber,
        type,
        zone: zone || null,
        floor: floor !== undefined ? parseInt(floor) : null,
        isHandicapped: Boolean(isHandicapped),
        hasEVCharger: Boolean(hasEVCharger),
        length: length ? parseFloat(length) : null,
        width: width ? parseFloat(width) : null,
        notes: notes || null,
      },
    });

    return sendSuccess(res, slot, 'Parking slot created', 201);
  } catch (error) {
    if (error.code === 'P2002') return sendError(res, 'Slot number already exists in this society', 409);
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/slots/bulk
exports.bulkCreateSlots = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { slots } = req.body;

    if (!Array.isArray(slots) || slots.length === 0) return sendError(res, 'slots array is required', 400);
    if (slots.length > 200) return sendError(res, 'Cannot create more than 200 slots at once', 400);

    const validTypes = ['COVERED', 'OPEN', 'BASEMENT', 'VISITOR', 'STILT', 'RESERVED'];

    const data = slots.map((s, i) => {
      if (!s.slotNumber || !s.type) throw new Error(`slots[${i}] missing slotNumber or type`);
      if (!validTypes.includes(s.type)) throw new Error(`slots[${i}] invalid type: ${s.type}`);
      return {
        societyId,
        slotNumber: s.slotNumber,
        type: s.type,
        zone: s.zone || null,
        floor: s.floor !== undefined ? parseInt(s.floor) : null,
        isHandicapped: Boolean(s.isHandicapped),
        hasEVCharger: Boolean(s.hasEVCharger),
        notes: s.notes || null,
      };
    });

    const result = await prisma.parkingSlot.createMany({ data, skipDuplicates: true });

    return sendSuccess(res, { created: result.count, attempted: slots.length }, 'Bulk slots created', 201);
  } catch (error) {
    return sendError(res, error.message, 400);
  }
};

// PATCH /api/parking/slots/:id
exports.updateSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { type, zone, floor, isHandicapped, hasEVCharger, length, width, notes, isActive, status } = req.body;

    const slot = await prisma.parkingSlot.findUnique({ where: { id } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);

    const updateData = {};
    if (type !== undefined) updateData.type = type;
    if (zone !== undefined) updateData.zone = zone;
    if (floor !== undefined) updateData.floor = parseInt(floor);
    if (isHandicapped !== undefined) updateData.isHandicapped = Boolean(isHandicapped);
    if (hasEVCharger !== undefined) updateData.hasEVCharger = Boolean(hasEVCharger);
    if (length !== undefined) updateData.length = parseFloat(length);
    if (width !== undefined) updateData.width = parseFloat(width);
    if (notes !== undefined) updateData.notes = notes;
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);
    if (status !== undefined) {
      const value = String(status).toUpperCase();
      const valid = ['AVAILABLE', 'OCCUPIED', 'RESERVED', 'UNDER_MAINTENANCE', 'BLOCKED'];
      if (!valid.includes(value)) return sendError(res, `Invalid status. Must be one of: ${valid.join(', ')}`, 400);
      updateData.status = value;
    }

    const updated = await prisma.parkingSlot.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Slot updated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// DELETE /api/parking/slots/:id (soft delete)
exports.deleteSlot = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const slot = await prisma.parkingSlot.findUnique({ where: { id } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);

    const activeAllotment = await prisma.parkingAllotment.findFirst({ where: { slotId: id, status: 'ACTIVE' } });
    if (activeAllotment) return sendError(res, 'Cannot delete a slot with an active allotment. Release it first.', 400);

    await prisma.parkingSlot.update({ where: { id }, data: { isActive: false, status: 'BLOCKED' } });
    return sendSuccess(res, null, 'Slot deactivated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/parking/map  — floor-wise slot grid
exports.getParkingMap = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { zone } = req.query;

    const where = { societyId, isActive: true };
    if (zone) where.zone = zone;

    const slots = await prisma.parkingSlot.findMany({
      where,
      include: {
        allotments: {
          where: { status: 'ACTIVE' },
          select: {
            unitId: true,
            unit: { select: { fullCode: true } },
            vehicle: { select: { numberPlate: true, type: true } },
          },
        },
        sessions: {
          where: { status: 'ACTIVE' },
          select: { guestPlate: true, entryAt: true },
        },
      },
      orderBy: [{ floor: 'asc' }, { slotNumber: 'asc' }],
    });

    // Group by floor
    const map = {};
    for (const slot of slots) {
      const floorKey = slot.floor !== null ? `floor_${slot.floor}` : 'unassigned';
      if (!map[floorKey]) map[floorKey] = { floor: slot.floor, slots: [] };
      map[floorKey].slots.push(slot);
    }

    return sendSuccess(res, Object.values(map), 'Parking map retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// ─── ALLOTMENT MANAGEMENT ────────────────────────────────────────────────────

// GET /api/parking/allotments
exports.listAllotments = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { status, unitId, slotId, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (status) where.status = status;
    if (unitId) where.unitId = unitId;
    if (slotId) where.slotId = slotId;

    const [allotments, total] = await Promise.all([
      prisma.parkingAllotment.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          slot: { select: { slotNumber: true, type: true, zone: true, floor: true, hasEVCharger: true } },
          unit: { select: { fullCode: true, wing: true, unitNumber: true } },
          vehicle: { select: { numberPlate: true, type: true, brand: true, colour: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.parkingAllotment.count({ where }),
    ]);

    return sendSuccess(res, { allotments, total, page: parseInt(page), limit: parseInt(limit) }, 'Allotments retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/parking/allotments/unit/:unitId
exports.listAllotmentsByUnit = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { unitId } = req.params;

    const allotments = await prisma.parkingAllotment.findMany({
      where: { societyId, unitId },
      include: {
        slot: { select: { slotNumber: true, type: true, zone: true, floor: true, hasEVCharger: true, isHandicapped: true } },
        vehicle: { select: { numberPlate: true, type: true, brand: true, colour: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Fetch pending parking bills for this unit from maintenanceBill
    const pendingParkingBills = await prisma.maintenanceBill.findMany({
      where: { societyId, unitId, category: 'PARKING', status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] }, deletedAt: null },
      select: { id: true, amount: true, dueDate: true, description: true },
      orderBy: { dueDate: 'desc' },
    });

    // Attach pending charges to allotments for backward compatibility
    const result = allotments.map(a => ({
      ...a,
      pendingCharges: pendingParkingBills,
    }));

    return sendSuccess(res, result, 'Unit allotments retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/allotments
exports.createAllotment = async (req, res) => {
  try {
    const { societyId, id: allottedById } = req.user;
    const { slotId, unitId, vehicleId, startDate, endDate } = req.body;

    if (!slotId || !unitId) return sendError(res, 'slotId and unitId are required', 400);

    // Validate slot
    const slot = await prisma.parkingSlot.findUnique({ where: { id: slotId } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);
    if (!slot.isActive) return sendError(res, 'Slot is not active', 400);
    if (slot.status !== 'AVAILABLE') return sendError(res, `Slot is currently ${slot.status}`, 400);

    // Validate unit
    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) return sendError(res, 'Unit not found', 404);

    // Validate vehicle if provided
    if (vehicleId) {
      const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
      if (!vehicle || vehicle.societyId !== societyId) return sendError(res, 'Vehicle not found', 404);
      if (vehicle.unitId !== unitId) return sendError(res, 'Vehicle does not belong to this unit', 400);
      // Check vehicle not already in active allotment
      const existingVehicleAllotment = await prisma.parkingAllotment.findFirst({
        where: { vehicleId, status: 'ACTIVE' },
      });
      if (existingVehicleAllotment) return sendError(res, 'This vehicle already has an active parking allotment', 400);
    }

    const [allotment] = await prisma.$transaction([
      prisma.parkingAllotment.create({
        data: {
          societyId,
          slotId,
          unitId,
          vehicleId: vehicleId || null,
          allottedById,
          startDate: startDate ? new Date(startDate) : new Date(),
          endDate: endDate ? new Date(endDate) : null,
        },
        include: {
          slot: { select: { slotNumber: true, type: true, zone: true, floor: true } },
          unit: { select: { fullCode: true } },
          vehicle: { select: { numberPlate: true, type: true } },
        },
      }),
      prisma.parkingSlot.update({ where: { id: slotId }, data: { status: 'OCCUPIED' } }),
    ]);

    setImmediate(() =>
      parkingNotify.notifyAllotment(societyId, unitId, allotment.slot.slotNumber, allottedById).catch(() => {})
    );
    return sendSuccess(res, allotment, 'Parking slot allotted successfully', 201);
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/allotments/:id/vehicle
exports.updateAllotmentVehicle = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { vehicleId } = req.body;

    const allotment = await prisma.parkingAllotment.findUnique({ where: { id } });
    if (!allotment || allotment.societyId !== societyId) return sendError(res, 'Allotment not found', 404);
    if (allotment.status !== 'ACTIVE') return sendError(res, 'Only active allotments can be updated', 400);

    if (vehicleId) {
      const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
      if (!vehicle || vehicle.societyId !== societyId) return sendError(res, 'Vehicle not found', 404);
      if (vehicle.unitId !== allotment.unitId) return sendError(res, 'Vehicle does not belong to the allotted unit', 400);
    }

    const updated = await prisma.parkingAllotment.update({
      where: { id },
      data: { vehicleId: vehicleId || null },
      include: {
        slot: { select: { slotNumber: true, type: true } },
        vehicle: { select: { numberPlate: true, type: true } },
      },
    });

    return sendSuccess(res, updated, 'Allotment vehicle updated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/allotments/:id/release
exports.releaseAllotment = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { releaseReason } = req.body;

    const allotment = await prisma.parkingAllotment.findUnique({ where: { id } });
    if (!allotment || allotment.societyId !== societyId) return sendError(res, 'Allotment not found', 404);
    if (allotment.status !== 'ACTIVE') return sendError(res, 'Only active allotments can be released', 400);

    await prisma.$transaction([
      prisma.parkingAllotment.update({
        where: { id },
        data: { status: 'RELEASED', endDate: new Date(), releaseReason: releaseReason || null },
      }),
      prisma.parkingSlot.update({ where: { id: allotment.slotId }, data: { status: 'AVAILABLE' } }),
    ]);

    // fetch slot number for notification
    const releasedSlot = await prisma.parkingSlot.findUnique({ where: { id: allotment.slotId }, select: { slotNumber: true } });
    setImmediate(() =>
      parkingNotify.notifyRelease(allotment.societyId, allotment.unitId, releasedSlot?.slotNumber ?? '-', req.user.id).catch(() => {})
    );
    return sendSuccess(res, null, 'Parking slot released successfully');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/allotments/:id/transfer
exports.transferAllotment = async (req, res) => {
  try {
    const { societyId, id: allottedById } = req.user;
    const { id } = req.params;
    const { newUnitId, newVehicleId, transferReason } = req.body;

    if (!newUnitId) return sendError(res, 'newUnitId is required', 400);

    const allotment = await prisma.parkingAllotment.findUnique({ where: { id } });
    if (!allotment || allotment.societyId !== societyId) return sendError(res, 'Allotment not found', 404);
    if (allotment.status !== 'ACTIVE') return sendError(res, 'Only active allotments can be transferred', 400);

    const unit = await prisma.unit.findUnique({ where: { id: newUnitId } });
    if (!unit || unit.societyId !== societyId) return sendError(res, 'New unit not found', 404);

    if (newVehicleId) {
      const vehicle = await prisma.vehicle.findUnique({ where: { id: newVehicleId } });
      if (!vehicle || vehicle.unitId !== newUnitId) return sendError(res, 'Vehicle does not belong to new unit', 400);
    }

    const [, newAllotment] = await prisma.$transaction([
      // Mark old as transferred
      prisma.parkingAllotment.update({
        where: { id },
        data: { status: 'TRANSFERRED', endDate: new Date(), transferReason: transferReason || null },
      }),
      // Create new allotment for new unit
      prisma.parkingAllotment.create({
        data: {
          societyId,
          slotId: allotment.slotId,
          unitId: newUnitId,
          vehicleId: newVehicleId || null,
          allottedById,
          previousAllotmentId: id,
          transferReason: transferReason || null,
        },
        include: {
          slot: { select: { slotNumber: true, type: true } },
          unit: { select: { fullCode: true } },
          vehicle: { select: { numberPlate: true, type: true } },
        },
      }),
    ]);

    return sendSuccess(res, newAllotment, 'Parking slot transferred successfully');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/allotments/:id/suspend
exports.suspendAllotment = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const allotment = await prisma.parkingAllotment.findUnique({ where: { id } });
    if (!allotment || allotment.societyId !== societyId) return sendError(res, 'Allotment not found', 404);
    if (allotment.status !== 'ACTIVE') return sendError(res, 'Only active allotments can be suspended', 400);

    await prisma.$transaction([
      prisma.parkingAllotment.update({ where: { id }, data: { status: 'SUSPENDED' } }),
      prisma.parkingSlot.update({ where: { id: allotment.slotId }, data: { status: 'RESERVED' } }),
    ]);

    const suspendedSlot = await prisma.parkingSlot.findUnique({ where: { id: allotment.slotId }, select: { slotNumber: true } });
    setImmediate(() =>
      parkingNotify.notifySuspension(allotment.societyId, allotment.unitId, suspendedSlot?.slotNumber ?? '-', req.user.id).catch(() => {})
    );
    return sendSuccess(res, null, 'Allotment suspended');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/allotments/:id/reinstate
exports.reinstateAllotment = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const allotment = await prisma.parkingAllotment.findUnique({ where: { id } });
    if (!allotment || allotment.societyId !== societyId) return sendError(res, 'Allotment not found', 404);
    if (allotment.status !== 'SUSPENDED') return sendError(res, 'Only suspended allotments can be reinstated', 400);

    await prisma.$transaction([
      prisma.parkingAllotment.update({ where: { id }, data: { status: 'ACTIVE' } }),
      prisma.parkingSlot.update({ where: { id: allotment.slotId }, data: { status: 'OCCUPIED' } }),
    ]);

    const reinstatedSlot = await prisma.parkingSlot.findUnique({ where: { id: allotment.slotId }, select: { slotNumber: true } });
    setImmediate(() =>
      parkingNotify.notifyReinstatement(allotment.societyId, allotment.unitId, reinstatedSlot?.slotNumber ?? '-', req.user.id).catch(() => {})
    );
    return sendSuccess(res, null, 'Allotment reinstated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// ─── VISITOR / GUEST SESSIONS ─────────────────────────────────────────────────

// GET /api/parking/sessions
exports.listSessions = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { status, slotId, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (status) where.status = status;
    if (slotId) where.slotId = slotId;

    const [sessions, total] = await Promise.all([
      prisma.parkingSession.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          slot: { select: { slotNumber: true, type: true, zone: true, floor: true } },
          vehicle: { select: { numberPlate: true, type: true, brand: true } },
          linkedUnit: { select: { fullCode: true } },
        },
        orderBy: { entryAt: 'desc' },
      }),
      prisma.parkingSession.count({ where }),
    ]);

    return sendSuccess(res, { sessions, total, page: parseInt(page), limit: parseInt(limit) }, 'Sessions retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/parking/sessions/overstayed
exports.listOverstayedSessions = async (req, res) => {
  try {
    const { societyId } = req.user;

    const sessions = await prisma.parkingSession.findMany({
      where: {
        societyId,
        status: { in: ['ACTIVE', 'OVERSTAYED'] },
        expectedExitAt: { lt: new Date() },
      },
      include: {
        slot: { select: { slotNumber: true, type: true, zone: true } },
        vehicle: { select: { numberPlate: true, type: true } },
        linkedUnit: { select: { fullCode: true } },
      },
      orderBy: { expectedExitAt: 'asc' },
    });

    // Mark them as OVERSTAYED in background
    const ids = sessions.filter((s) => s.status === 'ACTIVE').map((s) => s.id);
    if (ids.length > 0) {
      prisma.parkingSession.updateMany({ where: { id: { in: ids } }, data: { status: 'OVERSTAYED' } }).catch(() => {});
    }

    return sendSuccess(res, sessions, 'Overstayed sessions retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/sessions  — log vehicle entry
exports.logEntry = async (req, res) => {
  try {
    const { societyId, id: entryById } = req.user;
    const { slotId, vehicleId, guestPlate, guestName, guestPhone, linkedUnitId, visitorId, deliveryId, expectedExitAt } = req.body;

    if (!slotId) return sendError(res, 'slotId is required', 400);
    if (!vehicleId && !guestPlate) return sendError(res, 'Either vehicleId or guestPlate is required', 400);

    const slot = await prisma.parkingSlot.findUnique({ where: { id: slotId } });
    if (!slot || slot.societyId !== societyId) return sendError(res, 'Slot not found', 404);
    if (!slot.isActive) return sendError(res, 'Slot is not active', 400);

    // Check no active session already on this slot
    const existingSession = await prisma.parkingSession.findFirst({ where: { slotId, status: 'ACTIVE' } });
    if (existingSession) return sendError(res, 'Slot already has an active session', 400);

    if (vehicleId) {
      const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
      if (!vehicle || vehicle.societyId !== societyId) return sendError(res, 'Vehicle not found', 404);
    }

    if (linkedUnitId) {
      const unit = await prisma.unit.findUnique({ where: { id: linkedUnitId } });
      if (!unit || unit.societyId !== societyId) return sendError(res, 'Unit not found', 404);
    }

    const [session] = await prisma.$transaction([
      prisma.parkingSession.create({
        data: {
          societyId,
          slotId,
          vehicleId: vehicleId || null,
          guestPlate: guestPlate || null,
          guestName: guestName || null,
          guestPhone: guestPhone || null,
          linkedUnitId: linkedUnitId || null,
          visitorId: visitorId || null,
          deliveryId: deliveryId || null,
          entryById,
          expectedExitAt: expectedExitAt ? new Date(expectedExitAt) : null,
        },
        include: {
          slot: { select: { slotNumber: true, type: true, zone: true } },
          vehicle: { select: { numberPlate: true, type: true } },
          linkedUnit: { select: { fullCode: true } },
        },
      }),
      // Only mark slot OCCUPIED if it was AVAILABLE (VISITOR slots stay AVAILABLE for allotment purposes)
      ...(slot.type !== 'VISITOR'
        ? [prisma.parkingSlot.update({ where: { id: slotId }, data: { status: 'OCCUPIED' } })]
        : []),
    ]);

    return sendSuccess(res, session, 'Vehicle entry logged', 201);
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/parking/sessions/:id/exit  — log vehicle exit
exports.logExit = async (req, res) => {
  try {
    const { societyId, id: exitById } = req.user;
    const { id } = req.params;
    const { notes } = req.body;

    const session = await prisma.parkingSession.findUnique({ where: { id }, include: { slot: true } });
    if (!session || session.societyId !== societyId) return sendError(res, 'Session not found', 404);
    if (session.status === 'COMPLETED') return sendError(res, 'Session already completed', 400);

    await prisma.$transaction([
      prisma.parkingSession.update({
        where: { id },
        data: { exitAt: new Date(), exitById, status: 'COMPLETED', notes: notes || session.notes },
      }),
      // Restore slot to AVAILABLE only if it was a visitor/guest slot (not a resident allotted slot)
      ...(session.slot.type === 'VISITOR' || !session.vehicleId
        ? [] // visitor slots manage their own status
        : [prisma.parkingSlot.update({ where: { id: session.slotId }, data: { status: 'AVAILABLE' } })]),
    ]);

    return sendSuccess(res, null, 'Vehicle exit logged');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// ─── PARKING CHARGES (via MaintenanceBill, category=PARKING) ─────────────────

// GET /api/parking/charges
exports.listCharges = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { isPaid, unitId, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId, category: 'PARKING', deletedAt: null };
    if (isPaid !== undefined) {
      if (isPaid === 'true') {
        where.status = 'PAID';
      } else {
        where.status = { in: ['PENDING', 'PARTIAL', 'OVERDUE'] };
      }
    }
    if (unitId) where.unitId = unitId;

    const [charges, total] = await Promise.all([
      prisma.maintenanceBill.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          unit: { select: { fullCode: true, wing: true } },
        },
        orderBy: { dueDate: 'desc' },
      }),
      prisma.maintenanceBill.count({ where }),
    ]);

    // Map to a shape the frontend expects
    const mapped = charges.map(c => ({
      id: c.id,
      amount: c.amount,
      dueDate: c.dueDate,
      isPaid: c.status === 'PAID',
      paidAt: c.paidAt,
      paymentMethod: c.paymentMethod,
      description: c.description || c.title,
      frequency: 'MONTHLY',
      status: c.status,
      unit: c.unit,
      slot: null, // not linked directly anymore
      createdAt: c.createdAt,
    }));

    return sendSuccess(res, { charges: mapped, total, page: parseInt(page), limit: parseInt(limit) }, 'Parking charges retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/charges  — create a parking bill manually
exports.createCharge = async (req, res) => {
  try {
    const { societyId, id: createdById } = req.user;
    const { unitId, amount, dueDate, description } = req.body;

    if (!unitId || !amount || !dueDate) {
      return sendError(res, 'unitId, amount, and dueDate are required', 400);
    }

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) return sendError(res, 'Unit not found', 404);

    const bill = await prisma.maintenanceBill.create({
      data: {
        societyId,
        unitId,
        createdById,
        billingMonth: new Date(),
        amount: parseFloat(amount),
        totalDue: parseFloat(amount),
        status: 'PENDING',
        dueDate: new Date(dueDate),
        title: 'Parking Charge',
        description: description || 'Parking charge',
        category: 'PARKING',
      },
    });

    setImmediate(() => {
      notificationsService.sendNotification(createdById, societyId, {
        targetType: 'unit',
        targetId: unitId,
        title: '🅿️ Parking Charge',
        body: `A parking charge of ₹${parseFloat(amount).toFixed(0)} has been added for unit ${unit.fullCode}.`,
        type: 'BILL',
        route: '/bills',
        excludeUserId: createdById,
      });
    });

    return sendSuccess(res, bill, 'Parking charge created', 201);
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/parking/charges/generate  — bulk generate monthly parking bills for all active allotments
exports.generateMonthlyCharges = async (req, res) => {
  try {
    const { societyId, id: createdById } = req.user;
    const { amount, dueDate, description, month } = req.body;

    if (!amount || !dueDate) return sendError(res, 'amount and dueDate are required', 400);

    const billingMonthInput = month ? new Date(month) : new Date();
    const result = await billsService.bulkGenerateParkingBills(
      societyId,
      billingMonthInput.toISOString(),
      parseFloat(amount),
      new Date(dueDate),
      createdById,
      description ? { description } : {},
    );

    return sendSuccess(
      res,
      { generated: result.count, skipped: result.skippedExistingUnits },
      'Monthly parking charges generated',
    );
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
};

// PATCH /api/parking/charges/:id/pay
exports.payCharge = async (req, res) => {
  try {
    const { societyId, id: actorId } = req.user;
    const { id } = req.params;
    const { paymentMethod } = req.body;

    const bill = await prisma.maintenanceBill.findUnique({ where: { id } });
    if (!bill || bill.societyId !== societyId || bill.category !== 'PARKING') {
      return sendError(res, 'Parking charge not found', 404);
    }
    if (bill.status === 'PAID') return sendError(res, 'Charge already paid', 400);

    const updated = await prisma.$transaction(async (tx) => {
      const updatedBill = await tx.maintenanceBill.update({
        where: { id },
        data: {
          status: 'PAID',
          paidAmount: bill.totalDue,
          paidAt: new Date(),
          paidById: actorId,
          paymentMethod: paymentMethod || null,
        },
      });

      await tx.billAuditLog.create({
        data: {
          billId: id,
          societyId,
          unitId: bill.unitId,
          actorId,
          action: 'PAYMENT_RECORDED',
          note: 'Parking charge marked as paid',
          metadata: {
            amountPaid: Number(bill.totalDue),
            paymentMethod: paymentMethod || null,
          },
        },
      });

      return updatedBill;
    });

    return sendSuccess(res, { id: updated.id, isPaid: true, paidAt: updated.paidAt }, 'Parking charge marked as paid');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// ─── DASHBOARD ───────────────────────────────────────────────────────────────

// GET /api/parking/dashboard
exports.getDashboard = async (req, res) => {
  try {
    const { societyId } = req.user;

    const [
      totalSlots,
      availableSlots,
      occupiedSlots,
      maintenanceSlots,
      totalAllotments,
      activeAllotments,
      activeSessions,
      pendingCharges,
      pendingChargesAmount,
      evSlots,
      handicappedSlots,
      typeBreakdown,
    ] = await Promise.all([
      prisma.parkingSlot.count({ where: { societyId, isActive: true } }),
      prisma.parkingSlot.count({ where: { societyId, isActive: true, status: 'AVAILABLE' } }),
      prisma.parkingSlot.count({ where: { societyId, isActive: true, status: 'OCCUPIED' } }),
      prisma.parkingSlot.count({ where: { societyId, isActive: true, status: 'UNDER_MAINTENANCE' } }),
      prisma.parkingAllotment.count({ where: { societyId } }),
      prisma.parkingAllotment.count({ where: { societyId, status: 'ACTIVE' } }),
      prisma.parkingSession.count({ where: { societyId, status: 'ACTIVE' } }),
      prisma.maintenanceBill.count({ where: { societyId, category: 'PARKING', status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] }, deletedAt: null } }),
      prisma.maintenanceBill.aggregate({ where: { societyId, category: 'PARKING', status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] }, deletedAt: null }, _sum: { amount: true } }),
      prisma.parkingSlot.count({ where: { societyId, isActive: true, hasEVCharger: true } }),
      prisma.parkingSlot.count({ where: { societyId, isActive: true, isHandicapped: true } }),
      prisma.parkingSlot.groupBy({ by: ['type'], where: { societyId, isActive: true }, _count: { id: true } }),
    ]);

    const occupancyPercent = totalSlots > 0 ? Math.round((occupiedSlots / totalSlots) * 100) : 0;

    return sendSuccess(
      res,
      {
        slots: {
          total: totalSlots,
          available: availableSlots,
          occupied: occupiedSlots,
          underMaintenance: maintenanceSlots,
          occupancyPercent,
          evSlots,
          handicappedSlots,
          byType: typeBreakdown.map((t) => ({ type: t.type, count: t._count.id })),
        },
        allotments: { total: totalAllotments, active: activeAllotments },
        sessions: { active: activeSessions },
        charges: {
          pendingCount: pendingCharges,
          pendingAmount: pendingChargesAmount._sum.amount || 0,
        },
      },
      'Parking dashboard retrieved'
    );
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
