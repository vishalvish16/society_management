const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');

function startOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function wholeDaysBetween(from, to) {
  const a = startOfDay(from).getTime();
  const b = startOfDay(to).getTime();
  return Math.max(0, Math.floor((b - a) / (24 * 60 * 60 * 1000)));
}

async function getSocietyLateFeePolicy(societyId) {
  const society = await prisma.society.findUnique({
    where: { id: societyId },
    select: { settings: true },
  });
  const settings = society?.settings || {};
  const type = String(settings.late_fee_type || '').toUpperCase(); // FIXED | PER_DAY | ''
  const graceDays = Number(settings.late_fee_grace_days || 0);
  const amount = Number(settings.late_fee_amount || 0);

  return {
    type: type === 'FIXED' || type === 'PER_DAY' ? type : 'NONE',
    graceDays: Number.isFinite(graceDays) && graceDays > 0 ? Math.floor(graceDays) : 0,
    amount: Number.isFinite(amount) && amount > 0 ? amount : 0,
  };
}

function computeLateFeeForBill(policy, bill, asOf = new Date()) {
  if (!policy || policy.type === 'NONE') return 0;
  if (policy.amount <= 0) return 0;
  if (!bill?.dueDate) return 0;
  if (String(bill.category || '').toUpperCase() !== 'MAINTENANCE') return 0;
  if (String(bill.status || '').toUpperCase() === 'PAID') return Number(bill.lateFee || 0);

  const daysLate = wholeDaysBetween(new Date(bill.dueDate), asOf);
  const effectiveDays = Math.max(0, daysLate - (policy.graceDays || 0));
  if (effectiveDays <= 0) return 0;

  if (policy.type === 'FIXED') return policy.amount;
  if (policy.type === 'PER_DAY') return Number((effectiveDays * policy.amount).toFixed(2));
  return 0;
}

function recomputeTotalsForBill(bill, lateFee) {
  const amount = Number(bill.amount || 0);
  const gstAmount = Number(bill.gstAmount || 0);
  const nextLateFee = Number(lateFee || 0);
  const total = Number((amount + gstAmount + nextLateFee).toFixed(2));
  return {
    lateFee: nextLateFee,
    totalDue: total,
  };
}

