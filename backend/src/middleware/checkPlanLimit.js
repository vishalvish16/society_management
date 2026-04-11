const prisma = require('../config/db');
const { sendError } = require('../utils/response');

/**
 * Plan limit enforcement middleware factory.
 * Schema has no Subscription model — society carries planId directly.
 * Plan limits: maxUnits, maxSecretaries, features (Json).
 */
function checkPlanLimit(feature) {
  return async (req, res, next) => {
    try {
      if (req.user.role === 'SUPER_ADMIN') return next();

      const societyId = req.user.societyId;
      if (!societyId) {
        return sendError(res, 'No society associated with this account', 403);
      }

      // Load society with its plan
      const society = await prisma.society.findUnique({
        where: { id: societyId },
        select: {
          status: true,
          planRenewalDate: true,
          plan: {
            select: { maxUnits: true, maxSecretaries: true, features: true, isActive: true },
          },
        },
      });

      if (!society || society.status !== 'active') {
        return sendError(res, 'Society is not active. Please contact your administrator.', 403);
      }

      if (!society.plan || !society.plan.isActive) {
        return sendError(res, 'No active plan assigned. Please contact your administrator.', 403);
      }

      // Check plan renewal
      if (society.planRenewalDate && new Date(society.planRenewalDate) < new Date()) {
        return sendError(res, 'Your plan has expired. Please renew to continue.', 403);
      }

      const plan = society.plan;

      // Count-based limits
      if (feature === 'units') {
        const currentCount = await prisma.unit.count({ where: { societyId } });
        const maxAllowed = plan.maxUnits;
        if (maxAllowed !== -1 && currentCount >= maxAllowed) {
          return sendError(res, `Plan limit reached (${currentCount}/${maxAllowed} units). Upgrade to add more.`, 403);
        }
        return next();
      }

      if (feature === 'secretaries') {
        const currentCount = await prisma.user.count({
          where: { societyId, role: 'SECRETARY', deletedAt: null },
        });
        const maxAllowed = plan.maxSecretaries;
        if (maxAllowed !== -1 && currentCount >= maxAllowed) {
          return sendError(res, `Plan limit reached (${currentCount}/${maxAllowed} secretaries). Upgrade to add more.`, 403);
        }
        return next();
      }

      // Feature flag checks (plan.features is a JSON object)
      const features = plan.features || {};
      if (features[feature] === false) {
        const label = feature.charAt(0).toUpperCase() + feature.slice(1);
        return sendError(res, `${label} is not available on your current plan. Please upgrade.`, 403);
      }

      next();
    } catch (err) {
      console.error('checkPlanLimit error:', err.message);
      next(err);
    }
  };
}

module.exports = checkPlanLimit;
