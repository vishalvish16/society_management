const billsService = require('./bills.service');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * GET /api/v1/bills
 */
async function getBills(req, res) {
  try {
    const filters = req.query;
    const result = await billsService.listBills(req.user.societyId, filters);
    return sendSuccess(res, result, 'Bills retrieved successfully');
  } catch (error) {
    console.error('Get bills error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * GET /api/v1/bills/:id
 */
async function getBillById(req, res) {
  try {
    const { id } = req.params;
    const bill = await billsService.getBill(id, req.user.societyId);
    return sendSuccess(res, bill, 'Bill details retrieved');
  } catch (error) {
    console.error('Get bill by ID error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/bills/generate
 */
async function bulkGenerate(req, res) {
  try {
    const { month, defaultAmount, dueDate } = req.body;

    if (!month || !defaultAmount || !dueDate) {
      return sendError(res, 'Month, defaultAmount, and dueDate are required', 400);
    }

    const result = await billsService.bulkGenerateBills(req.user.societyId, month, Number(defaultAmount), new Date(dueDate));
    return sendSuccess(res, result, `Generated ${result.count} bills for ${month}`, 201);
  } catch (error) {
    console.error('Bulk generate bills error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/bills/:id/pay
 */
async function recordPayment(req, res) {
  try {
    const { id: billId } = req.params;
    const { paidAmount, paymentMethod, notes } = req.body;

    if (!paidAmount || !paymentMethod) {
      return sendError(res, 'paidAmount and paymentMethod are required', 400);
    }

    const updated = await billsService.recordPayment(billId, {
      paidAmount: Number(paidAmount),
      paymentMethod,
      notes
    }, req.user.societyId);

    return sendSuccess(res, updated, 'Payment recorded successfully');
  } catch (error) {
    console.error('Record payment error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getBills,
  getBillById,
  bulkGenerate,
  recordPayment
};
