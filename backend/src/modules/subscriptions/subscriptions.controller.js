const subscriptionsService = require('./subscriptions.service');
const { sendSuccess, sendError } = require('../../utils/response');

async function listSubscriptions(req, res, next) {
  try {
    const { page = 1, limit = 20, societyId, status } = req.query;
    const result = await subscriptionsService.listSubscriptions({
      page: parseInt(page, 10),
      limit: Math.min(parseInt(limit, 10) || 20, 100),
      societyId: societyId || undefined,
      status: status || undefined,
    });
    return sendSuccess(res, result, 'Subscriptions retrieved');
  } catch (err) {
    next(err);
  }
}

async function getSubscription(req, res, next) {
  try {
    const sub = await subscriptionsService.getSubscriptionById(req.params.id);
    if (!sub) return sendError(res, 'Subscription not found', 404);
    return sendSuccess(res, sub, 'Subscription retrieved');
  } catch (err) {
    next(err);
  }
}

async function assignPlan(req, res, next) {
  try {
    const { societyId, planName, billingCycle, amount, paymentMethod, reference, notes } = req.body;

    if (!societyId || !planName) {
      return sendError(res, 'societyId and planName are required', 400);
    }

    const sub = await subscriptionsService.assignPlan({
      societyId,
      planName,
      billingCycle,
      amount,
      paymentMethod,
      reference,
      notes,
      recordedById: req.user?.id,
    });
    return sendSuccess(res, sub, 'Plan assigned successfully', 201);
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function renewSubscription(req, res, next) {
  try {
    const { billingCycle, amount, paymentMethod, reference, planName, periods, discountPercent, notes, startDate } =
      req.body;
    const sub = await subscriptionsService.renewSubscription(req.params.id, {
      billingCycle,
      amount,
      paymentMethod,
      reference,
      planName,
      periods,
      discountPercent,
      notes,
      startDate,
      recordedById: req.user?.id,
    });
    return sendSuccess(res, sub, 'Subscription renewed');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function getSubscriptionReport(req, res, next) {
  try {
    const {
      from,
      to,
      planName,
      paymentMethod,
      search,
      orderBy = 'createdAt',
      orderDir = 'desc',
      page = 1,
      limit = 50,
    } = req.query;

    const result = await subscriptionsService.getSubscriptionReport({
      from,
      to,
      planName,
      paymentMethod,
      search,
      orderBy,
      orderDir,
      page: parseInt(page, 10),
      limit: Math.min(parseInt(limit, 10) || 50, 200),
    });
    return sendSuccess(res, result, 'Subscription report retrieved');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function suspendSociety(req, res, next) {
  try {
    const { reason } = req.body;
    const result = await subscriptionsService.suspendSociety(req.params.societyId, {
      reason,
      suspendedById: req.user?.id,
    });
    return sendSuccess(res, result, 'Society suspended');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function reactivateSociety(req, res, next) {
  try {
    const result = await subscriptionsService.reactivateSociety(req.params.societyId);
    return sendSuccess(res, result, 'Society reactivated');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

module.exports = {
  listSubscriptions,
  getSubscription,
  assignPlan,
  renewSubscription,
  getSubscriptionReport,
  suspendSociety,
  reactivateSociety,
};
