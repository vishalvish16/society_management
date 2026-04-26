const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const crypto = require('crypto');
const notificationsService = require('../notifications/notifications.service');

function toLedgerAccountFromPaymentMethod(paymentMethod) {
  // Cash stays in CASH. Everything else is treated as BANK for reporting.
  // (BANK/UPI/ONLINE/RAZORPAY)
  return String(paymentMethod || '').toUpperCase() === 'CASH' ? 'CASH' : 'BANK';
}

function applyDelta(balances, account, delta) {
  if (account === 'CASH') balances.cash += delta;
  else balances.bank += delta;
  balances.total = balances.cash + balances.bank;
}

async function buildLedgerTimeline({ societyId, from, to }) {
  // Opening sources (< from)
  const [billsBefore, donationsBefore, expensesBefore, ledgerBefore] = await Promise.all([
    prisma.maintenanceBill.findMany({
      where: { societyId, status: 'PAID', deletedAt: null, paidAt: { lt: from } },
      select: { paidAmount: true, paymentMethod: true },
    }),
    prisma.donation.findMany({
      where: { societyId, paidAt: { lt: from } },
      select: { amount: true, paymentMethod: true },
    }),
    prisma.expense.findMany({
      where: { societyId, status: 'APPROVED', expenseDate: { lt: from } },
      select: { totalAmount: true, paymentMethod: true },
    }),
    prisma.ledgerEntry.findMany({
      where: { societyId, occurredAt: { lt: from } },
      select: { account: true, direction: true, amount: true },
    }),
  ]);

  const opening = { cash: 0, bank: 0, total: 0 };

  for (const b of billsBefore) {
    const acct = toLedgerAccountFromPaymentMethod(b.paymentMethod);
    applyDelta(opening, acct, Number(b.paidAmount));
  }
  for (const d of donationsBefore) {
    const acct = toLedgerAccountFromPaymentMethod(d.paymentMethod);
    applyDelta(opening, acct, Number(d.amount));
  }
  for (const e of expensesBefore) {
    const acct = toLedgerAccountFromPaymentMethod(e.paymentMethod); // null -> BANK
    applyDelta(opening, acct, -Number(e.totalAmount));
  }
  for (const le of ledgerBefore) {
    const delta = (le.direction === 'IN' ? 1 : -1) * Number(le.amount);
    applyDelta(opening, le.account, delta);
  }

  // Period txns (>= from && <= to)
  const [bills, donations, expenses, ledgerEntries] = await Promise.all([
    prisma.maintenanceBill.findMany({
      where: { societyId, status: 'PAID', deletedAt: null, paidAt: { gte: from, lte: to } },
      select: {
        id: true,
        paidAmount: true,
        paidAt: true,
        paymentMethod: true,
        category: true,
        title: true,
        unit: { select: { fullCode: true } },
      },
    }),
    prisma.donation.findMany({
      where: { societyId, paidAt: { gte: from, lte: to } },
      select: {
        id: true,
        amount: true,
        paidAt: true,
        paymentMethod: true,
        donor: { select: { name: true } },
        campaign: { select: { title: true } },
      },
    }),
    prisma.expense.findMany({
      where: { societyId, status: 'APPROVED', expenseDate: { gte: from, lte: to } },
      select: {
        id: true,
        totalAmount: true,
        expenseDate: true,
        category: true,
        title: true,
        paymentMethod: true,
      },
    }),
    prisma.ledgerEntry.findMany({
      where: { societyId, occurredAt: { gte: from, lte: to } },
      select: {
        id: true,
        account: true,
        direction: true,
        amount: true,
        occurredAt: true,
        description: true,
        transferGroupId: true,
      },
      orderBy: { occurredAt: 'asc' },
    }),
  ]);

  const txns = [];

  bills.forEach((b) => {
    const account = toLedgerAccountFromPaymentMethod(b.paymentMethod);
    const amount = Number(b.paidAmount);
    txns.push({
      id: b.id,
      date: b.paidAt,
      source: 'BILL',
      type: 'income',
      account,
      subType: b.category || 'MAINTENANCE',
      description: b.title || `Bill - ${b.unit?.fullCode}`,
      unit: b.unit?.fullCode || null,
      amount,
      paymentMethod: b.paymentMethod,
      deltaCash: account === 'CASH' ? amount : 0,
      deltaBank: account === 'BANK' ? amount : 0,
    });
  });

  donations.forEach((d) => {
    const account = toLedgerAccountFromPaymentMethod(d.paymentMethod);
    const amount = Number(d.amount);
    txns.push({
      id: d.id,
      date: d.paidAt,
      source: 'DONATION',
      type: 'income',
      account,
      subType: 'DONATION',
      description: d.campaign?.title ? `Donation: ${d.campaign.title}` : 'Donation',
      unit: d.donor?.name || null,
      amount,
      paymentMethod: d.paymentMethod,
      deltaCash: account === 'CASH' ? amount : 0,
      deltaBank: account === 'BANK' ? amount : 0,
    });
  });

  expenses.forEach((e) => {
    const account = toLedgerAccountFromPaymentMethod(e.paymentMethod); // null -> BANK
    const amount = Number(e.totalAmount);
    txns.push({
      id: e.id,
      date: e.expenseDate,
      source: 'EXPENSE',
      type: 'expense',
      account,
      subType: e.category,
      description: e.title,
      unit: null,
      amount,
      paymentMethod: e.paymentMethod,
      deltaCash: account === 'CASH' ? -amount : 0,
      deltaBank: account === 'BANK' ? -amount : 0,
    });
  });

  ledgerEntries.forEach((le) => {
    // Transfers are stored as 2 rows (OUT + IN). We'll group them into 1 row for reports.
    // Non-transfer entries remain 1 row.
    if (!le.transferGroupId) {
      const amount = Number(le.amount);
      const delta = (le.direction === 'IN' ? 1 : -1) * amount;
      txns.push({
        id: le.id,
        date: le.occurredAt,
        source: 'LEDGER',
        type: le.direction === 'IN' ? 'income' : 'expense',
        account: le.account,
        subType: 'MANUAL',
        description: le.description || null,
        unit: null,
        amount,
        paymentMethod: le.account,
        transferGroupId: null,
        deltaCash: le.account === 'CASH' ? delta : 0,
        deltaBank: le.account === 'BANK' ? delta : 0,
      });
      return;
    }

    // transfer: collect for grouping
    if (!buildLedgerTimeline._transferMap) buildLedgerTimeline._transferMap = new Map();
    const map = buildLedgerTimeline._transferMap;
    const key = le.transferGroupId;
    const current = map.get(key) || { entries: [], occurredAt: le.occurredAt, description: le.description || null };
    current.entries.push(le);
    // keep earliest timestamp just in case
    if (new Date(le.occurredAt) < new Date(current.occurredAt)) current.occurredAt = le.occurredAt;
    // prefer non-empty description if any side has it
    if (!current.description && le.description) current.description = le.description;
    map.set(key, current);
  });

  // Flush grouped transfers into a single txn each.
  if (buildLedgerTimeline._transferMap) {
    for (const [transferGroupId, group] of buildLedgerTimeline._transferMap.entries()) {
      const cash = group.entries.find((e) => e.account === 'CASH');
      const bank = group.entries.find((e) => e.account === 'BANK');
      const amount = Number((cash || bank)?.amount || 0);

      const deltaCash = cash ? (cash.direction === 'IN' ? amount : -amount) : 0;
      const deltaBank = bank ? (bank.direction === 'IN' ? amount : -amount) : 0;

      const isDeposit = deltaCash < 0 && deltaBank > 0;
      const isWithdraw = deltaBank < 0 && deltaCash > 0;

      const defaultLabel = isDeposit
          ? 'Deposit Cash → Bank'
          : isWithdraw
              ? 'Withdraw Bank → Cash'
              : 'Transfer';

      txns.push({
        id: transferGroupId,
        date: group.occurredAt,
        source: 'LEDGER',
        type: 'transfer',
        account: null,
        subType: 'TRANSFER',
        description: group.description || defaultLabel,
        unit: null,
        amount,
        paymentMethod: 'TRANSFER',
        transferGroupId,
        deltaCash,
        deltaBank,
      });
    }
    buildLedgerTimeline._transferMap = null;
  }

  // Sort by date ascending for running balances.
  txns.sort((a, b) => new Date(a.date) - new Date(b.date));

  return { opening, txns };
}

