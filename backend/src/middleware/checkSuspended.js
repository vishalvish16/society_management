/**
 * Global suspension gate middleware.
 *
 * Applied after authMiddleware on all society-scoped routes.
 * SUPER_ADMIN is always exempt.
 *
 * If the society's status is SUSPENDED, every API call returns 403 with
 * a consistent error code that the frontend uses to redirect to the
 * SubscriptionSuspendedScreen.
 */
const prisma = require('../config/db');
const { sendError } = require('../utils/response');

async function checkSuspended(req, res, next) {
  try {
    if (!req.user || req.user.role === 'SUPER_ADMIN') return next();

    const societyId = req.user.societyId;
    if (!societyId) return next();

    // Cache bust: always read from DB (status changes must be immediate)
    const society = await prisma.society.findUnique({
      where: { id: societyId },
      select: { status: true },
    });

    if (society?.status === 'SUSPENDED') {
      return res.status(403).json({
        success: false,
        errorCode: 'SOCIETY_SUSPENDED',
        message:
          'Your subscription has been suspended. Please contact your administrator or recharge to continue managing your society seamlessly.',
      });
    }

    next();
  } catch (err) {
    console.error('checkSuspended error:', err.message);
    next(err);
  }
}

module.exports = checkSuspended;
