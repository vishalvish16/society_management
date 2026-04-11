const prisma = require('../../config/db');

/**
 * Get platform-wide dashboard stats for Super Admin.
 * Uses actual schema: Society has planId/status/planRenewalDate, no Subscription model.
 */
async function getDashboardStats() {
  const now = new Date();

  const [
    totalSocieties,
    activeSocieties,
    suspendedSocieties,
    totalUsers,
    totalUnits,
    totalPlans,
    recentPayments,
  ] = await Promise.all([
    prisma.society.count(),
    prisma.society.count({ where: { status: 'active' } }),
    prisma.society.count({ where: { status: 'suspended' } }),
    prisma.user.count({ where: { deletedAt: null, isActive: true } }),
    prisma.unit.count(),
    prisma.plan.count({ where: { isActive: true } }),
    // MRR approximation: sum of this month's subscription payments
    prisma.subscriptionPayment.findMany({
      where: { createdAt: { gte: new Date(now.getFullYear(), now.getMonth(), 1) } },
      select: { amount: true },
    }),
  ]);

  // MRR = sum of this month's paid subscription payments
  let mrr = 0;
  for (const p of recentPayments) {
    mrr += parseFloat(p.amount);
  }
  mrr = Math.round(mrr * 100) / 100;

  // Plan distribution: count societies per plan
  const planDist = await prisma.society.groupBy({
    by: ['planId'],
    where: { status: 'active' },
    _count: { id: true },
  });

  let distribution = [];
  if (planDist.length > 0) {
    const planIds = planDist.map((d) => d.planId);
    const plans = await prisma.plan.findMany({
      where: { id: { in: planIds } },
      select: { id: true, name: true, displayName: true },
    });
    const planMap = Object.fromEntries(plans.map((p) => [p.id, p]));
    distribution = planDist.map((d) => ({
      planId: d.planId,
      planName: planMap[d.planId]?.displayName || planMap[d.planId]?.name || 'Unknown',
      planCode: planMap[d.planId]?.name || 'UNKNOWN',
      count: d._count.id,
    }));
  }

  // Societies expiring soon (renewal within 30 days)
  const thirtyDaysLater = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const expiringSoon = await prisma.society.count({
    where: {
      status: 'active',
      planRenewalDate: { lte: thirtyDaysLater, gte: now },
    },
  });

  return {
    totalSocieties,
    activeSocieties,
    suspendedSocieties,
    totalUsers,
    totalUnits,
    totalPlans,
    // Keep these for Flutter DashboardStats model compatibility
    activeSubscriptions: activeSocieties,
    trialSubscriptions: 0,
    expiredSubscriptions: suspendedSocieties,
    expiringSoon,
    mrr,
    arr: Math.round(mrr * 12 * 100) / 100,
    planDistribution: distribution,
  };
}

/**
 * Get revenue trends (using SubscriptionPayment model).
 */
async function getRevenueTrends(period = '6m') {
  let monthsBack;
  if (period === '1y') monthsBack = 12;
  else if (period === 'all') monthsBack = 36;
  else monthsBack = 6;

  const since = new Date();
  since.setMonth(since.getMonth() - monthsBack);
  since.setDate(1);
  since.setHours(0, 0, 0, 0);

  const payments = await prisma.subscriptionPayment.findMany({
    where: { createdAt: { gte: since } },
    select: { createdAt: true, amount: true },
    orderBy: { createdAt: 'asc' },
  });

  const societies = await prisma.society.findMany({
    where: { createdAt: { gte: since } },
    select: { createdAt: true },
  });

  const months = {};
  const now = new Date();
  const cursor = new Date(since);
  while (cursor <= now) {
    const key = `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`;
    months[key] = { month: key, revenue: 0, newSocieties: 0 };
    cursor.setMonth(cursor.getMonth() + 1);
  }

  for (const p of payments) {
    const key = `${p.createdAt.getFullYear()}-${String(p.createdAt.getMonth() + 1).padStart(2, '0')}`;
    if (months[key]) months[key].revenue += parseFloat(p.amount);
  }

  for (const s of societies) {
    const key = `${s.createdAt.getFullYear()}-${String(s.createdAt.getMonth() + 1).padStart(2, '0')}`;
    if (months[key]) months[key].newSocieties += 1;
  }

  return Object.values(months).map((m) => ({
    ...m,
    revenue: Math.round(m.revenue * 100) / 100,
  }));
}

/**
 * Get last 10 recently created societies with plan + stats.
 */
async function getRecentSocieties() {
  return prisma.society.findMany({
    orderBy: { createdAt: 'desc' },
    take: 10,
    select: {
      id: true,
      name: true,
      status: true,
      createdAt: true,
      contactPhone: true,
      contactEmail: true,
      planRenewalDate: true,
      plan: { select: { name: true, displayName: true } },
      _count: { select: { users: true, units: true } },
    },
  });
}

module.exports = { getDashboardStats, getRevenueTrends, getRecentSocieties };