// GET /api/reports/financial
// Query: fromDate, toDate, type (income|expense|donation|all), page, limit
exports.getFinancialReport = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { fromDate, toDate, type = 'all', page = 1, limit = 50 } = req.query;

    const from = fromDate ? new Date(fromDate) : new Date(new Date().getFullYear(), 0, 1);
    const to = toDate ? new Date(toDate) : new Date();
    to.setHours(23, 59, 59, 999);

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = parseInt(limit);

    const results = [];

    if (type === 'all' || type === 'income') {
      const bills = await prisma.maintenanceBill.findMany({
        where: {
          societyId,
          status: 'PAID',
          deletedAt: null,
          paidAt: { gte: from, lte: to },
        },
        select: {
          id: true, paidAmount: true, paidAt: true, paymentMethod: true,
          category: true, title: true,
          unit: { select: { fullCode: true } },
        },
        orderBy: { paidAt: 'desc' },
      });
      bills.forEach(b => results.push({
        id: b.id,
        date: b.paidAt,
        type: 'income',
        subType: b.category || 'MAINTENANCE',
        description: b.title || `Bill - ${b.unit?.fullCode}`,
        unit: b.unit?.fullCode,
        amount: Number(b.paidAmount),
        paymentMethod: b.paymentMethod,
      }));
    }

    if (type === 'all' || type === 'donation') {
      const donations = await prisma.donation.findMany({
        where: { societyId, paidAt: { gte: from, lte: to } },
        select: {
          id: true, amount: true, paidAt: true, paymentMethod: true, note: true,
          donor: { select: { name: true } },
          campaign: { select: { title: true } },
        },
        orderBy: { paidAt: 'desc' },
      });
      donations.forEach(d => results.push({
        id: d.id,
        date: d.paidAt,
        type: 'income',
        subType: 'DONATION',
        description: d.campaign?.title ? `Donation: ${d.campaign.title}` : 'Donation',
        unit: d.donor?.name,
        amount: Number(d.amount),
        paymentMethod: d.paymentMethod,
      }));
    }

    if (type === 'all' || type === 'expense') {
      const expenses = await prisma.expense.findMany({
        where: {
          societyId,
          status: 'APPROVED',
          expenseDate: { gte: from, lte: to },
        },
        select: {
          id: true, totalAmount: true, expenseDate: true, category: true, title: true,
        },
        orderBy: { expenseDate: 'desc' },
      });
      expenses.forEach(e => results.push({
        id: e.id,
        date: e.expenseDate,
        type: 'expense',
        subType: e.category,
        description: e.title,
        unit: null,
        amount: Number(e.totalAmount),
        paymentMethod: null,
      }));
    }

    // Sort all combined results by date desc
    results.sort((a, b) => new Date(b.date) - new Date(a.date));

    const total = results.length;
    const paginated = results.slice(skip, skip + take);

    // Monthly summary
    const monthlyMap = {};
    results.forEach(r => {
      const d = new Date(r.date);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      if (!monthlyMap[key]) monthlyMap[key] = { month: key, income: 0, expense: 0 };
      if (r.type === 'income') monthlyMap[key].income += r.amount;
      else monthlyMap[key].expense += r.amount;
    });
    const monthly = Object.values(monthlyMap)
      .map(m => ({ ...m, balance: m.income - m.expense }))
      .sort((a, b) => a.month.localeCompare(b.month));

    const totalIncome = results.filter(r => r.type === 'income').reduce((s, r) => s + r.amount, 0);
    const totalExpense = results.filter(r => r.type === 'expense').reduce((s, r) => s + r.amount, 0);

    return sendSuccess(res, {
      transactions: paginated,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      summary: { totalIncome, totalExpense, netBalance: totalIncome - totalExpense },
      monthly,
    });
  } catch (e) {
    console.error('Financial report error:', e);
    return sendError(res, 'Failed to load financial report', 500);
  }
};

