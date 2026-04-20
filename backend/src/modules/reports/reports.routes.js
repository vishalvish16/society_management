const { Router } = require('express');
const ctrl = require('./reports.controller');
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();
router.use(auth);

// Financial summary — admin committee only
const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER'];

// Balance report — all roles except regular members/residents
const BALANCE_ROLES = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'WATCHMAN', 'SUPER_ADMIN'];

router.get('/financial', roleGuard(ADMIN_ROLES), checkPlanLimit('financial_reports'), ctrl.getFinancialReport);
router.get('/balance', roleGuard(BALANCE_ROLES), checkPlanLimit('financial_reports'), ctrl.getBalanceReport);

module.exports = router;
