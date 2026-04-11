const { Router } = require('express');
const expensesController = require('./expenses.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

// Expense routes (all protected)
router.use(authMiddleware);

// Visible to admins and watchmen (based on build doc "Expenses (Admin/Watchman upload)")
router.get('/', roleGuard(['PRAMUKH', 'SECRETARY', 'WATCHMAN']), expensesController.getExpenses);
router.get('/summary', roleGuard(['PRAMUKH', 'SECRETARY']), expensesController.getSummary);

router.post('/', roleGuard(['PRAMUKH', 'SECRETARY', 'WATCHMAN']), checkPlanLimit('expenses'), expensesController.submitExpense);

// Review (Only admins)
router.patch('/:id/review', roleGuard(['PRAMUKH', 'SECRETARY']), expensesController.reviewExpense);

module.exports = router;