// GET /api/reports/balance
// Query: fromDate, toDate
// Returns opening balance (all transactions before fromDate), then date-wise
// transactions within range, running balance, and closing balance.
exports.getBalanceReport = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { fromDate, toDate } = req.query;

    const from = fromDate ? new Date(fromDate) : new Date(new Date().getFullYear(), 0, 1);
    const to = toDate ? new Date(toDate) : new Date();
    to.setHours(23, 59, 59, 999);
    from.setHours(0, 0, 0, 0);

    const { opening, txns } = await buildLedgerTimeline({ societyId, from, to });

    // Backwards-compatible: total opening balance + classic income/expense running balance.
    const openingBalance = opening.total;
    let running = openingBalance;
    const transactions = txns.map((t) => {
      const delta = (t.deltaCash || 0) + (t.deltaBank || 0);
      running += delta;
      return { ...t, runningBalance: running };
    });

    const periodIncome = txns.filter(t => (t.deltaCash + t.deltaBank) > 0).reduce((s, t) => s + (t.deltaCash + t.deltaBank), 0);
    const periodExpense = txns.filter(t => (t.deltaCash + t.deltaBank) < 0).reduce((s, t) => s + Math.abs(t.deltaCash + t.deltaBank), 0);
    const closing = { ...opening };
    for (const t of txns) {
      applyDelta(closing, 'CASH', t.deltaCash || 0);
      applyDelta(closing, 'BANK', t.deltaBank || 0);
    }

    return sendSuccess(res, {
      openingBalance,
      opening: opening,
      transactions,
      summary: {
        periodIncome,
        periodExpense,
        netChange: periodIncome - periodExpense,
        closingBalance: closing.total,
        closing,
      },
    });
  } catch (e) {
    console.error('Balance report error:', e);
    return sendError(res, 'Failed to load balance report', 500);
  }
};

