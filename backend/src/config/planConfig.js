/**
 * VIDYRON canonical plan config.
 *
 * Rules implemented:
 * - Plan eligibility is based on current UNIT count (maxUnits).
 * - User creation is capped by maxUsers (fair usage for unlimited can be added later).
 * - Feature access is denied-by-default and enforced via `checkPlanLimit(key)` middleware.
 * - Pricing is unit-count based with duration discounts.
 *
 * IMPORTANT: Keep feature keys aligned with existing backend middleware + routes.
 */

const PLAN_DURATIONS = {
  MONTHLY: { months: 1, discountPercent: 0 },
  THREE_MONTHS: { months: 3, discountPercent: 5 },
  SIX_MONTHS: { months: 6, discountPercent: 10 },
  YEARLY: { months: 12, discountPercent: 20 },
};

/**
 * Canonical feature keys for plan enforcement.
 * Boolean features: false = denied, true = allowed.
 * Numeric features: -1 = unlimited, 0 = denied, N = cap.
 */
const FEATURE_DEFAULTS = {
  // Security Management
  visitors: false,
  visitor_qr: false,
  gate_passes: false,
  delivery_tracking: false,
  domestic_help: false,
  parking_management: false,

  // Society Operations
  society_gates: false,
  amenities: false,
  amenity_booking: false,
  move_requests: false,
  complaint_assignment: false,

  // Finance & Billing
  expenses: false,
  expense_approval: false,
  bill_schedules: false,
  financial_reports: false,
  donations: false,

  // Asset Management
  asset_management: false,

  // Numeric
  attachments_count: 0,
};

/**
 * Canonical 3 plans as per VIDYRON table.
 * Pricing is per-unit-per-month (unit count is billing base).
 */
const VIDYRON_PLANS = {
  basic: {
    name: 'basic',
    displayName: 'Basic 🟢',
    pricePerUnit: 5,
    maxUnits: 100,
    maxUsers: 250,
    features: {
      ...FEATURE_DEFAULTS,
      // Core platform + communication are always allowed (not feature-gated here)
    },
  },
  standard: {
    name: 'standard',
    displayName: 'Standard 🔵',
    pricePerUnit: 8,
    maxUnits: 500,
    maxUsers: 1200,
    features: {
      ...FEATURE_DEFAULTS,
      // Security Management ✅
      visitors: true,
      visitor_qr: true,
      gate_passes: true,
      delivery_tracking: true,
      domestic_help: true,
      parking_management: true,
      // Society Operations ✅
      society_gates: true,
      amenities: true,
      amenity_booking: true,
      move_requests: true,
      complaint_assignment: true,
      asset_management: true,
      // Finance/Admin ❌ (remain false)
      attachments_count: 10,
    },
  },
  premium: {
    name: 'premium',
    displayName: 'Premium 🔴',
    pricePerUnit: 12,
    maxUnits: -1,
    maxUsers: -1, // unlimited (fair usage can be enforced later)
    features: {
      ...FEATURE_DEFAULTS,
      // Everything ✅
      visitors: true,
      visitor_qr: true,
      gate_passes: true,
      delivery_tracking: true,
      domestic_help: true,
      parking_management: true,
      society_gates: true,
      amenities: true,
      amenity_booking: true,
      move_requests: true,
      complaint_assignment: true,
      expenses: true,
      expense_approval: true,
      bill_schedules: true,
      financial_reports: true,
      donations: true,
      asset_management: true,
      attachments_count: -1,
    },
  },
};

/**
 * Returns true if the society's plan grants the given boolean feature.
 * @param {object} planFeatures - plan.features JSON from the database
 * @param {string} key
 */
function hasFeature(planFeatures, key) {
  if (!planFeatures || !(key in FEATURE_DEFAULTS)) return false;
  return planFeatures[key] === true;
}

/**
 * Returns the numeric limit for a feature (e.g. attachments_count).
 * Returns -1 for unlimited, 0 if denied.
 * @param {object} planFeatures
 * @param {string} key
 */
function featureLimit(planFeatures, key) {
  if (!planFeatures) return 0;
  const val = planFeatures[key];
  return typeof val === 'number' ? val : 0;
}

/**
 * Throws a 403 if the plan does not include the given feature.
 * @param {object} planFeatures
 * @param {string} key
 */
function requireFeature(planFeatures, key) {
  if (!hasFeature(planFeatures, key)) {
    const err = new Error(`Your current plan does not include this feature. Please upgrade.`);
    err.status = 403;
    throw err;
  }
}

/**
 * Normalize a plan duration string to known codes.
 * @param {string} duration
 */
function normalizeDuration(duration) {
  const d = String(duration || 'MONTHLY').toUpperCase().trim();
  if (PLAN_DURATIONS[d]) return d;
  // Back-compat: accept billingCycle-ish strings
  if (d === 'QUARTERLY') return 'THREE_MONTHS';
  if (d === 'HALF_YEARLY') return 'SIX_MONTHS';
  return 'MONTHLY';
}

/**
 * Compute subscription pricing based on unit count, plan, and duration discount.
 * @param {{ pricePerUnit: number }} plan
 * @param {number} unitCount
 * @param {string} duration - MONTHLY | THREE_MONTHS | SIX_MONTHS | YEARLY
 */
function computeSubscriptionAmount(plan, unitCount, duration) {
  const units = Math.max(parseInt(unitCount || 0, 10) || 0, 0);
  const perUnit = Number(plan.pricePerUnit) || 0;
  const dur = normalizeDuration(duration);
  const { months, discountPercent } = PLAN_DURATIONS[dur];
  const base = units * perUnit * months;
  const discounted = base * (1 - discountPercent / 100);
  const rounded = Math.round(discounted * 100) / 100;
  return { amount: rounded, months, discountPercent, duration: dur, perUnit, unitCount: units };
}

module.exports = {
  FEATURE_DEFAULTS,
  PLAN_DURATIONS,
  VIDYRON_PLANS,
  hasFeature,
  featureLimit,
  requireFeature,
  normalizeDuration,
  computeSubscriptionAmount,
};
