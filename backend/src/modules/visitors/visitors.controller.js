const visitorsService = require('./visitors.service');
const { sendSuccess, sendError } = require('../../utils/response');
const { getVisitorQrMaxHrs } = require('../../utils/platformSettings');

/**
 * GET /api/v1/visitors
 */
async function getVisitors(req, res) {
  try {
    const filters = req.query;
    const result = await visitorsService.listVisitors(req.user.societyId, filters);
    return sendSuccess(res, result, 'Visitors retrieved successfully');
  } catch (error) {
    console.error('Get visitors error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/visitors/invite
 */
async function inviteVisitor(req, res) {
  try {
    const { unitId, visitorName, visitorPhone, visitorEmail, numberOfAdults, description, expectedArrival, expiryHours, noteForWatchman } = req.body;

    if (!unitId || !visitorName || !visitorPhone) {
      return sendError(res, 'Unit ID, visitor name, and phone are required', 400);
    }

    const invitation = await visitorsService.inviteVisitor(req.user.id, req.user.societyId, {
      unitId, visitorName, visitorPhone, visitorEmail, numberOfAdults, description, expectedArrival, expiryHours, noteForWatchman,
    });

    return sendSuccess(res, invitation, 'Visitor invitation created', 201);
  } catch (error) {
    console.error('Invite visitor error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/visitors/validate
 */
async function validateToken(req, res) {
  try {
    const { qrToken, deviceInfo } = req.body;

    if (!qrToken) {
      return sendError(res, 'QR token is required', 400);
    }

    const result = await visitorsService.validateToken(qrToken, req.user.id, req.user.societyId, deviceInfo);

    if (result.success) {
      return sendSuccess(res, result.visitor, `Access granted for ${result.visitor.name}`);
    } else {
      return sendError(res, result.message, 401, { result: result.result });
    }
  } catch (error) {
    console.error('Validate token error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function getVisitorLog(req, res) {
  try {
    const { societyId } = req.user;
    const { page = 1, limit = 20 } = req.query;
    const prisma = require('../../config/db');
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [logs, total] = await Promise.all([
      prisma.visitorLog.findMany({
        where: { visitor: { societyId } },
        skip, take: parseInt(limit),
        orderBy: { scannedAt: 'desc' },
        include: {
          visitor: { select: { visitorName: true, visitorPhone: true, unit: { select: { fullCode: true } } } },
          scanner: { select: { name: true } },
        },
      }),
      prisma.visitorLog.count({ where: { visitor: { societyId } } }),
    ]);

    return sendSuccess(res, { logs, total, page: parseInt(page), limit: parseInt(limit) }, 'Visitor log retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getTodayVisitorLog(req, res) {
  try {
    const { societyId } = req.user;
    const prisma = require('../../config/db');
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const logs = await prisma.visitorLog.findMany({
      where: { scannedAt: { gte: startOfDay }, visitor: { societyId } },
      orderBy: { scannedAt: 'desc' },
      include: {
        visitor: { select: { visitorName: true, visitorPhone: true, unit: { select: { fullCode: true } } } },
        scanner: { select: { name: true } },
      },
    });

    return sendSuccess(res, logs, "Today's visitor log retrieved");
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getMyVisitors(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const prisma = require('../../config/db');

    const where = { societyId, invitedById: userId };
    if (status) where.status = status;

    const [visitors, total] = await Promise.all([
      prisma.visitor.findMany({
        where, skip, take: parseInt(limit),
        orderBy: { createdAt: 'desc' },
      }),
      prisma.visitor.count({ where }),
    ]);

    return sendSuccess(res, { visitors, total, page: parseInt(page), limit: parseInt(limit) }, 'Your visitors retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function logWalkin(req, res) {
  try {
    const { unitId, visitorName, visitorPhone, numberOfAdults, description, noteForWatchman } = req.body;

    if (!unitId || !visitorName || !visitorPhone) {
      return sendError(res, 'Unit ID, visitor name, and phone are required', 400);
    }

    const log = await visitorsService.logWalkinEntry(req.user.id, req.user.societyId, {
      unitId, visitorName, visitorPhone, numberOfAdults, description, noteForWatchman
    });

    return sendSuccess(res, log, 'Visitor entry logged successfully', 201);
  } catch (error) {
    console.error('Log walk-in error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * GET /api/v1/visitors/config
 * Returns platform-level visitor configuration (max QR expiry hours).
 * Any authenticated user can read this so the invite form can enforce the cap.
 */
async function getVisitorConfig(req, res) {
  try {
    const { societyId } = req.user;
    const prisma = require('../../config/db');

    // 1. Get Platform Default
    let effectiveMaxHrs = await getVisitorQrMaxHrs();

    // 2. If user is in a society, check for society-level override
    if (societyId) {
      const society = await prisma.society.findUnique({
        where: { id: societyId },
        select: { settings: true }
      });

      const societyLimit = society?.settings?.visitor_qr_max_hrs;
      if (societyLimit && !isNaN(parseInt(societyLimit))) {
        effectiveMaxHrs = parseInt(societyLimit);
      }
    }

    return sendSuccess(res, { visitorQrMaxHrs: effectiveMaxHrs });
  } catch (error) {
    console.error('Get visitor config error:', error.message);
    return sendError(res, error.message, 500);
  }
}

module.exports = {
  getVisitors,
  inviteVisitor,
  validateToken,
  getMyVisitors,
  getVisitorLog,
  getTodayVisitorLog,
  logWalkin,
  getVisitorConfig,
};
