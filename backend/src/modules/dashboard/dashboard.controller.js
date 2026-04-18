const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// ─── GET /api/dashboard/stats ─────────────────────────────────────────────
// Role-aware: SUPER_ADMIN gets platform stats, CHAIRMAN/SECRETARY get society stats,
// RESIDENT gets personal stats, WATCHMAN gets today's gate activity
exports.getStats = async (req, res) => {
  try {
    const { societyId, role, id: userId } = req.user;

    // ── SUPER_ADMIN ──────────────────────────────────────────────────────
    if (role === 'SUPER_ADMIN') {
      const now = new Date();
      const [societies, activeSocieties, users, totalUnits, mrr] = await Promise.all([
        prisma.society.count(),
        prisma.society.count({ where: { status: 'ACTIVE' } }),
        prisma.user.count({ where: { isActive: true, deletedAt: null } }),
        prisma.unit.count(),
        prisma.subscriptionPayment.aggregate({
          where: { createdAt: { gte: new Date(now.getFullYear(), now.getMonth(), 1) } },
          _sum: { amount: true },
        }),
      ]);
      return sendSuccess(res, {
        societiesCount: societies,
        activeSocieties,
        usersCount: users,
        totalUnits,
        mrr: Number(mrr._sum.amount || 0),
      });
    }

    if (!societyId) return sendError(res, 'No society assigned', 400);

    // ── Society Roles (Chairman/Secretary/Committee) ─────────────────────
    const societyAdminRoles = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'MEMBER'];
    if (societyAdminRoles.includes(role)) {
      const now = new Date();

      const [
        totalUnits, occupiedUnits,
        pendingBills,
        totalBillIncome, totalDonations, totalExpenses,
        pendingExpenses,
        openComplaints,
        todayVisitors,
        pendingDeliveries,
        activeCampaigns,
      ] = await Promise.all([
        prisma.unit.count({ where: { societyId, deletedAt: null } }),
        prisma.unit.count({ where: { societyId, status: 'OCCUPIED', deletedAt: null } }),
        prisma.maintenanceBill.count({ where: { societyId, status: { in: ['PENDING', 'PARTIAL'] } } }),
        prisma.maintenanceBill.aggregate({
          where: { societyId, status: 'PAID', deletedAt: null },
          _sum: { paidAmount: true },
        }),
        prisma.donation.aggregate({
          where: { societyId },
          _sum: { amount: true },
        }),
        prisma.expense.aggregate({
          where: { societyId, status: 'APPROVED' },
          _sum: { totalAmount: true },
        }),
        prisma.expense.count({ where: { societyId, status: 'PENDING' } }),
        prisma.complaint.count({ where: { societyId, status: { in: ['OPEN', 'ASSIGNED', 'IN_PROGRESS'] } } }),
        prisma.visitor.count({
          where: {
            societyId,
            status: 'VALID',
            createdAt: {
              gte: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
            },
          },
        }),
        prisma.delivery.count({ where: { societyId, status: 'PENDING' } }),
        prisma.donationCampaign.findMany({
          where: {
            societyId,
            isActive: true,
            OR: [{ endDate: null }, { endDate: { gte: now } }],
          },
          include: {
            donations: {
              where: { donorId: userId },
              select: { id: true, amount: true },
            },
          },
        }),
      ]);

      const societyIncome = Number(totalBillIncome._sum.paidAmount || 0) + Number(totalDonations._sum.amount || 0);
      const societyExpense = Number(totalExpenses._sum.totalAmount || 0);

      return sendSuccess(res, {
        units: { total: totalUnits, occupied: occupiedUnits, vacant: totalUnits - occupiedUnits },
        billing: {
          pendingCount: pendingBills,
          societyBalance: societyIncome - societyExpense,
          totalIncome: societyIncome,
          totalExpense: societyExpense,
        },
        expenses: { pendingApproval: pendingExpenses },
        complaints: { open: openComplaints },
        visitors: { today: todayVisitors },
        deliveries: { pending: pendingDeliveries },
        activeCampaigns: activeCampaigns
          .filter(c => c.donations.length === 0)
          .map(c => ({
            ...c,
            hasPaid: false,
          })),
      });
    }

    // ── RESIDENT ─────────────────────────────────────────────────────────
    if (role === 'RESIDENT') {
      const myUnit = await prisma.unitResident.findFirst({
        where: { userId },
        select: {
          isOwner: true,
          unit: {
            select: {
              id: true, fullCode: true,
              bills: {
                where: { status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] } },
                select: { id: true, totalDue: true, paidAmount: true, billingMonth: true, dueDate: true, status: true },
                orderBy: { billingMonth: 'desc' },
                take: 3,
              },
            },
          },
        },
      });

      const [myComplaints, myVisitors, myDeliveries, activeCampaigns] = await Promise.all([
        prisma.complaint.count({ where: { raisedById: userId, societyId, status: { not: 'CLOSED' } } }),
        prisma.visitor.count({ where: { societyId, invitedById: userId, status: 'PENDING' } }),
        prisma.delivery.count({ where: { societyId, unitId: myUnit?.unit?.id, status: 'PENDING' } }),
        prisma.donationCampaign.findMany({
          where: {
            societyId,
            isActive: true,
            OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
          },
          include: {
            donations: {
              where: { donorId: userId },
              select: { id: true, amount: true },
            },
          },
        }),
      ]);

      const outstanding = myUnit?.unit?.bills?.reduce(
        (sum, b) => sum + (Number(b.totalDue) - Number(b.paidAmount)), 0
      ) || 0;

      return sendSuccess(res, {
        unit: myUnit?.unit ? { id: myUnit.unit.id, fullCode: myUnit.unit.fullCode, isOwner: myUnit.isOwner } : null,
        outstandingBalance: outstanding,
        pendingBills: myUnit?.unit?.bills || [],
        activeComplaints: myComplaints,
        pendingVisitors: myVisitors,
        pendingDeliveries: myDeliveries,
        activeCampaigns: activeCampaigns
          .filter((c) => c.donations.length === 0)
          .map((c) => ({
            id: c.id,
            title: c.title,
            description: c.description,
            targetAmount: c.targetAmount,
            endDate: c.endDate,
          })),
      });
    }

    // ── WATCHMAN ─────────────────────────────────────────────────────────
    if (role === 'WATCHMAN') {
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

      const [todayVisitors, pendingDeliveries, activeGatePasses] = await Promise.all([
        prisma.visitorLog.count({ where: { visitor: { societyId }, scannedAt: { gte: startOfDay } } }),
        prisma.delivery.count({ where: { societyId, status: 'PENDING' } }),
        prisma.gatePass.count({ where: { societyId, status: 'ACTIVE' } }),
      ]);

      return sendSuccess(res, {
        todayVisitorScans: todayVisitors,
        pendingDeliveries,
        activeGatePasses,
      });
    }

    return sendError(res, 'Unknown role', 400);
  } catch (err) {
    console.error('Dashboard stats error:', err.message);
    return sendError(res, 'Failed to load dashboard stats', 500);
  }
};

