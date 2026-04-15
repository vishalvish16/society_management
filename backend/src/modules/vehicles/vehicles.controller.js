const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// GET /api/vehicles
exports.getAllVehicles = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { unitId, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId, isActive: true };
    if (unitId) where.unitId = unitId;

    const [vehicles, total] = await Promise.all([
      prisma.vehicle.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: { unit: { select: { fullCode: true } } },
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
    const { societyId, id: registeredById } = req.user;
    const { unitId, type, numberPlate, brand, model, colour } = req.body;

    if (!unitId || !type || !numberPlate) {
      return sendError(res, 'unitId, type, and numberPlate are required', 400);
    }

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) {
      return sendError(res, 'Unit not found in your society', 404);
    }

    const vehicle = await prisma.vehicle.create({
      data: { societyId, unitId, registeredById, type, numberPlate, brand, model, colour },
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
    const { societyId } = req.user;
    const { id } = req.params;

    const vehicle = await prisma.vehicle.findUnique({ where: { id } });
    if (!vehicle || vehicle.societyId !== societyId) {
      return sendError(res, 'Vehicle not found', 404);
    }

    const { numberPlate, brand, model, colour, isActive } = req.body;
    const updateData = {};
    if (numberPlate !== undefined) updateData.numberPlate = numberPlate;
    if (brand !== undefined) updateData.brand = brand;
    if (model !== undefined) updateData.model = model;
    if (colour !== undefined) updateData.colour = colour;
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);

    const updated = await prisma.vehicle.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Vehicle updated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/vehicles/mine
exports.getMyVehicles = async (req, res) => {
  try {
    const { societyId, id: userId } = req.user;
    const unitResidents = await prisma.unitResident.findMany({ where: { userId }, select: { unitId: true } });
    const unitIds = unitResidents.map((ur) => ur.unitId);

    const vehicles = await prisma.vehicle.findMany({
      where: { societyId, unitId: { in: unitIds }, isActive: true },
      include: { unit: { select: { fullCode: true } } },
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
      include: { unit: { select: { fullCode: true, wing: true, unitNumber: true } } },
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
    const { societyId } = req.user;
    const { id } = req.params;

    const vehicle = await prisma.vehicle.findUnique({ where: { id } });
    if (!vehicle || vehicle.societyId !== societyId) {
      return sendError(res, 'Vehicle not found', 404);
    }

    await prisma.vehicle.update({ where: { id }, data: { isActive: false } });
    return sendSuccess(res, null, 'Vehicle removed');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
