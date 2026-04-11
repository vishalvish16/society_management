const { Router } = require('express');
const notificationsController = require('./notifications.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// Notification routes (all protected)
router.use(authMiddleware);

// Visible to admins for history
router.get('/', roleGuard(['PRAMUKH', 'SECRETARY']), notificationsController.getNotifications);

// Residents see their own notifications
router.get('/me', notificationsController.getMyNotifications);

// Send (Only admins)
router.post('/send', roleGuard(['PRAMUKH', 'SECRETARY']), notificationsController.sendNotification);

module.exports = router;
