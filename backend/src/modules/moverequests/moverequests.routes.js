const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./moverequests.controller');

router.use(auth);

router.get('/mine', roleGuard(['RESIDENT']), checkPlanLimit('move_requests'), c.getMyMoveRequests);
router.get('/', checkPlanLimit('move_requests'), c.getAllMoveRequests);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT']), checkPlanLimit('move_requests'), c.createMoveRequest);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.updateMoveRequest);
router.patch('/:id/check-dues', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.checkDues);
router.patch('/:id/issue-noc', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.issueNoc);
router.patch('/:id/approve', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.approveMoveRequest);
router.patch('/:id/reject', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.rejectMoveRequest);
router.patch('/:id/complete', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.completeMoveRequest);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('move_requests'), c.deleteMoveRequest);

module.exports = router;