async function ensureLateFeeUpToDate(billId, societyId, asOf = new Date()) {
  const bill = await prisma.maintenanceBill.findUnique({ where: { id: billId } });
  if (!bill || bill.deletedAt) {
    throw Object.assign(new Error('Bill not found'), { status: 404 });
  }
  if (bill.societyId !== societyId) {
    throw Object.assign(new Error('Cannot access bills outside your society'), { status: 403 });
  }

  const policy = await getSocietyLateFeePolicy(societyId);
  const nextLateFee = computeLateFeeForBill(policy, bill, asOf);
  const { lateFee, totalDue } = recomputeTotalsForBill(bill, nextLateFee);

  const prevLate = Number(bill.lateFee || 0);
  const prevTotal = Number(bill.totalDue || 0);
  const changed =
    Math.abs(prevLate - lateFee) > 0.0001 || Math.abs(prevTotal - totalDue) > 0.0001;

  if (!changed) return bill;

  const updated = await prisma.maintenanceBill.update({
    where: { id: billId },
    data: {
      lateFee,
      totalDue,
      ...(bill.status === 'PENDING' || bill.status === 'PARTIAL' || bill.status === 'OVERDUE'
        ? { status: new Date(bill.dueDate) < asOf ? 'OVERDUE' : bill.status }
        : {}),
    },
  });

  // Audit for traceability in admin logs.
  await createBillAuditLog(prisma, {
    billId: updated.id,
    societyId: updated.societyId,
    unitId: updated.unitId,
    actorId: null,
    action: 'LATE_FEE_RECALCULATED',
    note: `Late fee recalculated as of ${asOf.toISOString()}`,
    metadata: {
      lateFeePolicy: policy,
      lateFeeBefore: prevLate,
      lateFeeAfter: lateFee,
      totalDueBefore: prevTotal,
      totalDueAfter: totalDue,
      dueDate: bill.dueDate,
    },
  });

  return updated;
}

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

  const [bills, total, policy] = await Promise.all([
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
    getSocietyLateFeePolicy(societyId),
  ]);

  const now = new Date();
  const normalizedBills = bills.map((bill) => {
    const lateFee = computeLateFeeForBill(policy, bill, now);
    const totals = recomputeTotalsForBill(bill, lateFee);
    return { ...bill, ...totals };
  });

  return { bills: normalizedBills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
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
          lateFee: 0,
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
 * Monthly parking bills for units with at least one ACTIVE parking allotment.
 * At most one PARKING bill per unit per billing month (same rule as POST /parking/charges/generate).
 */
async function bulkGenerateParkingBills(
  societyId,
  month,
  amount,
  dueDate,
  generatedById = null,
  options = {},
) {
  const billingMonth = getMonthStart(month);
  const monthEnd = getMonthEnd(billingMonth);
  const defaultAmount = Number(amount);
  if (!defaultAmount || defaultAmount <= 0) {
    throw Object.assign(new Error('Amount must be greater than zero'), { status: 400 });
  }

  const activeAllotments = await prisma.parkingAllotment.findMany({
    where: { societyId, status: 'ACTIVE' },
    include: {
      unit: { select: { id: true, fullCode: true } },
      slot: { select: { slotNumber: true } },
    },
  });

  if (activeAllotments.length === 0) {
    throw Object.assign(new Error('No active parking allotments found'), { status: 404 });
  }

  const unitIds = [...new Set(activeAllotments.map((a) => a.unitId))];

  const existingBills = await prisma.maintenanceBill.findMany({
    where: {
      societyId,
      category: 'PARKING',
      billingMonth: { gte: billingMonth, lte: monthEnd },
      deletedAt: null,
      unitId: { in: unitIds },
    },
    select: { unitId: true },
  });
  const alreadyBilledUnits = new Set(existingBills.map((b) => b.unitId));

  const monthLabel = formatMonthLabel(billingMonth);
  const descriptionOverride = options.description;

  const billsToCreate = [];
  const allotmentChosenByUnit = new Map();

  for (const a of activeAllotments) {
    if (alreadyBilledUnits.has(a.unitId)) continue;
    if (allotmentChosenByUnit.has(a.unitId)) continue;
    allotmentChosenByUnit.set(a.unitId, a);
    billsToCreate.push({
      societyId,
      unitId: a.unitId,
      createdById: generatedById || null,
      billingMonth,
      amount: defaultAmount,
      lateFee: 0,
      totalDue: defaultAmount,
      status: 'PENDING',
      dueDate: new Date(dueDate),
      title: 'Parking Charge',
      description:
        descriptionOverride ||
        `Monthly parking charge — Slot ${a.slot.slotNumber} — ${monthLabel}`,
      category: 'PARKING',
    });
  }

  if (billsToCreate.length === 0) {
    throw Object.assign(
      new Error('Parking bills already generated for all allotted units for this month'),
      { status: 400 },
    );
  }

  const result = await prisma.maintenanceBill.createMany({ data: billsToCreate });

  setImmediate(() => {
    for (const row of billsToCreate) {
      const allot = allotmentChosenByUnit.get(row.unitId);
      if (!allot) continue;
      notificationsService.sendNotification(generatedById, societyId, {
        targetType: 'unit',
        targetId: row.unitId,
        title: '🅿️ Parking Charge',
        body: `A parking charge of ₹${defaultAmount.toFixed(0)} for slot ${allot.slot.slotNumber} is now due.`,
        type: 'BILL',
        route: '/bills',
        excludeUserId: generatedById,
      });
    }
  });

  return {
    count: result.count,
    skippedExistingUnits: alreadyBilledUnits.size,
  };
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
  // Prevent splitting same expense multiple times (used by UI to hide split button)
  const splitMarker = `expenseSplit:${expenseId}`;
  const alreadySplit = await prisma.maintenanceBill.count({
    where: {
      societyId,
      deletedAt: null,
      notes: { contains: splitMarker },
    },
  });
  if (alreadySplit > 0) {
    throw Object.assign(new Error('Expense is already split among units'), { status: 400 });
  }

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
    category: 'EXPENSE',
    notes: splitMarker,
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

/**
 * Undo a previously split expense by soft-deleting the generated bills.
 * Only allowed if none of the generated bills has any payment recorded.
 */
async function undoSplitExpenseAmongUnits(societyId, expenseId, actorId) {
  const splitMarker = `expenseSplit:${expenseId}`;

  const bills = await prisma.maintenanceBill.findMany({
    where: {
      societyId,
      deletedAt: null,
      notes: { contains: splitMarker },
    },
    select: { id: true, status: true, paidAmount: true },
  });

  if (bills.length === 0) {
    throw Object.assign(new Error('No split bills found for this expense'), { status: 404 });
  }

  const hasAnyPayment = bills.some((b) => {
    const paid = Number(b.paidAmount || 0);
    return paid > 0 || ['PAID', 'PARTIAL'].includes(String(b.status || '').toUpperCase());
  });
  if (hasAnyPayment) {
    throw Object.assign(
      new Error('Cannot undo split because one or more bills already have payment recorded'),
      { status: 400 },
    );
  }

  const deleted = await prisma.maintenanceBill.updateMany({
    where: { id: { in: bills.map((b) => b.id) } },
    data: { deletedAt: new Date(), deletedById: actorId || null },
  });

  return { deletedCount: deleted.count };
}

async function getResidentUnitIds(userId, societyId, activeUnitId = null) {
  if (activeUnitId) return [activeUnitId];
  const unitResidents = await prisma.unitResident.findMany({
    where: { userId, unit: { societyId } },
    select: { unitId: true },
  });
  return unitResidents.map((item) => item.unitId);
}

async function recordPayment(billId, paymentData, societyId, allowedUnitIds = null) {
  // Ensure late fee is up-to-date before accepting payment amount.
  const bill = await ensureLateFeeUpToDate(billId, societyId, new Date());

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

    // If this is an amenity booking bill, sync payment status back to booking.
    if (updatedBill.category === 'AMENITY' && typeof updatedBill.notes === 'string') {
      const match = updatedBill.notes.match(/amenityBooking:([a-f0-9-]+)/i);
      if (match?.[1]) {
        await tx.amenityBooking.updateMany({
          where: { id: match[1], societyId: updatedBill.societyId },
          data: { paymentStatus: updatedBill.status === 'PAID' ? 'PAID' : 'PARTIAL' },
        });
      }
    }

    return updatedBill;
  });
}

