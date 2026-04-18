const { Router } = require('express');
const visitorsController = require('./visitors.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

// Visitor routes (all protected)
router.use(authMiddleware);

// QR expiry config (platform max hrs) — any authenticated user can read this
router.get('/config', visitorsController.getVisitorConfig);

// Resident's/Member's own visitors
router.get('/mine', roleGuard(['RESIDENT', 'MEMBER']), visitorsController.getMyVisitors);

// Visible to admins, watchmen, residents and members
router.get('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN', 'RESIDENT', 'MEMBER']), visitorsController.getVisitors);

// Invite (admins, residents and members)
router.post('/invite', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('visitors'), visitorsController.inviteVisitor);

// Manual Log (Walk-in, only watchmen and admins)
router.post('/log-entry', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('visitors'), visitorsController.logWalkin);

// Update pending visitor (inviter or admin)
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), visitorsController.updateVisitor);

// Validate (Only watchmen)
router.post('/validate', roleGuard(['WATCHMAN']), visitorsController.validateToken);

// Visitor log
router.get('/log/today', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), visitorsController.getTodayVisitorLog);
router.get('/log', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), visitorsController.getVisitorLog);

module.exports = router;
