const { Router } = require('express');
const superadminController = require('./superadmin.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// All super admin dashboard routes require SUPER_ADMIN
router.use(authMiddleware);
router.use(roleGuard('SUPER_ADMIN'));

router.get('/dashboard', superadminController.getDashboard);
router.get('/revenue', superadminController.getRevenue);
router.get('/societies/recent', superadminController.getRecentSocieties);

// Platform settings
router.get('/settings', superadminController.getSettings);
router.patch('/settings/:key', superadminController.updateSetting);

module.exports = router;
