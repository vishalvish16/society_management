const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');

function getMonthStart(input = new Date()) {
  const date = new Date(input);
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function getMonthEnd(input = new Date()) {
  const date = new Date(input);
  return new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
}

function addMonths(date, count) {
  const next = new Date(date);
  next.setMonth(next.getMonth() + count);
  return next;
}

function formatMonthLabel(date) {
  return new Intl.DateTimeFormat('en-IN', { month: 'long', year: 'numeric' }).format(date);
}

function normalizePaymentMethod(method) {
  const value = String(method || '').toUpperCase();
  const mapping = {
    CASH: 'CASH',
    UPI: 'UPI',
    ONLINE: 'ONLINE',
    RAZORPAY: 'RAZORPAY',
    BANK: 'BANK',
    BANK_TRANSFER: 'BANK',
    CHEQUE: 'BANK',
    OTHER: 'BANK',
  };

  return mapping[value] || 'ONLINE';
}

function isMaintenanceCharge(bill) {
  return bill.category === 'MAINTENANCE';
}

async function getLatestActiveAdvanceCoverageTo(tx, societyId, unitId) {
  const latestAdvance = await tx.maintenanceBill.findFirst({
    where: {
      societyId,
      unitId,
      category: 'ADVANCE_RECEIPT',
      deletedAt: null,
    },
    orderBy: { coverageTo: 'desc' },
    select: { coverageTo: true },
  });

  return latestAdvance?.coverageTo || null;
}

async function createBillAuditLog(tx, {
  billId,
  societyId,
  unitId,
  actorId = null,
  action,
  note = null,
  metadata = null,
}) {
  return tx.billAuditLog.create({
    data: {
      billId,
      societyId,
      unitId,
      actorId,
      action,
      note,
      metadata,
    },
  });
}

/**
 * List bills with filters.
 * @param {string} societyId
 * @param {{ unitId?: string, status?: string, month?: string, page?: number, limit?: number }} filters
 */
async function listBills(societyId, filters = {}) {
  const { unitId, status, month, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = { societyId, deletedAt: null };

  if (unitId) where.unitId = unitId;
  if (status) where.status = status.toUpperCase();
  if (month) {
    const startOfMonth = getMonthStart(month);
    const endOfMonth = getMonthEnd(month);
    where.billingMonth = { gte: startOfMonth, lte: endOfMonth };
  }

  const [bills, total] = await Promise.all([
    prisma.maintenanceBill.findMany({
      where,
      include: {
        unit: {
          select: {
            fullCode: true,
            wing: true,
            unitNumber: true,
            prepaidUntil: true,
          },
        },
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: [{ billingMonth: 'desc' }, { createdAt: 'desc' }],
    }),
    prisma.maintenanceBill.count({ where }),
  ]);

  return { bills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

/**
 * Generate bills for all occupied units in a society for a given month.
 * Covered prepaid units are skipped instead of receiving a monthly bill.
 */
async function bulkGenerateBills(societyId, month, defaultAmount, dueDate, generatedById = null) {
  const billingMonth = getMonthStart(month);

  const units = await prisma.unit.findMany({
    where: { societyId, status: 'OCCUPIED', deletedAt: null },
  });

  if (units.length === 0) {
    throw Object.assign(new Error('No occupied units found to bill'), { status: 404 });
  }

  const existingBills = await prisma.maintenanceBill.findMany({
    where: {
      societyId,
      billingMonth,
      deletedAt: null,
      unitId: { in: units.map((unit) => unit.id) },
    },
    select: { unitId: true },
  });

  const existingUnitIds = new Set(existingBills.map((bill) => bill.unitId));
  const candidateUnits = units.filter((unit) => !existingUnitIds.has(unit.id));

  const overlappingAdvanceReceipts = await prisma.maintenanceBill.findMany({
    where: {
      societyId,
      unitId: { in: candidateUnits.map((unit) => unit.id) },
      category: 'ADVANCE_RECEIPT',
      deletedAt: null,
      coverageFrom: { lte: getMonthEnd(billingMonth) },
      coverageTo: { gte: billingMonth },
    },
    select: { unitId: true },
  });
  const prepaidUnitIds = new Set(overlappingAdvanceReceipts.map((bill) => bill.unitId));

  if (candidateUnits.length === 0) {
    throw Object.assign(new Error('Bills already generated for all units for this month'), { status: 400 });
  }

  let createdCount = 0;
  let skippedPrepaidCount = 0;
  let skippedAdvanceCount = 0;

  for (const unit of candidateUnits) {
    const finalAmount = unit.maintenanceAmount ? Number(unit.maintenanceAmount) : defaultAmount;

    if (prepaidUnitIds.has(unit.id)) {
      skippedPrepaidCount += 1;
      continue;
    }

    let paidAmount = 0;
    let status = 'PENDING';
    let notes = null;
    let currentAdvance = Number(unit.advanceBalance || 0);

    if (currentAdvance >= finalAmount) {
      await prisma.unit.update({
        where: { id: unit.id },
        data: { advanceBalance: currentAdvance - finalAmount },
      });
      skippedAdvanceCount += 1;
      continue;
    }

    if (currentAdvance > 0) {
      paidAmount = Math.min(currentAdvance, finalAmount);
      currentAdvance -= paidAmount;
      status = paidAmount >= finalAmount ? 'PAID' : 'PARTIAL';
      notes = 'Adjusted from legacy advance balance';

      await prisma.unit.update({
        where: { id: unit.id },
        data: { advanceBalance: currentAdvance },
      });
    }

    const createdBill = await prisma.$transaction(async (tx) => {
      const bill = await tx.maintenanceBill.create({
        data: {
          societyId,
          unitId: unit.id,
          createdById: generatedById,
          billingMonth,
          amount: finalAmount,
          totalDue: finalAmount,
          paidAmount,
          status,
          dueDate: new Date(dueDate),
          notes,
        },
      });

      await createBillAuditLog(tx, {
        billId: bill.id,
        societyId,
        unitId: unit.id,
        actorId: generatedById,
        action: 'GENERATED',
        note: `Bill generated for ${formatMonthLabel(billingMonth)}`,
        metadata: {
          billingMonth,
          amount: finalAmount,
          dueDate: new Date(dueDate),
          status,
        },
      });

      return bill;
    });
    createdCount += 1;

    const monthLabel = formatMonthLabel(billingMonth);
    notificationsService.sendNotification(generatedById, societyId, {
      targetType: 'unit',
      targetId: createdBill.unitId,
      title: 'Maintenance Bill Generated',
      body: `Your maintenance bill of Rs ${finalAmount} for ${monthLabel} is now due.`,
      type: 'BILL',
      route: '/bills',
      excludeUserId: generatedById,
    });
  }

  if (createdCount === 0 && skippedPrepaidCount > 0) {
    throw Object.assign(new Error('All matching units are already covered by advance maintenance'), { status: 400 });
  }

  return { count: createdCount, skippedPrepaidCount, skippedAdvanceCount };
}

/**
 * Record an advance payment and issue a receipt bill entry so residents can see the payment slip.
 */
async function payAdvance(unitId, monthsCount, amountPerMonth, societyId, paymentData) {
  const totalAmount = Number((monthsCount * amountPerMonth).toFixed(2));
  const unit = await prisma.unit.findUnique({
    where: { id: unitId },
    select: {
      id: true,
      societyId: true,
      fullCode: true,
    },
  });

  if (!unit || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found'), { status: 404 });
  }

  const coverageStart = getMonthStart(paymentData.startDate);
  const coverageTo = getMonthEnd(addMonths(coverageStart, monthsCount - 1));

  const overlappingAdvance = await prisma.maintenanceBill.findFirst({
    where: {
      societyId,
      unitId,
      category: 'ADVANCE_RECEIPT',
      deletedAt: null,
      coverageFrom: { lte: coverageTo },
      coverageTo: { gte: coverageStart },
    },
    orderBy: { coverageTo: 'desc' },
    select: { coverageFrom: true, coverageTo: true },
  });

  if (overlappingAdvance) {
    throw Object.assign(
      new Error(
        `Advance period already exists from ${formatMonthLabel(overlappingAdvance.coverageFrom)} to ${formatMonthLabel(overlappingAdvance.coverageTo)}. Choose a non-overlapping period.`,
      ),
      { status: 400 },
    );
  }

  const result = await prisma.$transaction(async (tx) => {
    const latestCoverageTo = await getLatestActiveAdvanceCoverageTo(tx, societyId, unitId);
    const nextPrepaidUntil =
      !latestCoverageTo || coverageTo > latestCoverageTo ? coverageTo : latestCoverageTo;

    const updatedUnit = await tx.unit.update({
      where: { id: unitId },
      data: {
        prepaidUntil: nextPrepaidUntil,
      },
    });

    const receipt = await tx.maintenanceBill.create({
      data: {
        societyId,
        unitId,
        createdById: paymentData.actorId || null,
        billingMonth: new Date(),
        amount: totalAmount,
        totalDue: totalAmount,
        status: 'PAID',
        dueDate: new Date(),
        paidAmount: totalAmount,
        paidAt: new Date(),
        paidById: paymentData.actorId || null,
        paymentMethod: normalizePaymentMethod(paymentData.paymentMethod),
        notes: paymentData.notes || null,
        title: 'Advance Maintenance Receipt',
        description: `Advance maintenance paid for ${monthsCount} month(s), covering ${formatMonthLabel(coverageStart)} to ${formatMonthLabel(coverageTo)}.`,
        category: 'ADVANCE_RECEIPT',
        coverageFrom: coverageStart,
        coverageTo,
      },
    });

    await createBillAuditLog(tx, {
      billId: receipt.id,
      societyId,
      unitId,
      actorId: paymentData.actorId || null,
      action: 'ADVANCE_RECORDED',
      note: `Advance maintenance recorded for ${monthsCount} month(s)`,
      metadata: {
        monthsCount,
        amountPerMonth,
        totalAmount,
        startDate: coverageStart,
        coverageTo,
        paymentMethod: normalizePaymentMethod(paymentData.paymentMethod),
      },
    });

    return { updatedUnit, receipt };
  });

  await notificationsService.sendNotification(null, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title: 'Advance Maintenance Recorded',
    body: `Advance maintenance has been recorded for ${monthsCount} month(s) for unit ${unit.fullCode}.`,
    type: 'PAYMENT',
    route: '/bills',
  });

  return {
    unit: result.updatedUnit,
    receipt: result.receipt,
  };
}

/**
 * Split an expense equally among all occupied units.
 */
async function splitExpenseAmongUnits(societyId, expenseId, totalAmount, title, description, generatedById) {
  const units = await prisma.unit.findMany({
    where: { societyId, status: 'OCCUPIED', deletedAt: null },
  });

  if (units.length === 0) throw new Error('No occupied units found');

  const perUnitAmount = (Number(totalAmount) / units.length).toFixed(2);
  const dueDate = new Date();
  dueDate.setDate(dueDate.getDate() + 7);

  const billsData = units.map((unit) => ({
    societyId,
    unitId: unit.id,
    billingMonth: new Date(),
    amount: perUnitAmount,
    totalDue: perUnitAmount,
    status: 'PENDING',
    dueDate,
    title,
    description,
    category: 'EVENT',
  }));

  const result = await prisma.maintenanceBill.createMany({ data: billsData });

  setImmediate(() => {
    units.forEach((unit) => {
      notificationsService.sendNotification(generatedById, societyId, {
        targetType: 'unit',
        targetId: unit.id,
        title: `${title} contribution`,
        body: `A charge of Rs ${perUnitAmount} has been added for ${title}.`,
        type: 'BILL',
        route: '/bills',
      });
    });
  });

  return result;
}

async function getResidentUnitIds(userId) {
  const unitResidents = await prisma.unitResident.findMany({
    where: { userId },
    select: { unitId: true },
  });
  return unitResidents.map((item) => item.unitId);
}

async function recordPayment(billId, paymentData, societyId, allowedUnitIds = null) {
  const bill = await prisma.maintenanceBill.findUnique({
    where: { id: billId },
  });

  if (!bill || bill.deletedAt) {
    throw Object.assign(new Error('Bill not found'), { status: 404 });
  }

  if (bill.societyId !== societyId) {
    throw Object.assign(new Error('Cannot access bills outside your society'), { status: 403 });
  }

  if (allowedUnitIds !== null && !allowedUnitIds.includes(bill.unitId)) {
    throw Object.assign(new Error('You can only pay bills for your own unit'), { status: 403 });
  }

  if (bill.status === 'PAID') {
    throw Object.assign(new Error('Bill is already paid in full'), { status: 400 });
  }

  const paidAmount = Number(paymentData.paidAmount);
  const newPaidAmount = Number(bill.paidAmount) + paidAmount;
  const remaining = Number(bill.totalDue) - newPaidAmount;

  let newStatus = 'PARTIAL';
  if (remaining <= 0) {
    newStatus = 'PAID';
  } else if (newPaidAmount === 0 && Number(bill.totalDue) > 0) {
    newStatus = 'PENDING';
  } else if (new Date(bill.dueDate) < new Date()) {
    newStatus = 'OVERDUE';
  }

  return prisma.$transaction(async (tx) => {
    const updatedBill = await tx.maintenanceBill.update({
      where: { id: billId },
      data: {
        paidAmount: newPaidAmount,
        paidAt: new Date(),
        paidById: paymentData.actorId || bill.paidById,
        paymentMethod: normalizePaymentMethod(paymentData.paymentMethod),
        notes: paymentData.notes || bill.notes,
        status: newStatus,
      },
    });

    await createBillAuditLog(tx, {
      billId,
      societyId,
      unitId: bill.unitId,
      actorId: paymentData.actorId || null,
      action: 'PAYMENT_RECORDED',
      note: `Payment recorded for unit bill ${bill.unitId}`,
      metadata: {
        amountPaid: paidAmount,
        totalPaid: newPaidAmount,
        remaining,
        paymentMethod: normalizePaymentMethod(paymentData.paymentMethod),
      },
    });

    return updatedBill;
  });
}

async function getBill(billId, societyId) {
  const bill = await prisma.maintenanceBill.findUnique({
    where: { id: billId },
    include: {
      unit: true,
      createdBy: { select: { id: true, name: true, role: true } },
      paidBy: { select: { id: true, name: true, role: true } },
      deletedBy: { select: { id: true, name: true, role: true } },
    },
  });

  if (!bill || bill.deletedAt) throw Object.assign(new Error('Bill not found'), { status: 404 });
  if (bill.societyId !== societyId) throw Object.assign(new Error('Access denied'), { status: 403 });

  const society = await prisma.society.findUnique({
    where: { id: bill.societyId },
    select: { name: true, logoUrl: true, address: true },
  });

  return {
    ...bill,
    society,
  };
}

async function listBillAuditLogs(billId, societyId) {
  const bill = await prisma.maintenanceBill.findUnique({
    where: { id: billId },
    select: { id: true, societyId: true, deletedAt: true },
  });

  if (!bill || bill.societyId !== societyId) {
    throw Object.assign(new Error('Bill not found'), { status: 404 });
  }

  return prisma.billAuditLog.findMany({
    where: { billId, societyId },
    include: {
      actor: {
        select: { id: true, name: true, role: true },
      },
      bill: {
        select: {
          unit: {
            select: { fullCode: true },
          },
        },
      },
    },
    orderBy: { createdAt: 'desc' },
  });
}

async function listAllBillAuditLogs(societyId, filters = {}) {
  const { page = 1, limit = 20, unitId, action, billId } = filters;
  const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);

  const where = { societyId };
  if (unitId) where.unitId = unitId;
  if (billId) where.billId = billId;
  if (action) where.action = action.toUpperCase();

  const [logs, total] = await Promise.all([
    prisma.billAuditLog.findMany({
      where,
      include: {
        actor: {
          select: { id: true, name: true, role: true },
        },
        bill: {
          select: {
            id: true,
            title: true,
            category: true,
            billingMonth: true,
            deletedAt: true,
            unit: {
              select: { id: true, fullCode: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: parseInt(limit, 10),
    }),
    prisma.billAuditLog.count({ where }),
  ]);

  return {
    logs,
    total,
    page: parseInt(page, 10),
    limit: parseInt(limit, 10),
  };
}

async function softDeleteBill(billId, societyId, deletedById) {
  const bill = await prisma.maintenanceBill.findUnique({
    where: { id: billId },
    include: {
      unit: {
        select: { id: true, fullCode: true },
      },
    },
  });

  if (!bill || bill.deletedAt) {
    throw Object.assign(new Error('Bill not found'), { status: 404 });
  }
  if (bill.societyId !== societyId) {
    throw Object.assign(new Error('Access denied'), { status: 403 });
  }

  return prisma.$transaction(async (tx) => {
    let nextPrepaidUntil = null;

    if (bill.category === 'ADVANCE_RECEIPT') {
      nextPrepaidUntil = await getLatestActiveAdvanceCoverageTo(tx, societyId, bill.unitId);
    }

    const deletedBill = await tx.maintenanceBill.update({
      where: { id: billId },
      data: {
        deletedAt: new Date(),
        deletedById,
      },
    });

    if (bill.category === 'ADVANCE_RECEIPT') {
      nextPrepaidUntil = await getLatestActiveAdvanceCoverageTo(tx, societyId, bill.unitId);
      await tx.unit.update({
        where: { id: bill.unitId },
        data: {
          prepaidUntil: nextPrepaidUntil,
        },
      });
    }

    await createBillAuditLog(tx, {
      billId,
      societyId,
      unitId: bill.unitId,
      actorId: deletedById,
      action: 'DELETED',
      note: `Bill soft-deleted for unit ${bill.unit?.fullCode || bill.unitId}`,
      metadata: {
        billingMonth: bill.billingMonth,
        totalDue: bill.totalDue,
        status: bill.status,
        category: bill.category,
        prepaidUntilAfterDelete: nextPrepaidUntil,
      },
    });

    return deletedBill;
  });
}

async function getMyBills(userId, societyId, filters = {}) {
  const { page = 1, limit = 20, status } = filters;
  const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);

  const unitResidents = await prisma.unitResident.findMany({
    where: { userId },
    select: { unitId: true },
  });
  const unitIds = unitResidents.map((item) => item.unitId);

  if (unitIds.length === 0) {
    return { bills: [], total: 0, page: parseInt(page, 10), limit: parseInt(limit, 10) };
  }

  const where = { societyId, unitId: { in: unitIds }, deletedAt: null };
  if (status) where.status = status.toUpperCase();

  const [bills, total] = await Promise.all([
    prisma.maintenanceBill.findMany({
      where,
      include: {
        unit: {
          select: {
            fullCode: true,
            wing: true,
            unitNumber: true,
            prepaidUntil: true,
          },
        },
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: [{ billingMonth: 'desc' }, { createdAt: 'desc' }],
    }),
    prisma.maintenanceBill.count({ where }),
  ]);

  return { bills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

async function getDefaulters(societyId, filters = {}) {
  const { page = 1, limit = 20 } = filters;
  const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);

  const where = {
    societyId,
    deletedAt: null,
    status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] },
    category: 'MAINTENANCE',
  };

  const [bills, total] = await Promise.all([
    prisma.maintenanceBill.findMany({
      where,
      include: {
        unit: {
          select: {
            fullCode: true,
            wing: true,
            unitNumber: true,
            residents: {
              select: {
                user: { select: { id: true, name: true, phone: true } },
              },
            },
          },
        },
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { dueDate: 'asc' },
    }),
    prisma.maintenanceBill.count({ where }),
  ]);

  return { bills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

async function runOverdueReminderSweep() {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const unpaidBills = await prisma.maintenanceBill.findMany({
    where: {
      status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] },
      dueDate: { lt: todayStart },
      deletedAt: null,
      category: 'MAINTENANCE',
    },
    include: {
      unit: {
        select: {
          id: true,
          fullCode: true,
          residents: {
            select: {
              user: { select: { id: true, name: true } },
            },
          },
        },
      },
    },
    orderBy: { billingMonth: 'asc' },
  });

  const byUnit = new Map();
  for (const bill of unpaidBills) {
    if (!isMaintenanceCharge(bill)) continue;
    const list = byUnit.get(bill.unitId) || [];
    list.push(bill);
    byUnit.set(bill.unitId, list);
  }

  let remindersSent = 0;

  for (const [unitId, unitBills] of byUnit.entries()) {
    if (unitBills.length < 2) continue;

    const notRemindedToday = unitBills.filter((bill) => {
      if (!bill.lastReminderAt) return true;
      const reminderDate = new Date(bill.lastReminderAt);
      reminderDate.setHours(0, 0, 0, 0);
      return reminderDate.getTime() !== todayStart.getTime();
    });

    if (notRemindedToday.length === 0) continue;

    const totalOutstanding = unitBills.reduce(
      (sum, bill) => sum + (Number(bill.totalDue) - Number(bill.paidAmount)),
      0,
    );
    const oldestBill = unitBills[0];

    await notificationsService.sendNotification(null, oldestBill.societyId, {
      targetType: 'unit',
      targetId: unitId,
      title: 'Maintenance Payment Reminder',
      body: `You have ${unitBills.length} unpaid maintenance bill(s) for unit ${oldestBill.unit.fullCode}. Total outstanding is Rs ${totalOutstanding.toFixed(2)}.`,
      type: 'BILL',
      route: '/bills',
    });

    await prisma.maintenanceBill.updateMany({
      where: { id: { in: unitBills.map((bill) => bill.id) } },
      data: {
        status: 'OVERDUE',
        lastReminderAt: new Date(),
      },
    });

    remindersSent += 1;
  }

  return { remindersSent };
}

module.exports = {
  listBills,
  bulkGenerateBills,
  payAdvance,
  recordPayment,
  getBill,
  listBillAuditLogs,
  listAllBillAuditLogs,
  softDeleteBill,
  getMyBills,
  getDefaulters,
  getResidentUnitIds,
  runOverdueReminderSweep,
};
