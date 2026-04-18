const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

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
