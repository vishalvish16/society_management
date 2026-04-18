const { Router } = require('express');
const ctrl = require('./reports.controller');
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();
router.use(auth);

const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER'];

router.get('/financial', roleGuard(ADMIN_ROLES), ctrl.getFinancialReport);

module.exports = router;
