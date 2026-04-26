const notificationsService = require('./notifications.service');
const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

async function getNotifications(req, res) {
  try {
    const result = await notificationsService.listNotifications(req.user.societyId, req.query);
    return sendSuccess(res, result, 'Notification history retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getMyNotifications(req, res) {
  try {
    const notifications = await notificationsService.getNotificationsForUser(
      req.user.id,
      req.user.societyId,
      req.user.unitId || null
    );
    return sendSuccess(res, notifications, 'Your notifications retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function sendNotification(req, res) {
  try {
    const { targetType, targetId, title, body, type, route } = req.body;
    if (!targetType || !title || !body || !type) {
      return sendError(res, 'targetType, title, body, and type are required', 400);
    }
    const notification = await notificationsService.sendNotification(
      req.user.id, req.user.societyId, { targetType, targetId, title, body, type, route }
    );
    return sendSuccess(res, notification, 'Notification sent', 201);
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/notifications/fcm-token
 * Called by Flutter app on every launch to register/refresh the FCM token.
 */
async function registerFcmToken(req, res) {
  try {
    const { token } = req.body;
    if (!token) return sendError(res, 'token is required', 400);
    await prisma.user.update({
      where: { id: req.user.id },
      data: { fcmToken: token },
    });
    return sendSuccess(res, null, 'FCM token registered');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
}

module.exports = { getNotifications, getMyNotifications, sendNotification, registerFcmToken };
