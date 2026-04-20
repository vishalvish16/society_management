/**
 * Canonical feature keys for plan enforcement.
 * Each key maps to a route group gated by checkPlanLimit(key).
 * Boolean features: false = denied, true = allowed.
 * Numeric features: -1 = unlimited, 0 = denied, N = cap.
 *
 * Only features with real backend modules and checkPlanLimit wiring are listed.
 */

const FEATURE_DEFAULTS = {
  visitors: false,           // visitor log (manual walk-in)
  visitor_qr: false,         // QR invite for visitors
  gate_passes: false,        // gate pass create/scan
  expenses: false,           // expense submission
  expense_approval: false,   // expense review/approve workflow
  financial_reports: false,  // /reports/financial and /reports/balance
  donations: false,          // donation campaigns + contributions
  complaint_assignment: false, // assign & track complaints
  society_gates: false,      // society gate management
  amenities: false,          // amenity listing & management
  amenity_booking: false,    // amenity booking by residents
  parking_management: false, // parking slot management
  delivery_tracking: false,  // delivery create/respond/collect
  domestic_help: false,      // domestic help register/log workflow
  move_requests: false,      // move-in/out request workflow
  // Numeric
  attachments_count: 0,      // max file attachments per record (-1 = unlimited)
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
 * Compute the monthly bill for a society given their unit count.
 * totalMonthly = plan.priceMonthly + (unitCount * plan.pricePerUnit)
 * @param {{ priceMonthly: number, pricePerUnit: number }} plan
 * @param {number} unitCount
 */
function computeMonthlyBill(plan, unitCount) {
  const base = Number(plan.priceMonthly) || 0;
  const perUnit = Number(plan.pricePerUnit) || 0;
  return base + perUnit * (unitCount || 0);
}

module.exports = { FEATURE_DEFAULTS, hasFeature, featureLimit, requireFeature, computeMonthlyBill };
