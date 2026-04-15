const expensesService = require('./expenses.service');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * GET /api/v1/expenses
 */
async function getExpenses(req, res) {
  try {
    const filters = req.query;
    const result = await expensesService.listExpenses(req.user.societyId, filters);
    return sendSuccess(res, result, 'Expenses retrieved successfully');
  } catch (error) {
    console.error('Get expenses error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/expenses
 */
async function submitExpense(req, res) {
  try {
    const { category, title, description, amount, expenseDate, attachments } = req.body;

    if (!category || !title || !amount || !expenseDate) {
      return sendError(res, 'Category, title, amount, and expenseDate are required', 400);
    }

    const expense = await expensesService.submitExpense(
      req.user.id,
      req.user.societyId,
      { category, title, description, amount: Number(amount), expenseDate },
      req.files
    );


    return sendSuccess(res, expense, 'Expense submitted for review', 201);
  } catch (error) {
    console.error('Submit expense error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * PATCH /api/v1/expenses/:id/review
 */
async function reviewExpense(req, res) {
  try {
    const { id: expenseId } = req.params;
    const { status, rejectionReason } = req.body;

    if (!['approved', 'rejected'].includes(status)) {
      return sendError(res, 'Status must be approved or rejected', 400);
    }

    const reviewed = await expensesService.reviewExpense(expenseId, req.user.id, status, req.user.societyId, rejectionReason);
    return sendSuccess(res, reviewed, `Expense ${status} successfully`);
  } catch (error) {
    console.error('Review expense error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * GET /api/v1/expenses/summary
 */
async function getSummary(req, res) {
  try {
    const { startDate, endDate } = req.query;

    if (!startDate || !endDate) {
      return sendError(res, 'startDate and endDate are required', 400);
    }


    const result = await expensesService.getExpenseSummary(req.user.societyId, startDate, endDate);
    return sendSuccess(res, result, 'Expense summary retrieved');
  } catch (error) {
    console.error('Get expense summary error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function getPendingExpenses(req, res) {
  try {
    const result = await expensesService.listExpenses(req.user.societyId, { ...req.query, status: 'PENDING' });
    return sendSuccess(res, result, 'Pending expenses retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function approveExpense(req, res) {
  try {
    const reviewed = await expensesService.reviewExpense(req.params.id, req.user.id, 'approved', req.user.societyId);
    return sendSuccess(res, reviewed, 'Expense approved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function updateExpense(req, res) {
  try {
    const { category, title, description, amount, expenseDate } = req.body;
    const updated = await expensesService.updateExpense(
      req.params.id,
      req.user.societyId,
      { category, title, description, amount, expenseDate },
      req.files
    );
    return sendSuccess(res, updated, 'Expense updated successfully');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function rejectExpense(req, res) {
  try {
    const { rejectionReason } = req.body;
    if (!rejectionReason) return sendError(res, 'rejectionReason is required', 400);
    const reviewed = await expensesService.reviewExpense(req.params.id, req.user.id, 'rejected', req.user.societyId, rejectionReason);
    return sendSuccess(res, reviewed, 'Expense rejected');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getExpenses,
  submitExpense,
  updateExpense,
  reviewExpense,
  getSummary,
  getPendingExpenses,
  approveExpense,
  rejectExpense,
};
