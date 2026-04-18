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

async function updateVisitor(req, res) {
  try {
    const { id } = req.params;
    const { societyId, id: userId, role } = req.user;
    const prisma = require('../../config/db');

    const visitor = await prisma.visitor.findUnique({ where: { id } });
    if (!visitor || visitor.societyId !== societyId) {
      return sendError(res, 'Visitor not found', 404);
    }
    if (visitor.status !== 'PENDING') {
      return sendError(res, 'Only pending visitors can be edited', 400);
    }

    const isAdmin = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY'].includes(role);
    if (!isAdmin && visitor.invitedById !== userId) {
      return sendError(res, 'You can only edit visitors you invited', 403);
    }

    const { visitorName, visitorPhone, visitorEmail, numberOfAdults, description, noteForWatchman, expiryHours } = req.body;

    const updateData = {};
    if (visitorName)    updateData.visitorName    = visitorName;
    if (visitorPhone)   updateData.visitorPhone   = visitorPhone;
    if (visitorEmail !== undefined) updateData.visitorEmail = visitorEmail || null;
    if (numberOfAdults) updateData.numberOfAdults = parseInt(numberOfAdults, 10);
    if (description !== undefined)     updateData.description     = description || null;
    if (noteForWatchman !== undefined) updateData.noteForWatchman = noteForWatchman || null;
    if (expiryHours) {
      const hrs = Math.max(1, parseInt(expiryHours, 10));
      const newExpiry = new Date();
      newExpiry.setHours(newExpiry.getHours() + hrs);
      updateData.qrExpiresAt = newExpiry;
    }

    const updated = await prisma.visitor.update({
      where: { id },
      data:  updateData,
      include: {
        unit:    { select: { fullCode: true } },
        inviter: { select: { id: true, name: true } },
      },
    });

    return sendSuccess(res, updated, 'Visitor updated');
  } catch (error) {
    console.error('Update visitor error:', error.message);
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
  updateVisitor,
  validateToken,
  getMyVisitors,
  getVisitorLog,
  getTodayVisitorLog,
  logWalkin,
  getVisitorConfig,
};
