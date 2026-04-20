const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./gates.controller');

router.use(auth);

router.get('/', checkPlanLimit('society_gates'), c.listGates);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('society_gates'), c.createGate);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('society_gates'), c.deleteGate);

module.exports = router;