// GET /api/reports/ledger
// Query: fromDate, toDate
// Returns running cash/bank/total balances in one report.
exports.getLedgerReport = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { fromDate, toDate } = req.query;

    const from = fromDate ? new Date(fromDate) : new Date(new Date().getFullYear(), 0, 1);
    const to = toDate ? new Date(toDate) : new Date();
    to.setHours(23, 59, 59, 999);
    from.setHours(0, 0, 0, 0);

    const { opening, txns } = await buildLedgerTimeline({ societyId, from, to });

    const balances = { ...opening };
    const transactions = txns.map((t) => {
      applyDelta(balances, 'CASH', t.deltaCash || 0);
      applyDelta(balances, 'BANK', t.deltaBank || 0);
      return {
        ...t,
        balanceCash: balances.cash,
        balanceBank: balances.bank,
        balanceTotal: balances.total,
      };
    });

    return sendSuccess(res, {
      opening,
      transactions,
      closing: { cash: balances.cash, bank: balances.bank, total: balances.total },
    });
  } catch (e) {
    console.error('Ledger report error:', e);
    return sendError(res, 'Failed to load ledger report', 500);
  }
};

// POST /api/reports/ledger/entry
// Body: { account: CASH|BANK, direction: IN|OUT, amount, occurredAt?, description? }
exports.createLedgerEntry = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { account, direction, amount, occurredAt, description } = req.body;

    const acct = String(account || '').toUpperCase();
    const dir = String(direction || '').toUpperCase();
    const amt = Number(amount);

    if (!['CASH', 'BANK'].includes(acct)) return sendError(res, 'account must be CASH or BANK', 400);
    if (!['IN', 'OUT'].includes(dir)) return sendError(res, 'direction must be IN or OUT', 400);
    if (!Number.isFinite(amt) || amt <= 0) return sendError(res, 'amount must be a number > 0', 400);

    const entry = await prisma.ledgerEntry.create({
      data: {
        societyId,
        account: acct,
        direction: dir,
        amount: amt,
        occurredAt: occurredAt ? new Date(occurredAt) : new Date(),
        description: description ? String(description) : null,
        createdById: req.user.id,
      },
    });

    return sendSuccess(res, entry, 'Ledger entry created', 201);
  } catch (e) {
    console.error('Create ledger entry error:', e);
    return sendError(res, e.message || 'Failed to create ledger entry', 500);
  }
};

