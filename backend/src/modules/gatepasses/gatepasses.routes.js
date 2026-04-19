const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./gatepasses.controller');

router.use(auth);

router.get(
  '/verify/:passCode',
  roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']),
  c.verifyGatePass,
);

router.get('/mine', roleGuard(['RESIDENT', 'MEMBER']), c.listMyGatePasses);
router.get('/', c.listGatePasses);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.createGatePass);
router.post('/scan', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.scanGatePass);
router.patch('/:id/cancel', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT']), c.cancelGatePass);

module.exports = router;
