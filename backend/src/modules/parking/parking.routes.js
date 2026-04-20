const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./parking.controller');

router.use(auth);

router.get('/slots', checkPlanLimit('parking_management'), c.listSlots);
router.post('/slots', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('parking_management'), c.createSlot);
router.patch('/slots/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('parking_management'), c.updateSlot);
router.patch('/slots/:id/assign', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('parking_management'), c.assignSlot);
router.patch('/slots/:id/unassign', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('parking_management'), c.unassignSlot);

module.exports = router;
