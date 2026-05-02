const plansService = require('./plans.service');
const { sendSuccess, sendError } = require('../../utils/response');
const prisma = require('../../config/db');
const { normalizeDuration, computeSubscriptionAmount } = require('../../config/planConfig');

// ── Pricing Tier handlers ────────────────────────────────────────────

async function listPlanTiers(req, res, next) {
  try {
    const tiers = await plansService.listTiers(req.params.id);
    return sendSuccess(res, tiers, 'Tiers retrieved');
  } catch (err) { next(err); }
}

async function savePlanTiers(req, res, next) {
  try {
    const { tiers } = req.body;
    if (!Array.isArray(tiers)) return sendError(res, 'tiers must be an array', 400);
    for (const t of tiers) {
      if (t.minUnits === undefined || t.maxUnits === undefined || t.pricePerUnit === undefined) {
        return sendError(res, 'Each tier requires minUnits, maxUnits, pricePerUnit', 400);
      }
    }
    const result = await plansService.upsertTiers(req.params.id, tiers);
    return sendSuccess(res, result, 'Tiers saved');
  } catch (err) { next(err); }
}

async function deletePlanTier(req, res, next) {
  try {
    await plansService.deleteTier(req.params.tierId);
    return sendSuccess(res, null, 'Tier deleted');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Tier not found', 404);
    next(err);
  }
}

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
    // Only expose canonical subscription plans publicly.
    const canonical = new Set(['basic', 'standard', 'premium']);
    const filtered = plans.filter((p) => {
      const name = String(p.name || '');
      return canonical.has(name) && name === name.toLowerCase();
    });
    // Strip internal counts for public endpoint
    const publicPlans = filtered.map(({ societyCount: _sc, ...plan }) => plan);
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
    const { name, displayName, pricePerUnit, priceMonthly, priceYearly, maxUnits, maxUsers, features } = req.body;

    if (!name || !displayName || pricePerUnit === undefined) {
      return sendError(res, 'name, displayName, and pricePerUnit are required', 400);
    }

    // Ensure name is lowercase for unique constraint
    req.body.name = name.toString().toLowerCase().trim();
    
    const plan = await plansService.createPlan({
      name: req.body.name,
      displayName,
      priceMonthly: priceMonthly !== undefined ? parseFloat(priceMonthly) : 0,
      priceYearly: priceYearly !== undefined ? parseFloat(priceYearly) : 0,
      pricePerUnit: parseFloat(pricePerUnit),
      maxUnits: maxUnits !== undefined ? parseInt(maxUnits) : -1,
      maxUsers: maxUsers !== undefined ? parseInt(maxUsers) : -1,
      features: features && !Array.isArray(features) ? features : (Array.isArray(features) ? features : {}),
      isActive: req.body.isActive !== undefined ? req.body.isActive : true
    });
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
    
    // Convert types if present
    if (req.body.pricePerUnit !== undefined) req.body.pricePerUnit = parseFloat(req.body.pricePerUnit);
    if (req.body.priceMonthly !== undefined) req.body.priceMonthly = parseFloat(req.body.priceMonthly);
    if (req.body.priceYearly !== undefined) req.body.priceYearly = parseFloat(req.body.priceYearly);
    if (req.body.maxUnits !== undefined) req.body.maxUnits = parseInt(req.body.maxUnits);
    if (req.body.maxUsers !== undefined) req.body.maxUsers = parseInt(req.body.maxUsers);
    // features may be a JSON object (map) or array — both are valid

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

async function cleanupPlans(req, res, next) {
  try {
    const result = await plansService.cleanupDuplicatePlans();
    return sendSuccess(res, result, 'Plans cleaned up');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

/**
 * Public quote endpoint (no auth): compute eligible plans + pricing for a unitCount/duration.
 * GET /api/plans/public?unitCount=123&duration=MONTHLY
 */
async function publicQuote(req, res, next) {
  try {
    const unitCount = Math.max(parseInt(req.query.unitCount || 0, 10) || 0, 0);
    const duration = normalizeDuration(req.query.duration);

    const plans = await prisma.plan.findMany({
      where: { isActive: true },
      select: {
        id: true, name: true, displayName: true, pricePerUnit: true,
        maxUnits: true, maxUsers: true, features: true,
        pricingTiers: { select: { minUnits: true, maxUnits: true, pricePerUnit: true, label: true, sortOrder: true }, orderBy: { sortOrder: 'asc' } },
      },
      orderBy: { pricePerUnit: 'asc' },
    });
    const canonical = new Set(['basic', 'standard', 'premium']);
    const scoped = plans.filter((p) => {
      const name = String(p.name || '');
      return canonical.has(name) && name === name.toLowerCase();
    });

    const out = scoped.map((p) => {
      const eligible = p.maxUnits === -1 ? true : unitCount <= p.maxUnits;
      const pricing = computeSubscriptionAmount(p, unitCount, duration);
      return {
        ...p,
        eligible,
        quote: {
          unitCount: pricing.unitCount,
          duration: pricing.duration,
          months: pricing.months,
          discountPercent: pricing.discountPercent,
          pricePerUnit: pricing.perUnit,
          amount: pricing.amount,
        },
      };
    });

    return sendSuccess(res, out, 'Plan quotes retrieved');
  } catch (err) {
    next(err);
  }
}

module.exports = { listPlans, listPublicPlans, getPlan, createPlan, updatePlan, deactivatePlan, publicQuote, cleanupPlans, listPlanTiers, savePlanTiers, deletePlanTier };
