const plansService = require('./plans.service');
const { sendSuccess, sendError } = require('../../utils/response');

async function listPlans(req, res, next) {
  try {
    const plans = await plansService.listPlans({ activeOnly: false });
    return sendSuccess(res, plans, 'Plans retrieved');
  } catch (err) {
    next(err);
  }
}

async function listPublicPlans(req, res, next) {
  try {
    const plans = await plansService.listPlans({ activeOnly: true });
    // Strip internal counts for public endpoint
    const publicPlans = plans.map(({ societyCount: _sc, ...plan }) => plan);
    return sendSuccess(res, publicPlans, 'Plans retrieved');
  } catch (err) {
    next(err);
  }
}

async function getPlan(req, res, next) {
  try {
    const plan = await plansService.getPlanById(req.params.id);
    if (!plan) return sendError(res, 'Plan not found', 404);
    return sendSuccess(res, plan, 'Plan retrieved');
  } catch (err) {
    next(err);
  }
}

async function createPlan(req, res, next) {
  try {
    const { name, displayName, priceMonthly, price } = req.body;

    // Map frontend 'price' to backend 'priceMonthly' if missing
    if (priceMonthly === undefined && price !== undefined) {
      req.body.priceMonthly = price;
    }
    
    // If displayName is missing but name is provided, use name as displayName
    if (!displayName && name) {
      req.body.displayName = name;
    }

    if (!req.body.name || !req.body.displayName || req.body.priceMonthly === undefined) {
      return sendError(res, 'name, displayName, and priceMonthly are required', 400);
    }

    // Ensure name is lowercase for unique constraint
    req.body.name = (req.body.name || req.body.displayName || '').toString().toLowerCase().trim();
    
    if (!req.body.name) {
      return sendError(res, 'Plan name or code is required', 400);
    }

    const plan = await plansService.createPlan(req.body);
    return sendSuccess(res, plan, 'Plan created', 201);
  } catch (err) {
    if (err.code === 'P2002') return sendError(res, 'A plan with this name already exists', 409);
    next(err);
  }
}

async function updatePlan(req, res, next) {
  try {
    if (req.body.name) {
      return sendError(res, 'Plan internal name cannot be changed after creation', 400);
    }
    
    // Map frontend 'price' to backend 'priceMonthly' if missing
    if (req.body.priceMonthly === undefined && req.body.price !== undefined) {
      req.body.priceMonthly = req.body.price;
    }

    const plan = await plansService.updatePlan(req.params.id, req.body);
    return sendSuccess(res, plan, 'Plan updated');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Plan not found', 404);
    next(err);
  }
}

async function deactivatePlan(req, res, next) {
  try {
    const plan = await plansService.deactivatePlan(req.params.id);
    return sendSuccess(res, plan, 'Plan deactivated');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Plan not found', 404);
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

module.exports = { listPlans, listPublicPlans, getPlan, createPlan, updatePlan, deactivatePlan };
