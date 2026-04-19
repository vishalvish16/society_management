const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const crypto = require('crypto');

function generatePassCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase(); // 8-char hex
}

async function createGatePass(req, res, next) {
  try {
    const { unitId, itemDescription, reason, validFrom, validTo } = req.body;
    const societyId   = req.user.societyId;
    const createdById = req.user.id;

    if (!unitId || !itemDescription || !validFrom || !validTo) {
      return sendError(res, 'unitId, itemDescription, validFrom, validTo are required', 400);
    }

    const passCode = generatePassCode();

    const gatePass = await prisma.gatePass.create({
      data: {
        societyId,
        unitId,
        createdById,
        passCode,
        itemDescription,
        reason:    reason    || null,
        validFrom: new Date(validFrom),
        validTo:   new Date(validTo),
        status:    'ACTIVE',
      },
      select: {
        id: true, passCode: true, itemDescription: true, reason: true,
        validFrom: true, validTo: true, status: true, createdAt: true,
        unit: { select: { id: true, fullCode: true } },
      },
    });

    return sendSuccess(res, gatePass, 'Gate pass created', 201);
  } catch (err) {
    if (err.code === 'P2002') return sendError(res, 'Pass code collision — please retry', 409);
    next(err);
  }
}

async function listGatePasses(req, res, next) {
  try {
    const societyId = req.user.societyId;
    const { unitId, status, page = 1, limit = 20 } = req.query;
    const where = { societyId };
    if (unitId) where.unitId = unitId;
    if (status) where.status = status.toUpperCase();

    const [passes, total] = await Promise.all([
      prisma.gatePass.findMany({
        where,
        select: {
          id: true, passCode: true, itemDescription: true, reason: true,
          validFrom: true, validTo: true, status: true, scannedAt: true, createdAt: true,
          unit: { select: { id: true, fullCode: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (parseInt(page) - 1) * parseInt(limit),
        take: parseInt(limit),
      }),
      prisma.gatePass.count({ where }),
    ]);

    return sendSuccess(res, { passes, total, page: parseInt(page), limit: parseInt(limit) }, 'Gate passes retrieved');
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/gatepasses/verify/:passCode — read-only check for QR scanner (does not mark USED).
 */
async function verifyGatePass(req, res, next) {
  try {
    const raw = (req.params.passCode || '').trim().toUpperCase();
    if (!raw) return sendError(res, 'passCode is required', 400);

    const gatePass = await prisma.gatePass.findUnique({
      where: { passCode: raw },
      select: {
        id: true,
        societyId: true,
        status: true,
        validFrom: true,
        validTo: true,
        itemDescription: true,
        reason: true,
        unit: { select: { id: true, fullCode: true } },
      },
    });

    if (!gatePass) return sendError(res, 'Invalid pass code', 404);
    if (gatePass.societyId !== req.user.societyId) {
      return sendError(res, 'Pass not for this society', 403);
    }

    return sendSuccess(res, { pass: gatePass }, 'Gate pass verified');
  } catch (err) {
    next(err);
  }
}

async function scanGatePass(req, res, next) {
  try {
    const { passCode } = req.body;
    if (!passCode) return sendError(res, 'passCode is required', 400);

    const gatePass = await prisma.gatePass.findUnique({
      where: { passCode },
      select: { id: true, societyId: true, status: true, validFrom: true, validTo: true, itemDescription: true },
    });

    if (!gatePass) return sendError(res, 'Invalid pass code', 404);
    if (gatePass.societyId !== req.user.societyId) return sendError(res, 'Pass not for this society', 403);

    const now = new Date();
    if (gatePass.status !== 'ACTIVE') return sendError(res, `Gate pass is ${gatePass.status}`, 400);
    if (now < new Date(gatePass.validFrom)) return sendError(res, 'Gate pass is not yet valid', 400);
    if (now > new Date(gatePass.validTo))   return sendError(res, 'Gate pass has expired', 400);

    const updated = await prisma.gatePass.update({
      where: { id: gatePass.id },
      data: { status: 'USED', scannedById: req.user.id, scannedAt: now },
      select: { id: true, passCode: true, status: true, scannedAt: true, itemDescription: true },
    });

    return sendSuccess(res, updated, 'Gate pass scanned successfully');
  } catch (err) {
    next(err);
  }
}

async function cancelGatePass(req, res, next) {
  try {
    const { id } = req.params;
    const societyId = req.user.societyId;

    const gatePass = await prisma.gatePass.update({
      where: { id, societyId },
      data: { status: 'CANCELLED' },
      select: { id: true, passCode: true, status: true },
    });

    return sendSuccess(res, gatePass, 'Gate pass cancelled');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Gate pass not found', 404);
    next(err);
  }
}

async function listMyGatePasses(req, res, next) {
  try {
    const { societyId, id: userId } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const where = { societyId, createdById: userId };
    if (status) where.status = status.toUpperCase();

    const [passes, total] = await Promise.all([
      prisma.gatePass.findMany({
        where,
        select: {
          id: true, passCode: true, itemDescription: true, reason: true,
          validFrom: true, validTo: true, status: true, scannedAt: true, createdAt: true,
          unit: { select: { id: true, fullCode: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (parseInt(page) - 1) * parseInt(limit),
        take: parseInt(limit),
      }),
      prisma.gatePass.count({ where }),
    ]);

    return sendSuccess(res, { passes, total, page: parseInt(page), limit: parseInt(limit) }, 'Your gate passes retrieved');
  } catch (err) {
    next(err);
  }
}

module.exports = {
  createGatePass,
  listGatePasses,
  listMyGatePasses,
  verifyGatePass,
  scanGatePass,
  cancelGatePass,
};
