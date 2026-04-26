const prisma = require('../../config/db');

const PLAN_SELECT = {
  id: true,
  name: true,
  displayName: true,
  pricePerUnit: true,
  maxUnits: true,
  maxUsers: true,
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
    orderBy: { pricePerUnit: 'asc' },
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
 * Create or update a subscription plan.
 * @param {object} data
 */
async function createPlan(data) {
  const { name, displayName, pricePerUnit, maxUnits, maxUsers, features, isActive } = data;

  const payload = {
    displayName,
    pricePerUnit: pricePerUnit ?? 0,
    maxUnits: maxUnits !== undefined ? maxUnits : -1,
    maxUsers: maxUsers !== undefined ? maxUsers : -1,
    features: features || [],
    isActive: isActive !== undefined ? isActive : true,
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
  const allowed = ['displayName', 'pricePerUnit', 'maxUnits', 'maxUsers', 'features', 'isActive'];
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

/**
 * One-time cleanup: migrate societies from duplicate plan names to canonical plans,
 * then deactivate non-canonical plans (including uppercase variants).
 *
 * Canonical plans: basic | standard | premium (lowercase).
 */
async function cleanupDuplicatePlans() {
  const canonical = ['basic', 'standard', 'premium'];

  return prisma.$transaction(async (tx) => {
    const plans = await tx.plan.findMany({
      select: { id: true, name: true, displayName: true, isActive: true },
    });

    // Build canonical planId map
    const canonicalByName = new Map();
    for (const p of plans) {
      const name = String(p.name || '');
      if (canonical.includes(name) && name === name.toLowerCase()) {
        canonicalByName.set(name, p.id);
      }
    }

    const missing = canonical.filter((n) => !canonicalByName.has(n));
    if (missing.length) {
      throw Object.assign(new Error(`Missing canonical plan(s): ${missing.join(', ')}. Run seed first.`), { status: 400 });
    }

    // 1) migrate societies on duplicate plans to canonical equivalent (case-insensitive match)
    const toMigrate = plans.filter((p) => {
      const name = String(p.name || '');
      const lower = name.toLowerCase();
      return canonical.includes(lower) && name !== lower;
    });

    let migratedSocieties = 0;
    for (const dup of toMigrate) {
      const targetId = canonicalByName.get(String(dup.name).toLowerCase());
      const res = await tx.society.updateMany({
        where: { planId: dup.id },
        data: { planId: targetId },
      });
      migratedSocieties += res.count || 0;
    }

    // 2) deactivate any plan that is not exactly canonical lowercase
    const nonCanonical = plans.filter((p) => {
      const name = String(p.name || '');
      return !(canonical.includes(name) && name === name.toLowerCase());
    });

    // safety: don't deactivate if still referenced
    let deactivatedPlans = 0;
    const skippedPlans = [];
    for (const p of nonCanonical) {
      const refCount = await tx.society.count({ where: { planId: p.id } });
      if (refCount > 0) {
        skippedPlans.push({ id: p.id, name: p.name, societies: refCount });
        continue;
      }
      if (p.isActive) {
        await tx.plan.update({ where: { id: p.id }, data: { isActive: false } });
      }
      deactivatedPlans += 1;
    }

    return {
      canonicalPlans: canonical,
      migratedSocieties,
      deactivatedPlans,
      skippedPlans,
    };
  });
}

module.exports = { listPlans, getPlanById, createPlan, updatePlan, deactivatePlan, cleanupDuplicatePlans };
