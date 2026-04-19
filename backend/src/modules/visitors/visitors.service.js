const crypto = require('crypto');

const prisma                                      = require('../../config/db');
const notificationsService                        = require('../notifications/notifications.service');
const { pushToUnit }                              = require('../../utils/push');
const { sendVisitorQrMail }                       = require('../../utils/mailer');
const WhatsApp                                    = require('../../utils/whatsapp');
const { generateQrBuffer, buildVisitorQrPayload } = require('../../utils/qrGenerator');
const { getVisitorQrMaxHrs }                      = require('../../utils/platformSettings');

// ─── helpers ──────────────────────────────────────────────────────────────────

function fmtDate(d) {
  if (!d) return null;
  return new Intl.DateTimeFormat('en-IN', {
    day:    '2-digit',
    month:  'short',
    year:   'numeric',
    hour:   '2-digit',
    minute: '2-digit',
    hour12: true,
  }).format(new Date(d));
}

/**
 * Fire-and-forget: generate QR and dispatch via email + WhatsApp.
 * All errors are caught and logged — never propagate to the caller.
 */
async function _dispatchVisitorQr(visitor, unit, host, society) {
  try {
    const qrPayload   = buildVisitorQrPayload(visitor.qrToken);
    const qrBuffer    = await generateQrBuffer(qrPayload);
    const expiresStr  = fmtDate(visitor.qrExpiresAt);
    const arrivalStr  = fmtDate(visitor.expectedArrival);
    const societyName = society?.name  || 'Your Society';
    const hostName    = host?.name     || 'Resident';
    const unitCode    = unit?.fullCode || '-';

    // ── Email ────────────────────────────────────────────────────────────────
    // Only send if the visitor provided an email address
    if (visitor.visitorEmail) {
      setImmediate(() =>
        sendVisitorQrMail({
          to:              visitor.visitorEmail,
          visitorName:     visitor.visitorName,
          societyName,
          unitCode,
          hostName,
          expectedArrival: arrivalStr,
          qrExpiresAt:     expiresStr,
          qrImageBuffer:   qrBuffer,
          qrToken:         visitor.qrToken,
        }).catch((e) => console.error('[Visitor] Email dispatch error:', e.message))
      );
    }

    // ── WhatsApp ─────────────────────────────────────────────────────────────
    if (visitor.visitorPhone) {
      setImmediate(() =>
        WhatsApp.sendVisitorQr({
          phone:           visitor.visitorPhone,
          visitorName:     visitor.visitorName,
          societyName,
          unitCode,
          hostName,
          expectedArrival: arrivalStr,
          qrExpiresAt:     expiresStr,
          qrToken:         visitor.qrToken,
          // qrImageUrl: set this if you host the QR image publicly
        }).catch((e) => console.error('[Visitor] WhatsApp dispatch error:', e.message))
      );
    }
  } catch (err) {
    console.error('[Visitor] QR dispatch error:', err.message);
  }
}

// ─── List visitors ────────────────────────────────────────────────────────────

/**
 * List visitors for a society or specific unit.
 */
