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
router.get('/ledger', roleGuard(BALANCE_ROLES), checkPlanLimit('financial_reports'), ctrl.getLedgerReport);
router.post('/ledger/entry', roleGuard(BALANCE_ROLES), checkPlanLimit('financial_reports'), ctrl.createLedgerEntry);
router.post('/ledger/transfer', roleGuard(BALANCE_ROLES), checkPlanLimit('financial_reports'), ctrl.createLedgerTransfer);

// Dues report — any authenticated user (admins see all, members see own unit)
router.get('/dues', ctrl.getDuesReport);
router.post('/dues/remind', roleGuard(ADMIN_ROLES), ctrl.sendDueReminder);
router.post('/dues/remind-all', roleGuard(ADMIN_ROLES), ctrl.sendBulkDueReminder);

module.exports = router;