// POST /api/reports/ledger/transfer
// Body: { fromAccount: CASH|BANK, toAccount: CASH|BANK, amount, occurredAt?, description? }
exports.createLedgerTransfer = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { fromAccount, toAccount, amount, occurredAt, description } = req.body;

    const from = String(fromAccount || '').toUpperCase();
    const to = String(toAccount || '').toUpperCase();
    const amt = Number(amount);

    if (!['CASH', 'BANK'].includes(from)) return sendError(res, 'fromAccount must be CASH or BANK', 400);
    if (!['CASH', 'BANK'].includes(to)) return sendError(res, 'toAccount must be CASH or BANK', 400);
    if (from === to) return sendError(res, 'fromAccount and toAccount must be different', 400);
    if (!Number.isFinite(amt) || amt <= 0) return sendError(res, 'amount must be a number > 0', 400);

    const when = occurredAt ? new Date(occurredAt) : new Date();
    const transferGroupId = crypto.randomUUID();

    const [outEntry, inEntry] = await prisma.$transaction([
      prisma.ledgerEntry.create({
        data: {
          societyId,
          account: from,
          direction: 'OUT',
          amount: amt,
          occurredAt: when,
          description: description ? String(description) : null,
          transferGroupId,
          createdById: req.user.id,
        },
      }),
      prisma.ledgerEntry.create({
        data: {
          societyId,
          account: to,
          direction: 'IN',
          amount: amt,
          occurredAt: when,
          description: description ? String(description) : null,
          transferGroupId,
          createdById: req.user.id,
        },
      }),
    ]);

    return sendSuccess(res, { transferGroupId, outEntry, inEntry }, 'Transfer recorded', 201);
  } catch (e) {
    console.error('Create transfer error:', e);
    return sendError(res, e.message || 'Failed to create transfer', 500);
  }
};

// ── Dues Report ──────────────────────────────────────────────────────────────
// GET /api/reports/dues
// Returns all PENDING/PARTIAL/OVERDUE bills grouped by unit with member info.
exports.getDuesReport = async (req, res) => {
  try {
    const { societyId, id: userId, role } = req.user;
    const { billingMonth, status } = req.query;

    const adminRoles = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'SUPER_ADMIN'];
    const isAdmin = adminRoles.includes(role);

    const where = {
      societyId,
      deletedAt: null,
      status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] },
    };

    // Non-admin users only see their own unit's bills
    if (!isAdmin) {
      const unitResidents = await prisma.unitResident.findMany({
        where: { userId },
        select: { unitId: true },
      });
      const unitIds = unitResidents.map((r) => r.unitId);
      if (unitIds.length === 0) {
        return sendSuccess(res, { dues: [], summary: { totalBills: 0, totalDueAmount: 0, totalPaidAmount: 0, statusCounts: {} } }, 'No dues found');
      }
      where.unitId = { in: unitIds };
    }

    if (status) where.status = String(status).toUpperCase();
    if (billingMonth) {
      const m = new Date(billingMonth);
      const start = new Date(m.getFullYear(), m.getMonth(), 1);
      const end = new Date(m.getFullYear(), m.getMonth() + 1, 0, 23, 59, 59, 999);
      where.billingMonth = { gte: start, lte: end };
    }

    const bills = await prisma.maintenanceBill.findMany({
      where,
      include: {
        unit: {
          select: {
            id: true,
            fullCode: true,
            wing: true,
            unitNumber: true,
            residents: {
              where: { user: { deletedAt: null, isActive: true } },
              select: {
                user: { select: { id: true, name: true, phone: true, email: true, fcmToken: true } },
                isOwner: true,
              },
            },
          },
        },
      },
      orderBy: [{ dueDate: 'asc' }, { unit: { fullCode: 'asc' } }],
    });

    // Compute summary
    let totalDueAmount = 0;
    let totalPaidAmount = 0;
    const statusCounts = { PENDING: 0, PARTIAL: 0, OVERDUE: 0 };

    const duesData = bills.map((b) => {
      const due = Number(b.totalDue);
      const paid = Number(b.paidAmount);
      const remaining = due - paid;
      totalDueAmount += remaining;
      totalPaidAmount += paid;
      statusCounts[b.status] = (statusCounts[b.status] || 0) + 1;

      const residents = (b.unit?.residents ?? []).map((r) => ({
        ...r.user,
        isOwner: r.isOwner,
        fcmToken: undefined,
      }));

      return {
        billId: b.id,
        unitId: b.unit?.id,
        unitCode: b.unit?.fullCode,
        wing: b.unit?.wing,
        billingMonth: b.billingMonth,
        dueDate: b.dueDate,
        amount: due,
        paidAmount: paid,
        remaining,
        status: b.status,
        category: b.category,
        title: b.title,
        residents,
      };
    });

    return sendSuccess(res, {
      dues: duesData,
      summary: {
        totalBills: bills.length,
        totalDueAmount,
        totalPaidAmount,
        statusCounts,
      },
    }, 'Dues report retrieved');
  } catch (e) {
    console.error('Dues report error:', e);
    return sendError(res, 'Failed to load dues report', 500);
  }
};

