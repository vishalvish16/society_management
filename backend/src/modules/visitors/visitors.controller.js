const visitorsService = require('./visitors.service');
const { sendSuccess, sendError } = require('../../utils/response');

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
    const { unitId, visitorName, visitorPhone, expectedArrival, expiryHours } = req.body;

    if (!unitId || !visitorName || !visitorPhone) {
      return sendError(res, 'Unit ID, visitor name, and phone are required', 400);
    }

    const invitation = await visitorsService.inviteVisitor(req.user.id, req.user.societyId, {
      unitId, visitorName, visitorPhone, expectedArrival, expiryHours
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

module.exports = {
  getVisitors,
  inviteVisitor,
  validateToken
};
