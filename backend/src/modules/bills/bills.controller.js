const billsService = require('./bills.service');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * GET /api/v1/bills
 */
async function getBills(req, res) {
  try {
    const filters = req.query;
    // Residents/Members only see bills for their active unit.
    if (req.user?.unitId && (req.user.role === 'RESIDENT' || req.user.role === 'MEMBER')) {
      filters.unitId = req.user.unitId;
    }
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
    const { month, defaultAmount, dueDate, cycles = 1 } = req.body;
    
    if (!month || !defaultAmount || !dueDate) {
      return sendError(res, 'Month, defaultAmount, and dueDate are required', 400);
    }

    let totalCreated = 0;
    const startDate = new Date(month);

    for (let i = 0; i < cycles; i++) {
      const currentMonth = new Date(startDate);
      currentMonth.setMonth(startDate.getMonth() + i);
      const currentDueDate = new Date(dueDate);
      currentDueDate.setMonth(currentDueDate.getMonth() + i);

      const result = await billsService.bulkGenerateBills(
        req.user.societyId,
        currentMonth.toISOString(),
        Number(defaultAmount),
        currentDueDate,
        req.user.id
      );
      totalCreated += result.count;
    }

    return sendSuccess(res, { count: totalCreated }, `Generated bills for ${cycles} month(s)`, 201);
  } catch (error) {
    console.error('Bulk generate bills error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/bills/pay-advance
 */
async function payAdvance(req, res) {
  try {
    const { unitId, monthsCount, amountPerMonth, paymentMethod, notes, startDate } = req.body;

    if (!unitId || !monthsCount || !amountPerMonth || !paymentMethod || !startDate) {
      return sendError(res, 'unitId, monthsCount, amountPerMonth, paymentMethod and startDate are required', 400);
    }

    if (Number(monthsCount) <= 0 || Number(amountPerMonth) <= 0) {
      return sendError(res, 'monthsCount and amountPerMonth must be greater than zero', 400);
    }

    if (Number.isNaN(new Date(startDate).getTime())) {
      return sendError(res, 'startDate must be a valid date', 400);
    }

    const result = await billsService.payAdvance(unitId, Number(monthsCount), Number(amountPerMonth), req.user.societyId, {
      actorId: req.user.id,
      paymentMethod,
      notes,
      startDate,
    });

    return sendSuccess(res, result, 'Advance payment recorded successfully');
  } catch (error) {
    console.error('Pay advance error:', error.message);
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

    const adminRoles = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY'];
    const isAdmin = adminRoles.includes(req.user.role);

    // Non-admins can only pay bills for units they belong to
    const residentUnitIds = isAdmin
      ? null
      : await billsService.getResidentUnitIds(req.user.id, req.user.societyId, req.user.unitId || null);

    const updated = await billsService.recordPayment(billId, {
      paidAmount: Number(paidAmount),
      actorId: req.user.id,
      paymentMethod,
      notes
    }, req.user.societyId, residentUnitIds);

    return sendSuccess(res, updated, 'Payment recorded successfully');
  } catch (error) {
    console.error('Record payment error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function getMyBills(req, res) {
  try {
    const result = await billsService.getMyBills(req.user.id, req.user.societyId, req.query, req.user.unitId || null);
    return sendSuccess(res, result, 'Your bills retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getDefaulters(req, res) {
  try {
    const result = await billsService.getDefaulters(req.user.societyId, req.query);
    return sendSuccess(res, result, 'Defaulters retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getAllBillAuditLogs(req, res) {
  try {
    const result = await billsService.listAllBillAuditLogs(req.user.societyId, req.query);
    return sendSuccess(res, result, 'Bill audit logs retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function deleteBill(req, res) {
  try {
    const result = await billsService.softDeleteBill(req.params.id, req.user.societyId, req.user.id);
    return sendSuccess(res, result, 'Bill deleted successfully');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getBillAuditLogs(req, res) {
  try {
    const logs = await billsService.listBillAuditLogs(req.params.id, req.user.societyId);
    return sendSuccess(res, logs, 'Bill audit logs retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * GET /api/bills/schedules
 * Admin-only: list bill generation schedules for this society.
 */
async function listSchedules(req, res) {
  try {
    const schedules = await billsService.listMaintenanceBillSchedules(req.user.societyId);
    return sendSuccess(res, schedules, 'Bill schedules retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/bills/schedules
 * Admin-only: create/update a schedule for a billing month.
 * Body: { billingMonth, scheduledFor, defaultAmount, dueDate, isActive? }
 */
async function upsertSchedule(req, res) {
  try {
    const { billingMonth, scheduledFor, defaultAmount, dueDate, isActive } = req.body || {};

    if (!billingMonth || !scheduledFor || !defaultAmount || !dueDate) {
      return sendError(res, 'billingMonth, scheduledFor, defaultAmount, and dueDate are required', 400);
    }

    const schedule = await billsService.upsertMaintenanceBillSchedule(
      req.user.societyId,
      { billingMonth, scheduledFor, defaultAmount, dueDate, isActive },
      req.user.id,
    );

    return sendSuccess(res, schedule, 'Bill schedule saved', 201);
  } catch (error) {
    console.error('Upsert schedule error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getBills,
  getBillById,
  bulkGenerate,
  recordPayment,
  payAdvance,
  getAllBillAuditLogs,
  deleteBill,
  getBillAuditLogs,
  getMyBills,
  getDefaulters,
  upsertSchedule,
  listSchedules,
};
