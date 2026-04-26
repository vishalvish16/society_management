const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * GET /api/settings/payment
 * Returns the payment settings of the caller's society.
 * Accessible by all authenticated users (so the Pay Now sheet can show details).
 * NOTE: razorpayKeySecret is NEVER returned — only keyId is sent to clients.
 */
async function getPaymentSettings(req, res) {
  try {
    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });

    if (!society) return sendError(res, 'Society not found', 404);

    const settings = society.settings || {};
    const payment = {
      // UPI
      upiId: settings.upiId || null,
      upiName: settings.upiName || null,
      // Bank
      bankName: settings.bankName || null,
      accountNumber: settings.accountNumber || null,
      ifscCode: settings.ifscCode || null,
      accountHolderName: settings.accountHolderName || null,
      // Note
      paymentNote: settings.paymentNote || null,
      // Gateway
      activeGateway: settings.activeGateway || null,
      razorpayKeyId: settings.razorpayKeyId || null,
      // razorpayKeySecret intentionally omitted
    };

    return sendSuccess(res, payment, 'Payment settings retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
}

/**
 * PATCH /api/settings/payment
 * Update payment settings. Admin only (PRAMUKH / CHAIRMAN / SECRETARY).
 */
async function updatePaymentSettings(req, res) {
  try {
    const {
      upiId, upiName,
      bankName, accountNumber, ifscCode, accountHolderName,
      paymentNote,
      activeGateway,
      razorpayKeyId, razorpayKeySecret,
    } = req.body;

    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });

    if (!society) return sendError(res, 'Society not found', 404);

    const currentSettings = society.settings || {};

    const updatedSettings = {
      ...currentSettings,
      ...(upiId !== undefined && { upiId: upiId || null }),
      ...(upiName !== undefined && { upiName: upiName || null }),
      ...(bankName !== undefined && { bankName: bankName || null }),
      ...(accountNumber !== undefined && { accountNumber: accountNumber || null }),
      ...(ifscCode !== undefined && { ifscCode: ifscCode || null }),
      ...(accountHolderName !== undefined && { accountHolderName: accountHolderName || null }),
      ...(paymentNote !== undefined && { paymentNote: paymentNote || null }),
      ...(activeGateway !== undefined && { activeGateway: activeGateway || null }),
      ...(razorpayKeyId !== undefined && { razorpayKeyId: razorpayKeyId || null }),
      // Only overwrite secret if explicitly provided and non-empty
      ...(razorpayKeySecret && razorpayKeySecret.trim() && { razorpayKeySecret: razorpayKeySecret.trim() }),
    };

    await prisma.society.update({
      where: { id: req.user.societyId },
      data: { settings: updatedSettings },
    });

    // Return same shape as GET — no secret
    const payment = {
      upiId: updatedSettings.upiId,
      upiName: updatedSettings.upiName,
      bankName: updatedSettings.bankName,
      accountNumber: updatedSettings.accountNumber,
      ifscCode: updatedSettings.ifscCode,
      accountHolderName: updatedSettings.accountHolderName,
      paymentNote: updatedSettings.paymentNote,
      activeGateway: updatedSettings.activeGateway,
      razorpayKeyId: updatedSettings.razorpayKeyId,
    };

    return sendSuccess(res, payment, 'Payment settings updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
}

// ── Role Permissions ──────────────────────────────────────────────────────

const CONFIGURABLE_ROLES = [
  'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER',
  'VICE_CHAIRMAN', 'ASSISTANT_SECRETARY',
  'TREASURER', 'ASSISTANT_TREASURER',
  'MEMBER', 'RESIDENT', 'WATCHMAN',
];

const ALL_FEATURES = [
  { key: 'dashboard',    label: 'Dashboard',      group: 'Main' },
  { key: 'units',        label: 'Units',          group: 'Main' },
  { key: 'members',      label: 'Members',        group: 'Main' },
  { key: 'bills',        label: 'Bills',          group: 'Finance' },
  { key: 'expenses',     label: 'Expenses',       group: 'Finance' },
  { key: 'donations',    label: 'Donations',      group: 'Finance' },
  { key: 'balance_report', label: 'Balance Report', group: 'Finance' },
  { key: 'pending_dues', label: 'Pending Dues',   group: 'Finance' },
  { key: 'visitors',     label: 'Visitors',       group: 'Security' },
  { key: 'gate_passes',  label: 'Gate Passes',    group: 'Security' },
  { key: 'vehicles',     label: 'Vehicles',       group: 'Security' },
  { key: 'parking',      label: 'Parking',        group: 'Security' },
  { key: 'complaints',   label: 'Complaints',     group: 'Society' },
  { key: 'suggestions',  label: 'Suggestions',    group: 'Society' },
  { key: 'notices',      label: 'Notices',        group: 'Society' },
  { key: 'polls',        label: 'Polls',          group: 'Society' },
  { key: 'events',       label: 'Events',         group: 'Society' },
  { key: 'amenities',    label: 'Amenities',      group: 'Society' },
  { key: 'staff',        label: 'Staff',          group: 'Society' },
  { key: 'deliveries',   label: 'Deliveries',     group: 'Society' },
  { key: 'domestic_help', label: 'Domestic Help', group: 'Society' },
  { key: 'chat',         label: 'Messages',       group: 'More' },
  { key: 'notifications', label: 'Notifications', group: 'More' },
];