async function getBill(billId, societyId) {
  await ensureLateFeeUpToDate(billId, societyId, new Date());

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

async function getMyBills(userId, societyId, filters = {}, activeUnitId = null) {
  const { page = 1, limit = 20, status } = filters;
  const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);

  const unitIds = await getResidentUnitIds(userId, societyId, activeUnitId);

  if (unitIds.length === 0) {
    return { bills: [], total: 0, page: parseInt(page, 10), limit: parseInt(limit, 10) };
  }

  const where = { societyId, unitId: { in: unitIds }, deletedAt: null };
  if (status) where.status = status.toUpperCase();

  const [bills, total, policy] = await Promise.all([
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
    getSocietyLateFeePolicy(societyId),
  ]);

  const now = new Date();
  const normalizedBills = bills.map((bill) => {
    const lateFee = computeLateFeeForBill(policy, bill, now);
    const totals = recomputeTotalsForBill(bill, lateFee);
    return { ...bill, ...totals };
  });

  return { bills: normalizedBills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
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

  const [bills, total, policy] = await Promise.all([
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
    getSocietyLateFeePolicy(societyId),
  ]);

  const now = new Date();
  const normalizedBills = bills.map((bill) => {
    const lateFee = computeLateFeeForBill(policy, bill, now);
    const totals = recomputeTotalsForBill(bill, lateFee);
    return { ...bill, ...totals };
  });

  return { bills: normalizedBills, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
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

  // Opportunistically update late fees for overdue bills once per sweep.
  // Keeps totals aligned even if nobody opens the bill screen.
  try {
    if (unpaidBills.length === 0) {
      // nothing to update
    } else {
      const policy = await getSocietyLateFeePolicy(unpaidBills[0].societyId);
    if (policy.type !== 'NONE') {
      for (const bill of unpaidBills) {
        const nextLateFee = computeLateFeeForBill(policy, bill, todayStart);
        const { lateFee, totalDue } = recomputeTotalsForBill(bill, nextLateFee);
        const prevLate = Number(bill.lateFee || 0);
        const prevTotal = Number(bill.totalDue || 0);
        if (Math.abs(prevLate - lateFee) < 0.0001 && Math.abs(prevTotal - totalDue) < 0.0001) continue;
        await prisma.maintenanceBill.update({
          where: { id: bill.id },
          data: { lateFee, totalDue, status: 'OVERDUE' },
        });
      }
    }
    }
  } catch (e) {
    console.error('[billing-jobs] late fee sweep failed:', e.message);
  }

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

async function upsertMaintenanceBillSchedule(societyId, scheduleInput, actorId) {
  const billingMonth = getMonthStart(scheduleInput.billingMonth);
  const scheduledFor = new Date(scheduleInput.scheduledFor);
  const dueDate = new Date(scheduleInput.dueDate);
  const defaultAmount = Number(scheduleInput.defaultAmount);
  const category = String(scheduleInput.category || 'MAINTENANCE').toUpperCase();

  if (category !== 'MAINTENANCE' && category !== 'PARKING') {
    throw Object.assign(new Error('category must be MAINTENANCE or PARKING'), { status: 400 });
  }

  if (Number.isNaN(billingMonth.getTime())) {
    throw Object.assign(new Error('billingMonth must be a valid date'), { status: 400 });
  }
  if (Number.isNaN(scheduledFor.getTime())) {
    throw Object.assign(new Error('scheduledFor must be a valid date+time'), { status: 400 });
  }
  if (Number.isNaN(dueDate.getTime())) {
    throw Object.assign(new Error('dueDate must be a valid date'), { status: 400 });
  }
  if (!defaultAmount || defaultAmount <= 0) {
    throw Object.assign(new Error('defaultAmount must be greater than zero'), { status: 400 });
  }

  return prisma.maintenanceBillSchedule.upsert({
    where: {
      societyId_billingMonth_category: {
        societyId,
        billingMonth,
        category,
      },
    },
    create: {
      societyId,
      billingMonth,
      category,
      scheduledFor,
      defaultAmount,
      dueDate,
      isActive: scheduleInput.isActive !== undefined ? Boolean(scheduleInput.isActive) : true,
      createdById: actorId || null,
    },
    update: {
      scheduledFor,
      defaultAmount,
      dueDate,
      isActive: scheduleInput.isActive !== undefined ? Boolean(scheduleInput.isActive) : true,
      // If admin updates schedule, allow it to run again for that month.
      executedAt: null,
    },
  });
}

async function listMaintenanceBillSchedules(societyId) {
  return prisma.maintenanceBillSchedule.findMany({
    where: { societyId },
    orderBy: [{ billingMonth: 'desc' }],
  });
}

async function runMaintenanceBillScheduleSweep() {
  const now = new Date();

  const dueSchedules = await prisma.maintenanceBillSchedule.findMany({
    where: {
      isActive: true,
      executedAt: null,
      scheduledFor: { lte: now },
    },
    orderBy: [{ scheduledFor: 'asc' }],
    take: 25,
  });

  let schedulesRun = 0;
  let billsCreated = 0;

  for (const schedule of dueSchedules) {
    try {
      // Claim the schedule (idempotent) so multiple servers don't double-run.
      const claim = await prisma.maintenanceBillSchedule.updateMany({
        where: { id: schedule.id, executedAt: null },
        data: { lastRunAt: now, executedAt: now },
      });

      if (claim.count === 0) continue;

      const cat = String(schedule.category || 'MAINTENANCE').toUpperCase();
      const result =
        cat === 'PARKING'
          ? await bulkGenerateParkingBills(
              schedule.societyId,
              schedule.billingMonth,
              Number(schedule.defaultAmount),
              schedule.dueDate,
              null,
            )
          : await bulkGenerateBills(
              schedule.societyId,
              schedule.billingMonth,
              Number(schedule.defaultAmount),
              schedule.dueDate,
              null,
            );

      schedulesRun += 1;
      billsCreated += result.count;
    } catch (error) {
      // If generation fails, unclaim so it can retry on next sweep.
      await prisma.maintenanceBillSchedule.updateMany({
        where: { id: schedule.id, executedAt: now },
        data: { executedAt: null },
      });
      console.error('[billing-schedules] schedule run failed:', error.message);
    }
  }

  return { schedulesRun, billsCreated };
}

module.exports = {
  listBills,
  bulkGenerateBills,
  bulkGenerateParkingBills,
  payAdvance,
  splitExpenseAmongUnits,
  undoSplitExpenseAmongUnits,
  recordPayment,
  getBill,
  listBillAuditLogs,
  listAllBillAuditLogs,
  softDeleteBill,
  getMyBills,
  getDefaulters,
  getResidentUnitIds,
  runOverdueReminderSweep,
  upsertMaintenanceBillSchedule,
  listMaintenanceBillSchedules,
  runMaintenanceBillScheduleSweep,
};