async function listVisitors(societyId, filters = {}) {
  const { unitId, status, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = { societyId };
  if (unitId) where.unitId = unitId;
  if (status) where.status = status;

  const [visitors, total] = await Promise.all([
    prisma.visitor.findMany({
      where,
      include: {
        unit:    { select: { fullCode: true } },
        inviter: { select: { id: true, name: true } },
        log:     { include: { scanner: { select: { name: true } } } },
      },
      skip,
      take:    parseInt(limit, 10),
      orderBy: { createdAt: 'desc' },
    }),
    prisma.visitor.count({ where }),
  ]);

  return { visitors, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

// ─── Invite visitor ───────────────────────────────────────────────────────────

/**
 * Create a new visitor invitation, generate a QR token, and
 * send the QR code to the visitor via email + WhatsApp.
 *
 * @param {string} userId
 * @param {string} societyId
 * @param {Object} data
 * @param {string} data.unitId
 * @param {string} data.visitorName
 * @param {string} data.visitorPhone
 * @param {string} [data.visitorEmail]     Optional — triggers email dispatch
 * @param {string} [data.expectedArrival]  ISO date string
 * @param {number} [data.expiryHours=24]
 * @param {string} [data.noteForWatchman]
 */
async function inviteVisitor(userId, societyId, data) {
  const {
    unitId,
    visitorName,
    visitorPhone,
    visitorEmail,
    numberOfAdults = 1,
    description,
    expectedArrival,
    expiryHours = 24,
    noteForWatchman,
  } = data;

  // Verify unit belongs to society
  const unit = await prisma.unit.findUnique({
    where:  { id: unitId },
    select: { id: true, fullCode: true, societyId: true },
  });
  if (!unit || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found in your society'), { status: 404 });
  }

  // Cap requested expiry: society override → platform default
  const platformMaxHrs = await getVisitorQrMaxHrs();
  const society        = await prisma.society.findUnique({ where: { id: societyId }, select: { settings: true } });
  const societyMaxHrs  = society?.settings?.visitor_qr_max_hrs
    ? parseInt(society.settings.visitor_qr_max_hrs, 10)
    : null;
  const effectiveMaxHrs = (Number.isFinite(societyMaxHrs) && societyMaxHrs > 0)
    ? societyMaxHrs
    : platformMaxHrs;
  const clampedHours = Math.min(Math.max(1, parseInt(expiryHours, 10) || effectiveMaxHrs), effectiveMaxHrs);

  const qrToken     = crypto.randomUUID();
  const qrExpiresAt = new Date();
  qrExpiresAt.setHours(qrExpiresAt.getHours() + clampedHours);

  const visitor = await prisma.visitor.create({
    data: {
      societyId,
      unitId,
      invitedById:     userId,
      visitorName,
      visitorPhone,
      visitorEmail:    visitorEmail || null,
      numberOfAdults:  parseInt(numberOfAdults, 10) || 1,
      description:     description || null,
      noteForWatchman: noteForWatchman || null,
      expectedArrival: expectedArrival ? new Date(expectedArrival) : null,
      qrToken,
      qrExpiresAt,
      status: 'PENDING',
    },
    include: {
      unit:    { select: { fullCode: true } },
      inviter: { select: { id: true, name: true } },
      society: { select: { name: true } },
    },
  });

  // Fetch host + society for notification content (non-blocking)
  setImmediate(async () => {
    try {
      const [host, society] = await Promise.all([
        prisma.user.findUnique({ where: { id: userId }, select: { name: true } }),
        prisma.society.findUnique({ where: { id: societyId }, select: { name: true } }),
      ]);
      await _dispatchVisitorQr(visitor, unit, host, society);
    } catch (e) {
      console.error('[Visitor] Post-create dispatch error:', e.message);
    }
  });

  return visitor;
}

// ─── Validate QR token ────────────────────────────────────────────────────────

/**
 * Validate a QR token scanned by a watchman.
 */
function normalizeQrToken(raw) {
  if (!raw || typeof raw !== 'string') return raw;
  const t = raw.trim();
  if (t.includes('/')) {
    const parts = t.split('/').filter(Boolean);
    if (parts.length) {
      try {
        return decodeURIComponent(parts[parts.length - 1]);
      } catch {
        return parts[parts.length - 1];
      }
    }
  }
  return t;
}

async function validateToken(qrToken, scannerId, societyId, _deviceInfo = {}) {
  qrToken = normalizeQrToken(qrToken);
  const visitor = await prisma.visitor.findUnique({
    where:   { qrToken },
    include: { unit: true },
  });

  if (!visitor) return { success: false, result: 'INVALID', message: 'Token not found' };

  if (visitor.societyId !== societyId) {
    return { success: false, result: 'INVALID', message: 'Token belongs to another society' };
  }

  if (visitor.status === 'USED') {
    // Fetch the scan log so we can tell watchman when it was used
    const scanLog = await prisma.visitorLog.findFirst({
      where:   { visitorId: visitor.id, scanResult: 'VALID' },
      orderBy: { scannedAt: 'desc' },
      include: { scanner: { select: { name: true } } },
    });
    return {
      success: false,
      result: 'used',
      message: 'This pass has already been scanned and used',
      scannedAt: scanLog?.scannedAt ?? null,
      scannedBy: scanLog?.scanner?.name ?? null,
    };
  }

  if (new Date() > visitor.qrExpiresAt) {
    await prisma.visitor.update({ where: { id: visitor.id }, data: { status: 'EXPIRED' } });
    return { success: false, result: 'expired', message: 'Token has expired' };
  }

  return prisma.$transaction(async (tx) => {
    await tx.visitorLog.create({
      data: { visitorId: visitor.id, scannedById: scannerId, scanResult: 'VALID' },
    });

    await tx.visitor.update({
      where: { id: visitor.id },
      data:  { status: 'USED' },
    });

    setImmediate(() =>
      notificationsService.sendNotification(null, societyId, {
        targetType: 'unit',
        targetId: visitor.unitId,
        title: '🚪 Visitor Arrived',
        body:  `${visitor.visitorName} has checked in at the gate for ${visitor.unit.fullCode}.`,
        type: 'VISITOR',
        route: '/visitors',
        excludeUserId: scannerId
      })
    );

    return {
      success: true,
      result:  'VALID',
      visitor: { name: visitor.visitorName, unit: visitor.unit.fullCode },
    };
  });
}

// ─── Walk-in entry ────────────────────────────────────────────────────────────

/**
 * Record a walk-in visitor entry (no advance invitation).
 * Only used by watchmen or admins — NO QR dispatch.
 */
async function logWalkinEntry(userId, societyId, data) {
  const { unitId, visitorName, visitorPhone, numberOfAdults = 1, description, noteForWatchman } = data;

  const unit = await prisma.unit.findUnique({ where: { id: unitId } });
  if (!unit || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found in your society'), { status: 404 });
  }

  return prisma.$transaction(async (tx) => {
    const visitor = await tx.visitor.create({
      data: {
        societyId,
        unitId,
        invitedById:     userId,
        visitorName,
        visitorPhone,
        numberOfAdults:  parseInt(numberOfAdults, 10) || 1,
        description:     description || null,
        noteForWatchman: noteForWatchman || null,
        qrToken:         crypto.randomUUID(),
        qrExpiresAt:     new Date(),   // immediate expiry — walk-in
        status:          'USED',
      },
    });

    await tx.visitorLog.create({
      data: { visitorId: visitor.id, scannedById: userId, scanResult: 'VALID' },
    });

    return visitor;
  });
}

module.exports = {
  listVisitors,
  inviteVisitor,
  validateToken,
  logWalkinEntry,
};
