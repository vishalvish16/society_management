/**
 * VIDYRON canonical plan config.
 *
 * Tiered pricing rules:
 * - Super admin can manage tiers per plan via the PricingTier table.
 * - At subscription time we pick the matching tier for the society's unit count.
 * - Fallback: plan.pricePerUnit (flat rate) is used when no tiers are defined.
 *
 * Duration discounts apply on top of the per-unit rate.
 */

const PLAN_DURATIONS = {
  MONTHLY:      { months: 1,  discountPercent: 0  },
  THREE_MONTHS: { months: 3,  discountPercent: 5  },
  SIX_MONTHS:   { months: 6,  discountPercent: 10 },
  YEARLY:       { months: 12, discountPercent: 20 },
};

/**
 * Canonical feature keys for plan enforcement.
 * Boolean features: false = denied, true = allowed.
 * Numeric features: -1 = unlimited, 0 = denied, N = cap.
 */
const FEATURE_DEFAULTS = {
  // Security Management
  visitors:            false,
  visitor_qr:          false,
  gate_passes:         false,
  delivery_tracking:   false,
  domestic_help:       false,
  parking_management:  false,

  // Society Operations
  society_gates:       false,
  amenities:           false,
  amenity_booking:     false,
  move_requests:       false,
  complaint_assignment:false,

  // Finance & Billing
  expenses:            false,
  expense_approval:    false,
  bill_schedules:      false,
  financial_reports:   false,
  donations:           false,

  // Asset Management
  asset_management:    false,

  // Numeric
  attachments_count:   0,
};

/**
 * Canonical 3 plans. pricePerUnit is the flat fallback when no tiers exist in DB.
 * Tiers in DB override this for pricing; maxUnits/maxUsers remain plan-level caps.
 */
const VIDYRON_PLANS = {
  basic: {
    name: 'basic',
    displayName: 'Basic 🟢',
    pricePerUnit: 10, // fallback flat rate
    maxUnits: 100,
    maxUsers: 250,
    features: { ...FEATURE_DEFAULTS },
  },
  standard: {
    name: 'standard',
    displayName: 'Standard 🔵',
    pricePerUnit: 11,
    maxUnits: 500,
    maxUsers: 1200,
    features: {
      ...FEATURE_DEFAULTS,
      visitors: true, visitor_qr: true, gate_passes: true,
      delivery_tracking: true, domestic_help: true, parking_management: true,
      society_gates: true, amenities: true, amenity_booking: true,
      move_requests: true, complaint_assignment: true, asset_management: true,
      attachments_count: 10,
    },
  },
  premium: {
    name: 'premium',
    displayName: 'Premium 🔴',
    pricePerUnit: 12,
    maxUnits: -1,
    maxUsers: -1,
    features: {
      ...FEATURE_DEFAULTS,
      visitors: true, visitor_qr: true, gate_passes: true,
      delivery_tracking: true, domestic_help: true, parking_management: true,
      society_gates: true, amenities: true, amenity_booking: true,
      move_requests: true, complaint_assignment: true,
      expenses: true, expense_approval: true, bill_schedules: true,
      financial_reports: true, donations: true, asset_management: true,
      attachments_count: -1,
    },
  },
};

/**
 * Default tier config as per business rules.
 * Seeded into DB for each canonical plan on first run.
 *
 * Rule: higher unit count = lower price per unit (volume discount).
 * maxUnits = -1 means "no upper bound" (this tier is the ceiling).
 *
 * Basic:    <100 → ₹10, 100–149 → ₹8, 150+ → ₹6
 * Standard: <100 → ₹11, 100–149 → ₹10, 150+ → ₹8
 * Premium:  <100 → ₹12, 100–149 → ₹11, 150+ → ₹9
 */
const DEFAULT_TIERS = {
  basic: [
    { minUnits: 0,   maxUnits: 99,  pricePerUnit: 10, label: 'Less than 100 units', sortOrder: 1 },
    { minUnits: 100, maxUnits: 149, pricePerUnit: 8,  label: '100–149 units',        sortOrder: 2 },
    { minUnits: 150, maxUnits: -1,  pricePerUnit: 6,  label: '150+ units',           sortOrder: 3 },
  ],
  standard: [
    { minUnits: 0,   maxUnits: 99,  pricePerUnit: 11, label: 'Less than 100 units', sortOrder: 1 },
    { minUnits: 100, maxUnits: 149, pricePerUnit: 10, label: '100–149 units',        sortOrder: 2 },
    { minUnits: 150, maxUnits: -1,  pricePerUnit: 8,  label: '150+ units',           sortOrder: 3 },
  ],
  premium: [
    { minUnits: 0,   maxUnits: 99,  pricePerUnit: 12, label: 'Less than 100 units', sortOrder: 1 },
    { minUnits: 100, maxUnits: 149, pricePerUnit: 11, label: '100–149 units',        sortOrder: 2 },
    { minUnits: 150, maxUnits: -1,  pricePerUnit: 9,  label: '150+ units',           sortOrder: 3 },
  ],
};