// POST /api/reports/dues/remind
// Send payment reminder notification to specific members or a whole unit.
// Body: { billId, userId? }
exports.sendDueReminder = async (req, res) => {
  try {
    const { societyId, id: senderId } = req.user;
    const { billId, userId } = req.body;

    if (!billId) return sendError(res, 'billId is required', 400);

    const bill = await prisma.maintenanceBill.findUnique({
      where: { id: billId },
      include: {
        unit: {
          select: {
            id: true,
            fullCode: true,
            residents: {
              where: { user: { deletedAt: null, isActive: true } },
              select: { user: { select: { id: true, name: true } } },
            },
          },
        },
      },
    });
    if (!bill || bill.societyId !== societyId) return sendError(res, 'Bill not found', 404);
    if (bill.status === 'PAID') return sendError(res, 'Bill is already paid', 400);

    const remaining = Number(bill.totalDue) - Number(bill.paidAmount);
    const monthLabel = new Date(bill.billingMonth).toLocaleDateString('en-IN', { month: 'short', year: 'numeric' });
    const title = 'Payment Reminder';
    const body = `Your ${bill.title || 'maintenance'} bill for ${monthLabel} (Unit ${bill.unit?.fullCode}) has Rs. ${Math.round(remaining)} pending. Please pay at the earliest.`;

    if (userId) {
      await notificationsService.sendNotification(senderId, societyId, {
        targetType: 'user',
        targetId: userId,
        title,
        body,
        type: 'BILL',
        route: '/bills',
      });
    } else {
      await notificationsService.sendNotification(senderId, societyId, {
        targetType: 'unit',
        targetId: bill.unit?.id,
        title,
        body,
        type: 'BILL',
        route: '/bills',
      });
    }

    // Update last reminder timestamp
    await prisma.maintenanceBill.update({
      where: { id: billId },
      data: { lastReminderAt: new Date() },
    });

    return sendSuccess(res, null, 'Reminder sent successfully');
  } catch (e) {
    console.error('Send reminder error:', e);
    return sendError(res, e.message || 'Failed to send reminder', 500);
  }
};

// POST /api/reports/dues/remind-all
// Send payment reminders to ALL units with pending dues.
exports.sendBulkDueReminder = async (req, res) => {
  try {
    const { societyId, id: senderId } = req.user;

    const bills = await prisma.maintenanceBill.findMany({
      where: {
        societyId,
        deletedAt: null,
        status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] },
      },
      include: {
        unit: { select: { id: true, fullCode: true } },
      },
    });

    if (bills.length === 0) return sendSuccess(res, { sent: 0 }, 'No pending dues found');

    // Group by unit to send one notification per unit
    const unitMap = new Map();
    for (const b of bills) {
      if (!b.unit) continue;
      if (!unitMap.has(b.unit.id)) {
        unitMap.set(b.unit.id, { unitCode: b.unit.fullCode, unitId: b.unit.id, total: 0, count: 0 });
      }
      const entry = unitMap.get(b.unit.id);
      entry.total += Number(b.totalDue) - Number(b.paidAmount);
      entry.count += 1;
    }

    let sent = 0;
    for (const [, unit] of unitMap) {
      await notificationsService.sendNotification(senderId, societyId, {
        targetType: 'unit',
        targetId: unit.unitId,
        title: 'Payment Reminder',
        body: `Unit ${unit.unitCode}: You have ${unit.count} pending bill(s) totalling Rs. ${Math.round(unit.total)}. Please pay at the earliest.`,
        type: 'BILL',
        route: '/bills',
      });
      sent++;
    }

    // Update lastReminderAt for all bills
    await prisma.maintenanceBill.updateMany({
      where: { id: { in: bills.map((b) => b.id) } },
      data: { lastReminderAt: new Date() },
    });

    return sendSuccess(res, { sent }, `Reminders sent to ${sent} units`);
  } catch (e) {
    console.error('Bulk reminder error:', e);
    return sendError(res, e.message || 'Failed to send reminders', 500);
  }
};