// ─── GET /api/dashboard/trends ────────────────────────────────────────────
exports.getTrends = async (req, res) => {
  try {
    const { societyId, role } = req.user;
    if (!societyId) return sendError(res, 'No society assigned', 400);

    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 5);
    sixMonthsAgo.setDate(1);
    sixMonthsAgo.setHours(0, 0, 0, 0);

    const [incomeTrends, expenseTrends] = await Promise.all([
      prisma.maintenanceBill.groupBy({
        by: ['billingMonth'],
        where: { societyId, billingMonth: { gte: sixMonthsAgo } },
        _sum: { paidAmount: true },
      }),
      prisma.expense.groupBy({
        by: ['expenseDate'],
        where: { societyId, status: 'APPROVED', expenseDate: { gte: sixMonthsAgo } },
        _sum: { amount: true },
      }),
    ]);

    return sendSuccess(res, { incomeTrends, expenseTrends });
  } catch (err) {
    return sendError(res, 'Failed to load trends', 500);
  }
};

// ─── GET /api/dashboard/settings ──────────────────────────────────────────
exports.getSettings = async (req, res) => {
  try {
    const { societyId } = req.user;
    if (!societyId) return sendError(res, 'No society assigned', 400);

    const society = await prisma.society.findUnique({
      where: { id: societyId },
      select: { id: true, name: true, address: true, city: true, logoUrl: true,
                contactEmail: true, contactPhone: true, settings: true,
                plan: { select: { name: true, displayName: true, features: true } } },
    });
    if (!society) return sendError(res, 'Society not found', 404);
    return sendSuccess(res, society);
  } catch (err) {
    return sendError(res, 'Failed to load settings', 500);
  }
};

// ─── PATCH /api/dashboard/settings ────────────────────────────────────────
exports.updateSettings = async (req, res) => {
  try {
    const { societyId } = req.user;
    if (!societyId) return sendError(res, 'No society assigned', 400);

    const { name, address, city, contactEmail, contactPhone, logoUrl, settings } = req.body;
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (address !== undefined) updateData.address = address;
    if (city !== undefined) updateData.city = city;
    if (contactEmail !== undefined) updateData.contactEmail = contactEmail;
    if (contactPhone !== undefined) updateData.contactPhone = contactPhone;
    if (logoUrl !== undefined) updateData.logoUrl = logoUrl;
    if (settings !== undefined) updateData.settings = settings;

    const updated = await prisma.society.update({ where: { id: societyId }, data: updateData });
    return sendSuccess(res, updated, 'Settings updated');
  } catch (err) {
    return sendError(res, 'Failed to update settings', 500);
  }
};
