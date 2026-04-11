const crypto = require('crypto');

const prisma = require('../../config/db');

/**
 * List visitors for a society or specific unit.
 */
async function listVisitors(societyId, filters = {}) {
  const { unitId, status, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = {
    societyId,
  };

  if (unitId) where.unitId = unitId;
  if (status) where.status = status;

  const [visitors, total] = await Promise.all([
    prisma.visitor.findMany({
      where,
      include: {
        unit: { select: { fullCode: true } },
        inviter: { select: { name: true } },
        log: { include: { scanner: { select: { name: true } } } }
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.visitor.count({ where })
  ]);

  return { visitors, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

/**
 * Create a new visitor invitation.
 * Generates a unique QR token valid for 24 hours by default.
 */
async function inviteVisitor(userId, societyId, data) {
  const { unitId, visitorName, visitorPhone, expectedArrival, expiryHours = 24 } = data;

  // Verify unit belongs to society and user has access (TODO: deeper check for resident-unit link)
  const unit = await prisma.unit.findUnique({ where: { id: unitId } });
  if (!unit || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found in your society'), { status: 404 });
  }

  const qrToken = crypto.randomUUID();

  const qrExpiresAt = new Date();
  qrExpiresAt.setHours(qrExpiresAt.getHours() + expiryHours);

  return prisma.visitor.create({
    data: {
      societyId,
      unitId,
      invitedBy: userId,
      visitorName,
      visitorPhone,
      expectedArrival: expectedArrival ? new Date(expectedArrival) : null,
      qrToken,
      qrExpiresAt,
      status: 'PENDING'
    }
  });
}

/**
 * Validate a QR token scanned by a watchman.
 */
async function validateToken(qrToken, scannerId, societyId, deviceInfo = {}) {
  const visitor = await prisma.visitor.findUnique({
    where: { qrToken },
    include: { unit: true }
  });

  if (!visitor) {
    return { success: false, result: 'INVALID', message: 'Token not found' };
  }

  if (visitor.societyId !== societyId) {
    return { success: false, result: 'INVALID', message: 'Token belongs to another society' };
  }

  if (visitor.status === 'USED') {
    return { success: false, result: 'USED', message: 'Token already used' };
  }

  if (new Date() > visitor.qrExpiresAt) {
    await prisma.visitor.update({
      where: { id: visitor.id },
      data: { status: 'EXPIRED' }
    });
    return { success: false, result: 'EXPIRED', message: 'Token has expired' };
  }

  // Record logs in transaction
  return prisma.$transaction(async (tx) => {
    // 1. Create log
    await tx.visitorLog.create({
      data: {
        visitorId: visitor.id,
        scannedBy: scannerId,
        scanResult: 'VALID',
        deviceInfo
      }
    });

    // 2. Update visitor status
    const updated = await tx.visitor.update({
      where: { id: visitor.id },
      data: { status: 'USED' },
      include: { unit: true, inviter: { select: { fcmToken: true, name: true } } }
    });

    return { 
      success: true, 
      result: 'VALID', 
      visitor: {
        name: visitor.visitorName,
        unit: visitor.unit.fullCode
      }
    };
  });
}

module.exports = {
  listVisitors,
  inviteVisitor,
  validateToken
};
