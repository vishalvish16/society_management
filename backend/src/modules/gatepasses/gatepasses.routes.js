const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./gatepasses.controller');

router.use(auth);

router.get(
  '/verify/:passCode',
  roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']),
  c.verifyGatePass,
);

router.get('/mine', roleGuard(['RESIDENT', 'MEMBER']), checkPlanLimit('gate_passes'), c.listMyGatePasses);
router.get('/', checkPlanLimit('gate_passes'), c.listGatePasses);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('gate_passes'), c.createGatePass);
router.post('/scan', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('gate_passes'), c.scanGatePass);
router.patch('/:id/cancel', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT']), checkPlanLimit('gate_passes'), c.cancelGatePass);

module.exports = router;
