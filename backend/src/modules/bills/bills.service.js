const prisma = require('../../config/db');

/**
 * List bills with filters.
 * @param {string} societyId
 * @param {{ unitId?: string, status?: string, month?: string, page?: number, limit?: number }} filters
 */
async function listBills(societyId, filters = {}) {
  const { unitId, status, month, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = {
    societyId,
  };

  if (unitId) where.unitId = unitId;
  if (status) where.status = status;
  if (month) {
    const date = new Date(month);
    const startOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
    const endOfMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59);
    where.billingMonth = {
      gte: startOfMonth,
      lte: endOfMonth
    };
  }

  const [bills, total] = await Promise.all([
    prisma.maintenanceBill.findMany({
      where,
      include: {
        unit: {
          select: { fullCode: true, wing: true, unitNumber: true }
        }
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { billingMonth: 'desc' }
    }),
    prisma.maintenanceBill.count({ where })
  ]);

  return { bills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

/**
 * Generate bills for all occupied units in a society for a given month.
 * @param {string} societyId
 * @param {string} month - ISO string of the month (e.g. '2023-10-01')
 * @param {number} defaultAmount - The flat maintenance fee
 * @param {Date} dueDate - Due date for the payments
 */
async function bulkGenerateBills(societyId, month, defaultAmount, dueDate) {
  const billingMonth = new Date(month);
  billingMonth.setDate(1); // Ensure it starts on the 1st
  billingMonth.setHours(0, 0, 0, 0);

  // 1. Get all occupied units in the society
  const units = await prisma.unit.findMany({
    where: { societyId, status: 'OCCUPIED', deletedAt: null }
  });

  if (units.length === 0) {
    throw Object.assign(new Error('No occupied units found to bill'), { status: 404 });
  }

  // 2. Check if bills already exist for this month to prevent duplicates
  const existingBills = await prisma.maintenanceBill.findMany({
    where: {
      societyId,
      billingMonth,
      unitId: { in: units.map(u => u.id) }
    },
    select: { unitId: true }
  });

  const existingUnitIds = new Set(existingBills.map(b => b.unitId));
  const newUnits = units.filter(u => !existingUnitIds.has(u.id));

  if (newUnits.length === 0) {
    throw Object.assign(new Error('Bills already generated for all units for this month'), { status: 400 });
  }

  // 3. Create bills in bulk
  const billsData = newUnits.map(unit => ({
    societyId,
    unitId: unit.id,
    billingMonth,
    amount: defaultAmount,
    totalDue: defaultAmount,
    status: 'PENDING',
    dueDate: new Date(dueDate),
  }));

  return prisma.maintenanceBill.createMany({
    data: billsData
  });
}

/**
 * Record a payment for a bill.
 * @param {string} billId
 * @param {{ paidAmount: number, paymentMethod: string, notes?: string }} paymentData
 * @param {string} societyId
 */
async function recordPayment(billId, paymentData, societyId) {
  const bill = await prisma.maintenanceBill.findUnique({
    where: { id: billId }
  });

  if (!bill) {
    throw Object.assign(new Error('Bill not found'), { status: 404 });
  }

  if (bill.societyId !== societyId) {
    throw Object.assign(new Error('Cannot access bills outside your society'), { status: 403 });
  }

  if (bill.status === 'PAID') {
    throw Object.assign(new Error('Bill is already paid in full'), { status: 400 });
  }

  const { paidAmount, paymentMethod, notes } = paymentData;
  const newPaidAmount = Number(bill.paidAmount) + paidAmount;
  const remaining = Number(bill.totalDue) - newPaidAmount;

  let newStatus = 'PARTIAL';
  if (remaining <= 0) {
    newStatus = 'PAID';
  } else if (newPaidAmount === 0 && Number(bill.totalDue) > 0) {
    newStatus = 'PENDING';
  }

  return prisma.maintenanceBill.update({
    where: { id: billId },
    data: {
      paidAmount: newPaidAmount,
      paidAt: new Date(),
      paymentMethod,
      notes: notes || bill.notes,
      status: newStatus
    }
  });
}

/**
 * Get a specific bill details.
 */
async function getBill(billId, societyId) {
  const bill = await prisma.maintenanceBill.findUnique({
    where: { id: billId },
    include: {
      unit: true,
      society: { select: { name: true, logoUrl: true, address: true } }
    }
  });

  if (!bill) throw Object.assign(new Error('Bill not found'), { status: 404 });
  if (bill.societyId !== societyId) throw Object.assign(new Error('Access denied'), { status: 403 });

  return bill;
}

module.exports = {
  listBills,
  bulkGenerateBills,
  recordPayment,
  getBill
};
