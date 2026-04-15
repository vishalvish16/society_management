const prisma = require('../../config/db');

const PLAN_SELECT = {
  id: true,
  name: true,
  displayName: true,
  priceMonthly: true,
  priceYearly: true,
  maxUnits: true,
  maxResidents: true,
  maxWatchmen: true,
  maxSecretaries: true,
  features: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
};

/**
 * List all plans (active + inactive for admin, active-only for public).
 * @param {{ activeOnly?: boolean }} options
 */
async function listPlans({ activeOnly = false } = {}) {
  const where = activeOnly ? { isActive: true } : {};
  const plans = await prisma.plan.findMany({
    where,
    select: {
      ...PLAN_SELECT,
      _count: { select: { societies: true } },
    },
    orderBy: { priceMonthly: 'asc' },
  });
  return plans.map((p) => ({ ...p, societyCount: p._count.societies, _count: undefined }));
}

/**
 * Get plan by ID with subscriber count.
 * @param {string} id
 */
async function getPlanById(id) {
  const plan = await prisma.plan.findUnique({
    where: { id },
    select: {
      ...PLAN_SELECT,
      _count: { select: { societies: true } },
      societies: {
        where: { status: 'ACTIVE' },
        select: { id: true, name: true, status: true },
        take: 20,
      },
    },
  });
  if (!plan) return null;
  return { ...plan, societyCount: plan._count.societies, _count: undefined };
}

/**
 * Create or update a subscription plan (upsert by name).
 * @param {object} data
 */
async function createPlan(data) {
  const { name, displayName, priceMonthly, priceYearly, maxUnits, maxResidents, maxWatchmen, maxSecretaries, features } = data;
  
  const payload = {
    displayName,
    priceMonthly,
    priceYearly: priceYearly || priceMonthly * 10,
    maxUnits: maxUnits || -1,
    maxResidents: maxResidents || -1,
    maxWatchmen: maxWatchmen || 2,
    maxSecretaries: maxSecretaries || 2,
    features: features || {},
    isActive: true,
  };

  return prisma.plan.upsert({
    where: { name },
    update: payload,
    create: { ...payload, name },
    select: PLAN_SELECT,
  });
}

/**
 * Update a plan.
 * @param {string} id
 * @param {object} data
 */
async function updatePlan(id, data) {
  const allowed = ['displayName', 'priceMonthly', 'priceYearly', 'maxUnits', 'maxResidents', 'maxWatchmen', 'maxSecretaries', 'features', 'isActive'];
  const updateData = {};
  for (const key of allowed) {
    if (data[key] !== undefined) updateData[key] = data[key];
  }
  return prisma.plan.update({
    where: { id },
    data: updateData,
    select: PLAN_SELECT,
  });
}

/**
 * Soft deactivate a plan (cannot if active societies exist on it).
 * @param {string} id
 */
async function deactivatePlan(id) {
  const activeCount = await prisma.society.count({
    where: { planId: id, status: 'ACTIVE' },
  });

  if (activeCount > 0) {
    throw Object.assign(
      new Error(`Cannot deactivate plan with ${activeCount} active society(ies). Migrate them first.`),
      { status: 409 }
    );
  }

  return prisma.plan.update({
    where: { id },
    data: { isActive: false },
    select: PLAN_SELECT,
  });
}

module.exports = { listPlans, getPlanById, createPlan, updatePlan, deactivatePlan };
