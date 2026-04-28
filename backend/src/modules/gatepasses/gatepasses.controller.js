const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const crypto = require('crypto');
const notificationsService = require('../notifications/notifications.service');

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
    // Residents/Members must only see their active unit's gate passes.
    if ((req.user.role === 'RESIDENT' || req.user.role === 'MEMBER') && req.user.unitId) {
      where.unitId = req.user.unitId;
    } else if (unitId) {
      where.unitId = unitId;
    }
    if (status) where.status = status.toUpperCase();

    const [passes, total] = await Promise.all([
      prisma.gatePass.findMany({
        where,
        select: {
          id: true, passCode: true, itemDescription: true, reason: true,
          validFrom: true,
          validTo: true,
          status: true,
          scannedAt: true,
          decision: true,
          decisionNote: true,
          createdAt: true,
          unit: { select: { id: true, fullCode: true } },
          createdBy: { select: { id: true, name: true } },
          scannedBy: { select: { id: true, name: true } },
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
        decision: true,
        scannedAt: true,
        validFrom: true,
        validTo: true,
        itemDescription: true,
        reason: true,
        unit: { select: { id: true, fullCode: true } },
        createdBy: { select: { id: true, name: true } },
        scannedBy: { select: { id: true, name: true } },
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
    const { passCode, decision, note } = req.body;
    if (!passCode) return sendError(res, 'passCode is required', 400);
    const normalizedDecision = (decision || '').toString().trim().toUpperCase();
    if (!['APPROVED', 'REJECTED'].includes(normalizedDecision)) {
      return sendError(res, 'decision must be APPROVED or REJECTED', 400);
    }

    const normalizedCode = passCode.toString().trim().toUpperCase();
    const gatePass = await prisma.gatePass.findUnique({
      where: { passCode: normalizedCode },
      select: {
        id: true,
        societyId: true,
        unit: { select: { id: true, fullCode: true } },
        createdById: true,
        createdBy: { select: { id: true, name: true } },
        status: true,
        decision: true,
        scannedAt: true,
        scannedBy: { select: { id: true, name: true } },
        validFrom: true,
        validTo: true,
        itemDescription: true,
      },
    });

    if (!gatePass) return sendError(res, 'Invalid pass code', 404);
    if (gatePass.societyId !== req.user.societyId) return sendError(res, 'Pass not for this society', 403);

    const now = new Date();
    const withinWindow = now >= new Date(gatePass.validFrom) && now <= new Date(gatePass.validTo);

    // Always log scan attempts for traceability (watchman + creator visibility).
    const logAttempt = async (result, extra = {}) => {
      await prisma.gatePassLog.create({
        data: {
          gatePassId: gatePass.id,
          scannedById: req.user.id,
          result,
          decision: extra.decision || null,
          note: extra.note || null,
          scannedAt: now,
        },
      });
    };

    if (gatePass.status !== 'ACTIVE') {
      await logAttempt('USED', { decision: gatePass.decision || null });
      return sendError(
        res,
        `Gate pass already scanned (${gatePass.status})`,
        400,
        {
          result: 'used',
          status: gatePass.status,
          scannedAt: gatePass.scannedAt,
          scannedBy: gatePass.scannedBy?.name || null,
          decision: gatePass.decision || null,
        },
      );
    }

    if (!withinWindow) {
      if (now < new Date(gatePass.validFrom)) {
        await logAttempt('NOT_YET_VALID');
        return sendError(res, 'Gate pass is not yet valid', 400, { result: 'not_yet_valid' });
      }
      await logAttempt('EXPIRED');
      return sendError(res, 'Gate pass has expired', 400, { result: 'expired' });
    }

    const updated = await prisma.$transaction(async (tx) => {
      const u = await tx.gatePass.update({
        where: { id: gatePass.id },
        data: {
          status: 'USED',
          scannedById: req.user.id,
          scannedAt: now,
          decision: normalizedDecision,
          decisionNote: note ? note.toString() : null,
        },
        select: {
          id: true,
          passCode: true,
          status: true,
          scannedAt: true,
          decision: true,
          decisionNote: true,
          itemDescription: true,
          unit: { select: { id: true, fullCode: true } },
          createdBy: { select: { id: true, name: true } },
          scannedBy: { select: { id: true, name: true } },
        },
      });

      await tx.gatePassLog.create({
        data: {
          gatePassId: gatePass.id,
          scannedById: req.user.id,
          result: 'VALID',
          decision: normalizedDecision,
          note: note ? note.toString() : null,
          scannedAt: now,
        },
      });

      return u;
    });

    // Notify creator (FCM + in-app) that pass was approved/rejected.
    try {
      const title =
        normalizedDecision === 'APPROVED' ? 'Gate Pass Approved' : 'Gate Pass Rejected';
      const body = `${updated.itemDescription} (${updated.passCode}) · Unit ${updated.unit.fullCode}`;
      await notificationsService.sendNotification(req.user.id, req.user.societyId, {
        targetType: 'user',
        targetId: updated.createdBy.id,
        title,
        body,
        type: 'GATE_PASS',
        pushData: {
          gatePassId: updated.id,
          passCode: updated.passCode,
          decision: updated.decision,
        },
      });
    } catch (_) {
      // Non-blocking: pass scan should succeed even if push fails.
    }

    return sendSuccess(res, updated, `Gate pass ${normalizedDecision.toLowerCase()} successfully`);
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
          validFrom: true,
          validTo: true,
          status: true,
          scannedAt: true,
          decision: true,
          decisionNote: true,
          createdAt: true,
          unit: { select: { id: true, fullCode: true } },
          scannedBy: { select: { id: true, name: true } },
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

/**
 * GET /api/gatepasses/:id/logs — scan/audit history for a gate pass.
 *
 * Access:
 * - WATCHMAN/committee roles: any gate pass in their society
 * - RESIDENT/MEMBER: only gate passes created by them
 */
async function listGatePassLogs(req, res, next) {
  try {
    const { id } = req.params;
    const societyId = req.user.societyId;

    const looksLikePassCode = (v) =>
      typeof v === 'string' && /^[0-9A-Fa-f]{8}$/.test(v.trim());

    const where = looksLikePassCode(id)
      ? { passCode: id.trim().toUpperCase() }
      : { id };

    const gatePass = await prisma.gatePass.findUnique({
      where,
      select: {
        id: true,
        societyId: true,
        createdById: true,
        passCode: true,
        itemDescription: true,
        status: true,
        decision: true,
        scannedAt: true,
        unit: { select: { id: true, fullCode: true } },
      },
    });

    if (!gatePass) return sendError(res, 'Gate pass not found', 404);
    if (gatePass.societyId !== societyId) return sendError(res, 'Pass not for this society', 403);

    const isStaff = ['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY'].includes(req.user.role);
    if (!isStaff && gatePass.createdById !== req.user.id) {
      return sendError(res, 'Not allowed to view logs for this gate pass', 403);
    }

    const logs = await prisma.gatePassLog.findMany({
      where: { gatePassId: gatePass.id },
      select: {
        id: true,
        result: true,
        decision: true,
        note: true,
        scannedAt: true,
        scannedBy: { select: { id: true, name: true } },
      },
      orderBy: { scannedAt: 'desc' },
    });

    return sendSuccess(
      res,
      { gatePass, logs },
      'Gate pass logs retrieved',
    );
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
  listGatePassLogs,
};
