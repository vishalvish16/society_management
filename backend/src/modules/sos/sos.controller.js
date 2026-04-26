const { sendSuccess, sendError } = require('../../utils/response');
const sosService = require('./sos.service');

/**
 * POST /api/sos/trigger
 * Body: { unitId: string, message?: string }
 */
async function triggerSos(req, res) {
  try {
    const { unitId, message } = req.body || {};
    if (!unitId) return sendError(res, 'unitId is required', 400);

    const result = await sosService.triggerSos(req.user, { unitId, message });
    return sendSuccess(res, result, 'SOS sent', 201);
  } catch (error) {
    console.error('Trigger SOS error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/sos/ack
 * Body: { notificationId?: string }
 * (Currently best-effort: records "read" for that notification if provided)
 */
async function acknowledgeSos(req, res) {
  try {
    const { notificationId } = req.body || {};
    const result = await sosService.acknowledgeSos(req.user, { notificationId });
    return sendSuccess(res, result, 'SOS acknowledged');
  } catch (error) {
    console.error('Acknowledge SOS error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = { triggerSos, acknowledgeSos };

