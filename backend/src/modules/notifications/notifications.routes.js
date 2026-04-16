const { Router } = require('express');
const notificationsController = require('./notifications.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// Notification routes (all protected)
router.use(authMiddleware);

// Visible to admins for history
const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN', 'TREASURER', 'ASSISTANT_SECRETARY', 'ASSISTANT_TREASURER'];
router.get('/', roleGuard(ADMIN_ROLES), notificationsController.getNotifications);

// Residents see their own notifications
router.get('/me', notificationsController.getMyNotifications);

// Register / update FCM token (any authenticated user)
router.post('/fcm-token', notificationsController.registerFcmToken);

// Send (Only admins)
router.post('/send', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), notificationsController.sendNotification);

module.exports = router;
