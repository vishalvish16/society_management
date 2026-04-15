const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./moverequests.controller');

router.use(auth);

router.get('/mine', roleGuard(['RESIDENT']), c.getMyMoveRequests);
router.get('/', c.getAllMoveRequests);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT']), c.createMoveRequest);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateMoveRequest);
router.patch('/:id/check-dues', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.checkDues);
router.patch('/:id/issue-noc', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.issueNoc);
router.patch('/:id/approve', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.approveMoveRequest);
router.patch('/:id/reject', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.rejectMoveRequest);
router.patch('/:id/complete', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.completeMoveRequest);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteMoveRequest);

module.exports = router;
