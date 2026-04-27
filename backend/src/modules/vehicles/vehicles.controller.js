const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const { userHasUnit } = require('../../utils/unitResident');

function buildVehicleAuditMetadata(before, after) {
  const changed = {};
  for (const key of Object.keys(after || {})) {
    if (before?.[key] !== after?.[key]) {
      changed[key] = { from: before?.[key] ?? null, to: after?.[key] ?? null };
    }
  }
  return Object.keys(changed).length ? { changed } : null;
}

// GET /api/vehicles
exports.getAllVehicles = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { unitId, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId, isActive: true };
    // Listing is society-wide by default; optionally filter by unitId for staff/admin UIs.
    if (unitId) {
      where.unitId = unitId;
    }

    const [vehicles, total] = await Promise.all([
      prisma.vehicle.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          unit: { select: { fullCode: true } },
          registeredBy: { select: { id: true, name: true, role: true } },
          updatedBy: { select: { id: true, name: true, role: true } },
          removedBy: { select: { id: true, name: true, role: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.vehicle.count({ where }),
    ]);

    return sendSuccess(res, { vehicles, total, page: parseInt(page), limit: parseInt(limit) }, 'Vehicles retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/vehicles
exports.createVehicle = async (req, res) => {
  try {
    const { societyId, id: registeredById, role, unitId: activeUnitId } = req.user;
    const { unitId, type, numberPlate, brand, model, colour } = req.body;

    if (!type || !numberPlate) {
      return sendError(res, 'unitId, type, and numberPlate are required', 400);
    }

    const roleUpper = String(role || '').toUpperCase();
    const finalUnitId =
      (roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') && activeUnitId
        ? activeUnitId
        : unitId;

    if (!finalUnitId) {
      return sendError(res, 'unitId, type, and numberPlate are required', 400);
    }

    const unit = await prisma.unit.findUnique({ where: { id: finalUnitId } });
    if (!unit || unit.societyId !== societyId) {
      return sendError(res, 'Unit not found in your society', 404);
    }

    // Residents/Members can only create vehicles for their own unit.
    if (roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') {
      const allowed = await userHasUnit(registeredById, societyId, finalUnitId);
      if (!allowed) return sendError(res, 'You can only add vehicles for your own unit', 403);
    }

    const vehicle = await prisma.$transaction(async (tx) => {
      const created = await tx.vehicle.create({
        data: { societyId, unitId: finalUnitId, registeredById, type, numberPlate, brand, model, colour },
      });

      await tx.vehicleAuditLog.create({
        data: {
          vehicleId: created.id,
          societyId,
          unitId: finalUnitId,
          actorId: registeredById,
          action: 'CREATED',
          metadata: { numberPlate, type, brand, model, colour },
        },
      });

      return tx.vehicle.findUnique({
        where: { id: created.id },
        include: {
          unit: { select: { fullCode: true } },
          registeredBy: { select: { id: true, name: true, role: true } },
          updatedBy: { select: { id: true, name: true, role: true } },
          removedBy: { select: { id: true, name: true, role: true } },
        },
      });
    });

    return sendSuccess(res, vehicle, 'Vehicle registered', 201);
  } catch (error) {
    if (error.code === 'P2002') return sendError(res, 'This number plate is already registered in your society', 409);
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/vehicles/:id
exports.updateVehicle = async (req, res) => {
  try {
    const { societyId, role, unitId: activeUnitId, id: userId } = req.user;
    const { id } = req.params;

    const vehicle = await prisma.vehicle.findUnique({ where: { id } });
    if (!vehicle || vehicle.societyId !== societyId) {
      return sendError(res, 'Vehicle not found', 404);
    }

    // Residents/Members can only edit vehicles for their own unit.
    const roleUpper = String(role || '').toUpperCase();
    if (roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') {
      if (!activeUnitId || vehicle.unitId !== activeUnitId) {
        return sendError(res, 'You can only edit vehicles for your own unit', 403);
      }
      const allowed = await userHasUnit(userId, societyId, activeUnitId);
      if (!allowed) return sendError(res, 'You can only edit vehicles for your own unit', 403);
    }

    const { numberPlate, brand, model, colour, isActive } = req.body;
    const updateData = {};
    if (numberPlate !== undefined) updateData.numberPlate = numberPlate;
    if (brand !== undefined) updateData.brand = brand;
    if (model !== undefined) updateData.model = model;
    if (colour !== undefined) updateData.colour = colour;
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);

    const updated = await prisma.$transaction(async (tx) => {
      const before = await tx.vehicle.findUnique({ where: { id } });
      const next = await tx.vehicle.update({
        where: { id },
        data: { ...updateData, updatedById: userId },
      });

      const metadata = buildVehicleAuditMetadata(before, next);
      await tx.vehicleAuditLog.create({
        data: {
          vehicleId: id,
          societyId,
          unitId: vehicle.unitId,
          actorId: userId,
          action: 'UPDATED',
          metadata,
        },
      });

      return tx.vehicle.findUnique({
        where: { id },
        include: {
          unit: { select: { fullCode: true } },
          registeredBy: { select: { id: true, name: true, role: true } },
          updatedBy: { select: { id: true, name: true, role: true } },
          removedBy: { select: { id: true, name: true, role: true } },
        },
      });
    });
    return sendSuccess(res, updated, 'Vehicle updated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/vehicles/mine
exports.getMyVehicles = async (req, res) => {
  try {
    const { societyId, id: userId, unitId: activeUnitId } = req.user;
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

    const vehicles = await prisma.vehicle.findMany({
      where: { societyId, unitId: { in: unitIds }, isActive: true },
      include: {
        unit: { select: { fullCode: true } },
        registeredBy: { select: { id: true, name: true, role: true } },
        updatedBy: { select: { id: true, name: true, role: true } },
        removedBy: { select: { id: true, name: true, role: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, vehicles, 'Your vehicles retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/vehicles/lookup/:plate
exports.lookupByPlate = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { plate } = req.params;
    const vehicle = await prisma.vehicle.findFirst({
      where: { societyId, numberPlate: { equals: plate, mode: 'insensitive' }, isActive: true },
      include: {
        unit: { select: { fullCode: true, wing: true, unitNumber: true } },
        registeredBy: { select: { id: true, name: true, role: true } },
        updatedBy: { select: { id: true, name: true, role: true } },
        removedBy: { select: { id: true, name: true, role: true } },
      },
    });
    if (!vehicle) return sendError(res, 'Vehicle not found', 404);
    return sendSuccess(res, vehicle, 'Vehicle found');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// DELETE /api/vehicles/:id
exports.deleteVehicle = async (req, res) => {
  try {
    const { societyId, role, unitId: activeUnitId, id: userId } = req.user;
    const { id } = req.params;

    const vehicle = await prisma.vehicle.findUnique({ where: { id } });
    if (!vehicle || vehicle.societyId !== societyId) {
      return sendError(res, 'Vehicle not found', 404);
    }

    // Residents/Members can only remove vehicles for their own unit.
    const roleUpper = String(role || '').toUpperCase();
    if (roleUpper === 'RESIDENT' || roleUpper === 'MEMBER') {
      if (!activeUnitId || vehicle.unitId !== activeUnitId) {
        return sendError(res, 'You can only remove vehicles for your own unit', 403);
      }
      const allowed = await userHasUnit(userId, societyId, activeUnitId);
      if (!allowed) return sendError(res, 'You can only remove vehicles for your own unit', 403);
    }

    await prisma.$transaction(async (tx) => {
      await tx.vehicle.update({
        where: { id },
        data: { isActive: false, removedAt: new Date(), removedById: userId },
      });
      await tx.vehicleAuditLog.create({
        data: {
          vehicleId: id,
          societyId,
          unitId: vehicle.unitId,
          actorId: userId,
          action: 'DELETED',
        },
      });
    });
    return sendSuccess(res, null, 'Vehicle removed');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/vehicles/:id/audit-logs
exports.getVehicleAuditLogs = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id: vehicleId } = req.params;

    const vehicle = await prisma.vehicle.findUnique({
      where: { id: vehicleId },
      select: { id: true, societyId: true },
    });
    if (!vehicle || vehicle.societyId !== societyId) return sendError(res, 'Vehicle not found', 404);

    const logs = await prisma.vehicleAuditLog.findMany({
      where: { vehicleId, societyId },
      include: {
        actor: { select: { id: true, name: true, role: true } },
        vehicle: {
          select: {
            id: true,
            numberPlate: true,
            unit: { select: { id: true, fullCode: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return sendSuccess(res, logs, 'Vehicle audit logs retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/vehicles/audit-logs
exports.getAllVehicleAuditLogs = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { page = 1, limit = 20, unitId, action, vehicleId } = req.query;
    const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);

    const where = { societyId };
    if (unitId) where.unitId = unitId;
    if (vehicleId) where.vehicleId = vehicleId;
    if (action) where.action = String(action).toUpperCase();

    const [logs, total] = await Promise.all([
      prisma.vehicleAuditLog.findMany({
        where,
        include: {
          actor: { select: { id: true, name: true, role: true } },
          vehicle: {
            select: {
              id: true,
              numberPlate: true,
              isActive: true,
              removedAt: true,
              unit: { select: { id: true, fullCode: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: parseInt(limit, 10),
      }),
      prisma.vehicleAuditLog.count({ where }),
    ]);

    return sendSuccess(
      res,
      { logs, total, page: parseInt(page, 10), limit: parseInt(limit, 10) },
      'Vehicle audit logs retrieved'
    );
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