const FEATURE_KEYS = ALL_FEATURES.map(f => f.key);

function buildDefaults() {
  const allEnabled = {};
  FEATURE_KEYS.forEach(k => { allEnabled[k] = true; });

  return {
    PRAMUKH:             { ...allEnabled },
    CHAIRMAN:           { ...allEnabled },
    SECRETARY:          { ...allEnabled },
    MANAGER:            { ...allEnabled },
    VICE_CHAIRMAN:       { ...allEnabled },
    ASSISTANT_SECRETARY: { ...allEnabled },
    TREASURER:           { ...allEnabled },
    ASSISTANT_TREASURER: { ...allEnabled },
    MEMBER: {
      dashboard: true, bills: true, complaints: true, suggestions: true,
      notices: true, polls: true, events: true, chat: true, notifications: true,
      visitors: true, gate_passes: true, deliveries: true, domestic_help: true,
      amenities: true, donations: true,
      units: false, members: false, expenses: false, balance_report: false,
      pending_dues: false, vehicles: false, parking: false, staff: false,
    },
    RESIDENT: {
      dashboard: true, bills: true, complaints: true, suggestions: true,
      notices: true, polls: true, events: true, chat: true, notifications: true,
      visitors: true, gate_passes: true, deliveries: true, domestic_help: true,
      amenities: true, donations: true,
      units: false, members: false, expenses: false, balance_report: false,
      pending_dues: false, vehicles: false, parking: false, staff: false,
    },
    WATCHMAN: {
      dashboard: true, visitors: true, gate_passes: true, parking: true,
      deliveries: true, domestic_help: true, notifications: true,
      units: false, members: false, bills: false, expenses: false,
      donations: false, balance_report: false, pending_dues: false,
      vehicles: false, complaints: false, suggestions: false, notices: false,
      polls: false, events: false, amenities: false, staff: false, chat: false,
    },
  };
}

/**
 * GET /api/settings/permissions
 */
async function getRolePermissions(req, res) {
  try {
    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    if (!society) return sendError(res, 'Society not found', 404);

    const settings = society.settings || {};
    const saved = settings.rolePermissions || {};
    const defaults = buildDefaults();

    const merged = {};
    for (const role of CONFIGURABLE_ROLES) {
      merged[role] = { ...defaults[role], ...(saved[role] || {}) };
    }

    return sendSuccess(res, {
      rolePermissions: merged,
      features: ALL_FEATURES,
      roles: CONFIGURABLE_ROLES,
    }, 'Role permissions retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
}

/**
 * PUT /api/settings/permissions
 * Body: { rolePermissions: { MEMBER: { bills: true, expenses: false, ... }, ... } }
 */
async function updateRolePermissions(req, res) {
  try {
    const { rolePermissions } = req.body;
    if (!rolePermissions || typeof rolePermissions !== 'object') {
      return sendError(res, 'rolePermissions object is required', 400);
    }

    const sanitized = {};
    for (const role of CONFIGURABLE_ROLES) {
      if (!rolePermissions[role]) continue;
      sanitized[role] = {};
      for (const key of FEATURE_KEYS) {
        if (rolePermissions[role][key] !== undefined) {
          sanitized[role][key] = !!rolePermissions[role][key];
        }
      }
    }

    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    if (!society) return sendError(res, 'Society not found', 404);

    const currentSettings = society.settings || {};
    const updatedSettings = {
      ...currentSettings,
      rolePermissions: sanitized,
    };

    await prisma.society.update({
      where: { id: req.user.societyId },
      data: { settings: updatedSettings },
    });

    const defaults = buildDefaults();
    const merged = {};
    for (const role of CONFIGURABLE_ROLES) {
      merged[role] = { ...defaults[role], ...(sanitized[role] || {}) };
    }

    return sendSuccess(res, {
      rolePermissions: merged,
      features: ALL_FEATURES,
      roles: CONFIGURABLE_ROLES,
    }, 'Role permissions updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
}

module.exports = {
  getPaymentSettings,
  updatePaymentSettings,
  getRolePermissions,
  updateRolePermissions,
};