function hasFeature(planFeatures, key) {
  if (!planFeatures || !(key in FEATURE_DEFAULTS)) return false;
  return planFeatures[key] === true;
}

function featureLimit(planFeatures, key) {
  if (!planFeatures) return 0;
  const val = planFeatures[key];
  return typeof val === 'number' ? val : 0;
}

function requireFeature(planFeatures, key) {
  if (!hasFeature(planFeatures, key)) {
    const err = new Error(`Your current plan does not include this feature. Please upgrade.`);
    err.status = 403;
    throw err;
  }
}

function normalizeDuration(duration) {
  const d = String(duration || 'MONTHLY').toUpperCase().trim();
  if (PLAN_DURATIONS[d]) return d;
  if (d === 'QUARTERLY') return 'THREE_MONTHS';
  if (d === 'HALF_YEARLY') return 'SIX_MONTHS';
  return 'MONTHLY';
}

/**
 * Resolve the per-unit price for a given unit count using tiered pricing.
 * @param {Array<{minUnits:number,maxUnits:number,pricePerUnit:number}>} tiers - sorted ascending by minUnits
 * @param {number} unitCount
 * @param {number} fallbackPricePerUnit - plan.pricePerUnit used when no tiers
 */
function resolveTieredPrice(tiers, unitCount, fallbackPricePerUnit) {
  if (!tiers || tiers.length === 0) return Number(fallbackPricePerUnit) || 0;
  // Sort ascending by minUnits to ensure correct traversal
  const sorted = [...tiers].sort((a, b) => a.minUnits - b.minUnits);
  // Walk tiers; last matching tier wins (so 150+ catches anything above 150)
  let resolved = Number(fallbackPricePerUnit) || 0;
  for (const tier of sorted) {
    const min = tier.minUnits;
    const max = tier.maxUnits; // -1 = no upper bound
    if (unitCount >= min && (max === -1 || unitCount <= max)) {
      resolved = Number(tier.pricePerUnit);
    }
  }
  return resolved;
}

/**
 * Compute subscription pricing.
 * @param {{ pricePerUnit: number, pricingTiers?: Array }} plan
 * @param {number} unitCount
 * @param {string} duration
 * @param {number} [overrideDiscountPercent] - additional manual discount (0–100)
 */
function computeSubscriptionAmount(plan, unitCount, duration, overrideDiscountPercent) {
  const units = Math.max(parseInt(unitCount || 0, 10) || 0, 0);
  const dur = normalizeDuration(duration);
  const { months, discountPercent: durationDiscount } = PLAN_DURATIONS[dur];

  const perUnit = resolveTieredPrice(plan.pricingTiers || [], units, plan.pricePerUnit);

  const base = units * perUnit * months;

  // Manual override discount stacks on top of duration discount (additive, capped at 100%)
  const totalDiscount = Math.min(
    durationDiscount + (overrideDiscountPercent !== undefined && overrideDiscountPercent !== null
      ? Math.max(0, parseFloat(overrideDiscountPercent) || 0)
      : 0),
    100,
  );

  const discounted = base * (1 - totalDiscount / 100);
  const rounded = Math.round(discounted * 100) / 100;

  return {
    amount: rounded,
    months,
    discountPercent: durationDiscount,
    extraDiscountPercent: overrideDiscountPercent || 0,
    totalDiscountPercent: totalDiscount,
    duration: dur,
    perUnit,
    unitCount: units,
  };
}

module.exports = {
  FEATURE_DEFAULTS,
  PLAN_DURATIONS,
  VIDYRON_PLANS,
  DEFAULT_TIERS,
  hasFeature,
  featureLimit,
  requireFeature,
  normalizeDuration,
  resolveTieredPrice,
  computeSubscriptionAmount,
};
