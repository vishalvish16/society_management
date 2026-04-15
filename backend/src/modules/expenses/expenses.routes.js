const { Router } = require('express');
const expensesController = require('./expenses.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

const upload = require('../../middleware/upload');

// Expense routes (all protected)
router.use(authMiddleware);

// Visible to admins and watchmen (based on build doc "Expenses (Admin/Watchman upload)")
router.get('/pending', roleGuard(['PRAMUKH', 'CHAIRMAN']), expensesController.getPendingExpenses);
router.get('/summary', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), expensesController.getSummary);
router.get('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN', 'MEMBER', 'RESIDENT']), expensesController.getExpenses);

router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), upload.array('attachments', 5), checkPlanLimit('expenses'), expensesController.submitExpense);
router.put('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), upload.array('attachments', 5), expensesController.updateExpense);

// Review (Only CHAIRMAN)
router.patch('/:id/approve', roleGuard(['PRAMUKH', 'CHAIRMAN']), expensesController.approveExpense);
router.patch('/:id/reject', roleGuard(['PRAMUKH', 'CHAIRMAN']), expensesController.rejectExpense);
router.patch('/:id/review', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), expensesController.reviewExpense);

module.exports = router;
