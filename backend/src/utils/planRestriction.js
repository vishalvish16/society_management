
const prisma = require('../config/db');
const { computeSubscriptionAmount, normalizeDuration } = require('../config/planConfig');

/**
 * Checks if adding a new item (UNIT or USER) would exceed the society's plan limits.
 * @param {string} societyId 
 * @param {'UNIT'|'USER'} type 
 * @throws {Error} If limit is reached
 */
async function checkPlanRestriction(societyId, type) {
  if (!societyId) return; // Super admin level or global

  const society = await prisma.society.findUnique({
    where: { id: societyId },
    include: { plan: true },
  });

  if (!society || !society.plan) return;

  if (type === 'UNIT') {
    if (society.plan.maxUnits === -1) return;
    const unitCount = await prisma.unit.count({ where: { societyId, deletedAt: null } });
    if (unitCount >= society.plan.maxUnits) {
      throw Object.assign(new Error(`Unit limit reached for ${society.plan.displayName}. Maximum ${society.plan.maxUnits} units allowed.`), { status: 403 });
    }
  }

  if (type === 'USER') {
    if (society.plan.maxUsers === -1) return;
    const userCount = await prisma.user.count({ where: { societyId, deletedAt: null } });
    if (userCount >= society.plan.maxUsers) {
      throw Object.assign(new Error(`User limit reached for ${society.plan.displayName}. Maximum ${society.plan.maxUsers} users allowed.`), { status: 403 });
    }
  }
}

/**
 * Checks if a society has access to a specific feature based on their plan.
 * @param {string} societyId 
 * @param {string} feature 
 * @returns {Promise<boolean>}
 */
async function checkFeatureAccess(societyId, feature) {
  if (!societyId) return true; // Super admin

  const society = await prisma.society.findUnique({
    where: { id: societyId },
    include: { plan: true },
  });

  if (!society || !society.plan) return false;
  
  const features = society.plan.features;
  if (Array.isArray(features)) return features.includes(feature);
  if (features && typeof features === 'object') return features[feature] === true;
  return false;
}

/**
 * Compute a subscription quote for a society (based on current unit count).
 * @param {{ societyId: string, planName: string, duration?: string }} input
 */
async function quoteSocietyPlan({ societyId, planName, duration }) {
  const society = await prisma.society.findUnique({
    where: { id: societyId },
    select: { id: true, status: true, planId: true },
  });
  if (!society) throw Object.assign(new Error('Society not found'), { status: 404 });

  const plan = await prisma.plan.findUnique({
    where: { name: String(planName || '').toLowerCase().trim() },
    select: { id: true, name: true, displayName: true, pricePerUnit: true, maxUnits: true, maxUsers: true, isActive: true },
  });
  if (!plan) throw Object.assign(new Error('Plan not found'), { status: 400 });
  if (!plan.isActive) throw Object.assign(new Error('Plan is not active'), { status: 400 });

  const unitCount = await prisma.unit.count({ where: { societyId, deletedAt: null } });
  const eligible = plan.maxUnits === -1 ? true : unitCount <= plan.maxUnits;
  if (!eligible) {
    throw Object.assign(
      new Error(`This society has ${unitCount} units, so it is not eligible for ${plan.displayName} (max ${plan.maxUnits}).`),
      { status: 400 },
    );
  }

  const normDuration = normalizeDuration(duration);
  const pricing = computeSubscriptionAmount(plan, unitCount, normDuration);
  return {
    societyId,
    plan: { id: plan.id, name: plan.name, displayName: plan.displayName, maxUnits: plan.maxUnits, maxUsers: plan.maxUsers },
    unitCount,
    duration: pricing.duration,
    months: pricing.months,
    discountPercent: pricing.discountPercent,
    pricePerUnit: pricing.perUnit,
    amount: pricing.amount,
  };
}

module.exports = { checkPlanRestriction, checkFeatureAccess, quoteSocietyPlan };
