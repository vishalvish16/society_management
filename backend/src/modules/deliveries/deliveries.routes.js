const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./deliveries.controller');

router.use(auth);

router.get('/today', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getTodayDeliveries);
router.get('/mine', roleGuard(['RESIDENT']), c.getMyDeliveries);
router.get('/', c.getAllDeliveries);
router.post('/', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createDelivery);
router.patch('/:id/respond', roleGuard(['RESIDENT', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.respondToDelivery);
router.patch('/:id/collect', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.markCollected);

module.exports = router;
