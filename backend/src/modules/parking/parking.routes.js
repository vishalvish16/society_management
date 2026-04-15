const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./parking.controller');

router.use(auth);

router.get('/slots', c.listSlots);
router.post('/slots', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createSlot);
router.patch('/slots/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateSlot);
router.patch('/slots/:id/assign', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.assignSlot);
router.patch('/slots/:id/unassign', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.unassignSlot);

module.exports = router;
