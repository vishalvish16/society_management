const { verifyAccessToken } = require('../utils/jwt');
const { sendError } = require('../utils/response');
const prisma = require('../config/db');
const { isResidentLikeRole } = require('../utils/unitResident');

/**
 * JWT authentication middleware.
 * Extracts the Bearer token from the Authorization header, verifies it,
 * and attaches the decoded payload to req.user.
 */
async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return sendError(res, 'Access token is required', 401);
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      return sendError(res, 'Access token is required', 401);
    }

    const decoded = verifyAccessToken(token);
    // Hydrate "active unit" for resident-like roles. This is used to strictly scope
    // unit-level data (deliveries, bills, visitors, etc.) to the unit the user is acting as.
    if (decoded?.societyId && isResidentLikeRole(decoded?.role) && !decoded.unitId) {
      try {
        const ur = await prisma.unitResident.findFirst({
          where: {
            userId: decoded.id,
            isStaying: true,
            unit: { societyId: decoded.societyId },
          },
          orderBy: [{ isOwner: 'desc' }, { createdAt: 'desc' }],
          select: { unitId: true },
        });
        decoded.unitId = ur?.unitId || null;
      } catch (e) {
        // Best-effort only; controllers should still validate access.
        decoded.unitId = null;
      }
    }

    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return sendError(res, 'Access token has expired', 401);
    }
    if (error.name === 'JsonWebTokenError') {
      return sendError(res, 'Invalid access token', 401);
    }
    console.error('Auth middleware error:', error.message);
    return sendError(res, 'Authentication failed', 401);
  }
}

// Named aliases used by various generated route files
const validateAndSanitizeQuery = (req, res, next) => next();
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorised' });
  if (roles.length && !roles.includes(req.user.role))
    return res.status(403).json({ error: 'Forbidden' });
  next();
};

module.exports = authMiddleware;
module.exports.authMiddleware       = authMiddleware;
module.exports.authenticateToken    = authMiddleware;
module.exports.authenticateUser     = authMiddleware;
module.exports.validateAndSanitizeQuery = validateAndSanitizeQuery;
module.exports.requireRole          = requireRole;
