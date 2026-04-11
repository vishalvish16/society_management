const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../../utils/response');

exports.getStats = async (req, res) => {
  try {
    const { societyId, role } = req.user;

    // super_admin gets platform-wide stats
    if (role === 'SUPER_ADMIN' || role === 'super_admin') {
      const [societies, users, plans] = await Promise.all([
        prisma.society.count(),
        prisma.user.count({ where: { isActive: true } }),
        prisma.plan.count(),
      ]);
      return sendSuccess(res, {
        societiesCount: societies,
        usersCount: users,
        plansCount: plans,
        // UI-friendly keys
        unitsCount: 0,
        pendingBillsCount: 0,
        openComplaintsCount: 0,
        activeVisitorsCount: 0,
      });
    }

    if (!societyId) return sendError(res, 'No society assigned', 400);

    const [units, pendingBills, openComplaints, visitors] = await Promise.all([
      prisma.unit.count({ where: { societyId } }),
      prisma.maintenanceBill.count({ where: { societyId, status: { in: ['pending', 'partial'] } } }),
      prisma.complaint.count({ where: { societyId, status: { in: ['open', 'assigned', 'in_progress'] } } }),
      prisma.visitor.count({ where: { societyId, status: 'valid' } }),
    ]);

    return sendSuccess(res, {
      unitsCount: units,
      pendingBillsCount: pendingBills,
      openComplaintsCount: openComplaints,
      activeVisitorsCount: visitors,
    });
  } catch (err) {
    console.error('Dashboard stats error:', err.message);
    return sendError(res, 'Failed to load dashboard stats', 500);
  }
};

exports.getTrends    = async (req, res) => sendSuccess(res, {});
exports.getSettings  = async (req, res) => sendSuccess(res, {});
exports.updateSettings = async (req, res) => sendSuccess(res, {});
