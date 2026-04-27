const prisma = require('../config/db');
const { sendError } = require('../utils/response');
const { resolveRoleFeatureAllowed } = require('../utils/rolePermissions');

/**
 * Society-configurable permission guard.
 * Checks society.settings.rolePermissions[role][featureKey] (with defaults).
 * @param {string} featureKey
 * @returns {import('express').RequestHandler}
 */
function permissionGuard(featureKey) {
  if (!featureKey) throw new Error('permissionGuard(featureKey) is required');

  return async (req, res, next) => {
    try {
      if (!req.user) return sendError(res, 'Authentication required', 401);

      const society = await prisma.society.findUnique({
        where: { id: req.user.societyId },
        select: { settings: true },
      });
      if (!society) return sendError(res, 'Society not found', 404);

      const settings = society.settings || {};
      const allowed = resolveRoleFeatureAllowed({
        rolePermissions: settings.rolePermissions || {},
        role: req.user.role,
        featureKey,
      });

      if (!allowed) return sendError(res, 'Insufficient permissions', 403);
      return next();
    } catch (err) {
      return sendError(res, err.message || 'Permission check failed', 500);
    }
  };
}

module.exports = permissionGuard;

