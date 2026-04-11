const { sendError } = require('../utils/response');

/**
 * Role-based access control middleware factory.
 * Returns middleware that checks whether req.user.role is in the allowed list.
 * @param {...string} roles - Allowed roles (e.g. 'PRAMUKH', 'SECRETARY')
 * @returns {import('express').RequestHandler}
 */
function roleGuard(...roles) {
  const allowedRoles = Array.isArray(roles[0]) ? roles[0] : roles;
  return (req, res, next) => {

    if (!req.user) {
      return sendError(res, 'Authentication required', 401);
    }

    if (!allowedRoles.includes(req.user.role)) {

      return sendError(res, 'Insufficient permissions', 403);
    }

    next();
  };
}

module.exports = roleGuard;
