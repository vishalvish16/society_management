const { Router } = require('express');
const dashboardController = require('./dashboard.controller');
const authMiddleware = require('../../middleware/auth');

const router = Router();
router.use(authMiddleware);

// All authenticated users can view stats
router.get('/stats',    dashboardController.getStats);
router.get('/trends',   dashboardController.getTrends);
router.get('/settings', dashboardController.getSettings);
router.patch('/settings', dashboardController.updateSettings);

module.exports = router;
