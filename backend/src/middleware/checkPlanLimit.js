const prisma = require('../config/db');
const { sendError } = require('../utils/response');

/**
 * Plan limit enforcement middleware factory.
 *
 * Usage:
 *   checkPlanLimit('visitor_qr')     — boolean feature gate
 *   checkPlanLimit('units')          — count-based cap (maxUnits)
 *   checkPlanLimit('secretaries')    — count-based cap (maxSecretaries)
 *   checkPlanLimit('watchmen')       — count-based cap (maxWatchmen)
 *   checkPlanLimit('residents')      — count-based cap (maxResidents)
 *
 * Feature flag rule: the key MUST exist in plan.features AND equal true.
 * A missing key is treated as false (deny-by-default).
 */
function checkPlanLimit(feature) {
  return async (req, res, next) => {
    try {
      if (req.user.role === 'SUPER_ADMIN') return next();

      const societyId = req.user.societyId;
      if (!societyId) {
        return sendError(res, 'No society associated with this account', 403);
      }

      const society = await prisma.society.findUnique({
        where: { id: societyId },
        select: {
          status: true,
          planRenewalDate: true,
          maxUnits: true,   // per-society override (null = use plan limit)
          maxUsers: true,   // per-society override (null = use plan limit)
          plan: {
            select: {
              maxUnits: true,
              maxUsers: true,
              features: true,
              isActive: true,
              displayName: true,
            },
          },
        },
      });

      if (!society) {
        return sendError(res, 'Society not found.', 403);
      }

      if (society.status === 'SUSPENDED') {
        return sendError(res, 'Your subscription has been suspended. Please contact your administrator to reactivate.', 403);
      }

      if (society.status !== 'ACTIVE') {
        return sendError(res, 'Society is not active. Please contact your administrator.', 403);
      }

      const plan = society.plan;
      if (!plan || !plan.isActive) {
        return sendError(res, 'No active plan assigned. Please contact your administrator.', 403);
      }

      if (society.planRenewalDate && new Date(society.planRenewalDate) < new Date()) {
        return sendError(res, 'Your plan has expired. Please renew to continue.', 403);
      }

      // ── Count-based caps ──────────────────────────────────────────────
      // Per-society override wins over plan-level limit when set.

      if (feature === 'units') {
        const count = await prisma.unit.count({ where: { societyId, deletedAt: null } });
        const max = society.maxUnits !== null && society.maxUnits !== undefined
          ? society.maxUnits
          : plan.maxUnits;
        if (max !== -1 && count >= max) {
          return sendError(res, `Unit limit reached (${count}/${max}). Upgrade your plan to add more.`, 403);
        }
        return next();
      }

      if (feature === 'users' || ['RESIDENT', 'WATCHMAN', 'SECRETARY', 'MEMBER'].includes(feature)) {
        const count = await prisma.user.count({ where: { societyId, deletedAt: null } });
        const max = society.maxUsers !== null && society.maxUsers !== undefined
          ? society.maxUsers
          : plan.maxUsers;
        if (max !== -1 && count >= max) {
          return sendError(res, `User limit reached (${count}/${max}). Upgrade your plan to add more.`, 403);
        }
        return next();
      }

      // ── Boolean feature flags ─────────────────────────────────────────
      const features = plan.features || [];
      const hasAccess = Array.isArray(features) ? features.includes(feature) : !!features[feature];
      
      if (!hasAccess) {
        const label = feature.replace(/_/g, ' ');
        return sendError(
          res,
          `"${label}" is not included in your ${plan.displayName}. Please upgrade to access this feature.`,
          403
        );
      }

      next();
    } catch (err) {
      console.error('checkPlanLimit error:', err.message);
      next(err);
    }
  };
}

module.exports = checkPlanLimit;
