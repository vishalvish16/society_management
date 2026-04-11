const notificationsService = require('./notifications.service');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * GET /api/v1/notifications
 */
async function getNotifications(req, res) {
  try {
    const filters = req.query;
    const result = await notificationsService.listNotifications(req.user.societyId, filters);
    return sendSuccess(res, result, 'Notification history retrieved');
  } catch (error) {
    console.error('Get notifications error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * GET /api/v1/notifications/me
 */
async function getMyNotifications(req, res) {
  try {
    const notifications = await notificationsService.getNotificationsForUser(req.user.id, req.user.societyId);
    return sendSuccess(res, notifications, 'Your recent notifications retrieved');
  } catch (error) {
    console.error('Get my notifications error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/notifications/send
 */
async function sendNotification(req, res) {
  try {
    const { targetType, targetId, title, body, type } = req.body;

    if (!targetType || !title || !body || !type) {
      return sendError(res, 'TargetType, title, body, and type are required', 400);
    }

    const notification = await notificationsService.sendNotification(req.user.id, req.user.societyId, {
      targetType, targetId, title, body, type
    });

    return sendSuccess(res, notification, 'Notification sent successfully', 201);
  } catch (error) {
    console.error('Send notification error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getNotifications,
  getMyNotifications,
  sendNotification
};
