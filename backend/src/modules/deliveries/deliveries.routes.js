const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const createUploader = require('../../middleware/uploadGeneric');
const c = require('./deliveries.controller');

const upload = createUploader('deliveries');

router.use(auth);

router.get('/today', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('delivery_tracking'), c.getTodayDeliveries);
router.get('/mine', roleGuard(['RESIDENT', 'MEMBER']), checkPlanLimit('delivery_tracking'), c.getMyDeliveries);
router.get('/', checkPlanLimit('delivery_tracking'), c.getAllDeliveries);
router.post(
  '/',
  roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']),
  checkPlanLimit('delivery_tracking'),
  c.createDelivery
);
router.patch('/:id/respond', roleGuard(['RESIDENT', 'MEMBER', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('delivery_tracking'), c.respondToDelivery);
router.patch('/:id/collect', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('delivery_tracking'), c.markCollected);
router.patch('/:id/return', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('delivery_tracking'), c.markReturned);
router.patch('/:id/drop-photo', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('delivery_tracking'), upload.single('photo'), c.uploadDropPhoto);

module.exports = router;
