const { Router } = require('express');
const settingsController = require('./settings.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();
router.use(authMiddleware);

// Any member of the society can read payment settings (to know where to pay)
router.get('/payment', settingsController.getPaymentSettings);

// Only admins can update
router.patch('/payment', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), settingsController.updatePaymentSettings);

// Role permissions — any member can read (needed for sidebar filtering), only admins can update
router.get('/permissions', settingsController.getRolePermissions);
router.put('/permissions', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), settingsController.updateRolePermissions);

module.exports = router;
