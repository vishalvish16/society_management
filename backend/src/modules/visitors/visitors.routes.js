const { Router } = require('express');
const visitorsController = require('./visitors.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const createUploader = require('../../middleware/uploadGeneric');

const router = Router();
const upload = createUploader('visitors');

router.use(authMiddleware);

// QR config — metadata only, no plan gate needed
router.get('/config', visitorsController.getVisitorConfig);

// Pending walk-in approvals for unit members — no plan gate (gate security is always available)
router.get('/pending-approvals', roleGuard(['RESIDENT', 'MEMBER', 'PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), visitorsController.getPendingApprovals);

// All visitor reads/writes require at least the `visitors` feature
router.get('/mine', roleGuard(['RESIDENT', 'MEMBER']), checkPlanLimit('visitors'), visitorsController.getMyVisitors);
router.get('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN', 'RESIDENT', 'MEMBER']), checkPlanLimit('visitors'), visitorsController.getVisitors);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('visitors'), visitorsController.updateVisitor);
router.patch('/:id/approve', roleGuard(['RESIDENT', 'MEMBER', 'PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), visitorsController.approveWalkin);
router.post('/validate', roleGuard(['WATCHMAN']), checkPlanLimit('visitors'), visitorsController.validateToken);
router.get('/log/today', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('visitors'), visitorsController.getTodayVisitorLog);
router.get('/log', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), checkPlanLimit('visitors'), visitorsController.getVisitorLog);

// QR invite — requires visitor_qr (Standard+)
router.post('/invite', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('visitor_qr'), visitorsController.inviteVisitor);

// Walk-in log — accepts optional photo
router.post('/log-entry', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('visitors'), upload.single('photo'), visitorsController.logWalkin);

module.exports = router;
