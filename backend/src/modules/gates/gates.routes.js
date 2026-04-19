const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./gates.controller');

router.use(auth);

router.get('/', c.listGates);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createGate);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteGate);

module.exports = router;
