const { Router } = require('express');
const expensesController = require('./expenses.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const permissionGuard = require('../../middleware/permissionGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

const upload = require('../../middleware/upload');

router.use(authMiddleware);

// All expense routes require the `expenses` feature
router.get('/pending', roleGuard(['PRAMUKH', 'CHAIRMAN']), checkPlanLimit('expenses'), expensesController.getPendingExpenses);
router.get('/summary', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('expenses'), expensesController.getSummary);
router.get('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN', 'MEMBER', 'RESIDENT']), checkPlanLimit('expenses'), expensesController.getExpenses);

router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), upload.array('attachments', 5), checkPlanLimit('expenses'), expensesController.submitExpense);
router.put('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), upload.array('attachments', 5), checkPlanLimit('expenses'), expensesController.updateExpense);
router.post('/:id/convert-to-bill', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('expenses'), expensesController.convertToBill);

// Approval workflow — requires expense_approval feature (Standard+)
router.patch('/:id/approve', permissionGuard('expense_approval'), checkPlanLimit('expense_approval'), expensesController.approveExpense);
router.patch('/:id/reject', permissionGuard('expense_approval'), checkPlanLimit('expense_approval'), expensesController.rejectExpense);
router.patch('/:id/review', permissionGuard('expense_approval'), checkPlanLimit('expense_approval'), expensesController.reviewExpense);

module.exports = router;
