const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./rules.controller');

router.use(auth);

router.get('/', c.getRules);
router.get('/:id', c.getRuleById);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createRule);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateRule);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteRule);
router.post('/reorder', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.reorderRules);

module.exports = router;
