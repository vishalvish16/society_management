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
          plan: {
            select: {
              maxUnits: true,
              maxResidents: true,
              maxWatchmen: true,
              maxSecretaries: true,
              features: true,
              isActive: true,
            },
          },
        },
      });

      if (!society || society.status !== 'ACTIVE') {
        return sendError(res, 'Society is not active. Please contact your administrator.', 403);
      }

      if (!society.plan || !society.plan.isActive) {
        return sendError(res, 'No active plan assigned. Please contact your administrator.', 403);
      }

      if (society.planRenewalDate && new Date(society.planRenewalDate) < new Date()) {
        return sendError(res, 'Your plan has expired. Please renew to continue.', 403);
      }

      const plan = society.plan;

      // ── Count-based caps ──────────────────────────────────────────────

      if (feature === 'units') {
        const count = await prisma.unit.count({ where: { societyId } });
        const max = plan.maxUnits;
        if (max !== -1 && count >= max) {
          return sendError(res, `Unit limit reached (${count}/${max}). Upgrade your plan to add more.`, 403);
        }
        return next();
      }

      if (feature === 'secretaries') {
        const count = await prisma.user.count({
          where: { societyId, role: 'SECRETARY', deletedAt: null },
        });
        const max = plan.maxSecretaries;
        if (max !== -1 && count >= max) {
          return sendError(res, `Secretary limit reached (${count}/${max}). Upgrade your plan to add more.`, 403);
        }
        return next();
      }

      if (feature === 'watchmen') {
        const count = await prisma.user.count({
          where: { societyId, role: 'WATCHMAN', deletedAt: null },
        });
        const max = plan.maxWatchmen ?? -1;
        if (max !== -1 && count >= max) {
          return sendError(res, `Watchman limit reached (${count}/${max}). Upgrade your plan to add more.`, 403);
        }
        return next();
      }

      if (feature === 'residents') {
        const count = await prisma.user.count({
          where: { societyId, role: 'RESIDENT', deletedAt: null },
        });
        const max = plan.maxResidents ?? -1;
        if (max !== -1 && count >= max) {
          return sendError(res, `Resident limit reached (${count}/${max}). Upgrade your plan to add more.`, 403);
        }
        return next();
      }

      // ── Boolean feature flags ─────────────────────────────────────────
      // Deny-by-default: key must exist AND equal true.
      const features = plan.features || {};
      if (features[feature] !== true) {
        const label = feature.replace(/_/g, ' ');
        return sendError(
          res,
          `"${label}" is not included in your current plan. Please upgrade to access this feature.`,
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
