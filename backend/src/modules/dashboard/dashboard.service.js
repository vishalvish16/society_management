const prisma = require('../../config/db');

/**
 * Get core stats for the society dashboard.
 * @param {string} societyId
 */
async function getAdminStats(societyId) {
  // Parallel execution for performance
  const [
    userCount,
    occupiedUnits,
    totalUnits,
    pendingPaymentsCount,
    totalRevenueResults,
    unapprovedExpensesCount
  ] = await Promise.all([
    prisma.user.count({ where: { societyId, deletedAt: null } }),
    prisma.unit.count({ where: { societyId, status: 'OCCUPIED', deletedAt: null } }),
    prisma.unit.count({ where: { societyId, deletedAt: null } }),
    prisma.maintenanceBill.count({ where: { societyId, status: { in: ['PENDING', 'PARTIAL'] } } }),
    prisma.maintenanceBill.aggregate({
      where: { societyId, status: 'PAID' },
      _sum: { paidAmount: true }
    }),
    prisma.expense.count({ where: { societyId, status: 'PENDING' } })
  ]);

  return {
    users: userCount,
    units: {
      total: totalUnits,
      occupied: occupiedUnits,
      vacant: totalUnits - occupiedUnits
    },
    billing: {
      pendingBills: pendingPaymentsCount,
      totalRevenue: Number(totalRevenueResults._sum.paidAmount || 0)
    },
    expenses: {
      pendingApprovals: unapprovedExpensesCount
    }
  };
}

/**
 * Get monthly revenue and expense trends for the last 6 months.
 */
async function getTrends(societyId) {
  const sixMonthsAgo = new Date();
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 5);
  sixMonthsAgo.setDate(1);
  sixMonthsAgo.setHours(0, 0, 0, 0);

  const [incomeTrends, expenseTrends] = await Promise.all([
    // Income trends (based on billingMonth)
    prisma.maintenanceBill.groupBy({
      by: ['billingMonth'],
      where: { societyId, billingMonth: { gte: sixMonthsAgo } },
      _sum: { paidAmount: true }
    }),
    // Expense trends (based on expenseDate)
    prisma.expense.groupBy({
      by: ['expenseDate'],
      where: { societyId, status: 'APPROVED', expenseDate: { gte: sixMonthsAgo } },
      _sum: { amount: true }
    })
  ]);

  // Transform data into a graph-friendly format (mapping by month)
  return { incomeTrends, expenseTrends };
}

/**
 * Get society settings.
 */
async function getSocietySettings(societyId) {
  return prisma.society.findUnique({
    where: { id: societyId },
    select: { id: true, name: true, address: true, logoUrl: true, settings: true }
  });
}

/**
 * Update society settings.
 */
async function updateSocietySettings(societyId, data) {
  return prisma.society.update({
    where: { id: societyId },
    data: {
      name: data.name,
      address: data.address,
      logoUrl: data.logoUrl,
      settings: data.settings ? { ...data.settings } : undefined
    }
  });
}

module.exports = {
  getAdminStats,
  getTrends,
  getSocietySettings,
  updateSocietySettings
};
