const { Router } = require('express');
const visitorsController = require('./visitors.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

// Visitor routes (all protected)
router.use(authMiddleware);

// Visible to admins, watchmen and residents
router.get('/', roleGuard(['PRAMUKH', 'SECRETARY', 'WATCHMAN', 'RESIDENT']), visitorsController.getVisitors);

// Invite (Only admins and residents)
router.post('/invite', roleGuard(['PRAMUKH', 'SECRETARY', 'RESIDENT']), checkPlanLimit('visitors'), visitorsController.inviteVisitor);

// Validate (Only watchmen)
router.post('/validate', roleGuard(['WATCHMAN']), visitorsController.validateToken);

module.exports = router;
