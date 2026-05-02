const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const {
  CONFIGURABLE_ROLES,
  ALL_FEATURES,
  FEATURE_KEYS,
  buildDefaults,
} = require('../../utils/rolePermissions');

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

/**
 * GET /api/settings/billing
 * Billing settings for the caller's society (late fee policy, etc.).
 * Accessible by all authenticated users.
 */
async function getBillingSettings(req, res) {
  try {
    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    if (!society) return sendError(res, 'Society not found', 404);

    const settings = society.settings || {};
    const billing = {
      lateFeeType: settings.late_fee_type || 'NONE', // NONE | FIXED | PER_DAY
      lateFeeAmount: settings.late_fee_amount != null ? Number(settings.late_fee_amount) : 0,
      lateFeeGraceDays: settings.late_fee_grace_days != null ? Number(settings.late_fee_grace_days) : 0,
    };

    return sendSuccess(res, billing, 'Billing settings retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
}

/**
 * PATCH /api/settings/billing
 * Admin-only: update billing settings for the society.
 * Body: { lateFeeType?, lateFeeAmount?, lateFeeGraceDays? }
 */
async function updateBillingSettings(req, res) {
  try {
    const { lateFeeType, lateFeeAmount, lateFeeGraceDays } = req.body || {};

    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    if (!society) return sendError(res, 'Society not found', 404);

    const currentSettings = society.settings || {};
    const updatedSettings = { ...currentSettings };

    if (lateFeeType !== undefined) {
      const t = String(lateFeeType || '').toUpperCase();
      const allowed = new Set(['NONE', 'FIXED', 'PER_DAY']);
      if (!allowed.has(t)) {
        return sendError(res, 'lateFeeType must be one of NONE, FIXED, PER_DAY', 400);
      }
      updatedSettings.late_fee_type = t === 'NONE' ? null : t;
    }

    if (lateFeeGraceDays !== undefined) {
      const n = Number(lateFeeGraceDays);
      if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) {
        return sendError(res, 'lateFeeGraceDays must be a non-negative integer', 400);
      }
      updatedSettings.late_fee_grace_days = n;
    }

    if (lateFeeAmount !== undefined) {
      const n = Number(lateFeeAmount);
      if (!Number.isFinite(n) || n < 0) {
        return sendError(res, 'lateFeeAmount must be a non-negative number', 400);
      }
      updatedSettings.late_fee_amount = n;
    }

    // If late fee type is NONE, keep amount/graceDays but treat as disabled.
    await prisma.society.update({
      where: { id: req.user.societyId },
      data: { settings: updatedSettings },
    });

    const billing = {
      lateFeeType: updatedSettings.late_fee_type || 'NONE',
      lateFeeAmount: updatedSettings.late_fee_amount != null ? Number(updatedSettings.late_fee_amount) : 0,
      lateFeeGraceDays: updatedSettings.late_fee_grace_days != null ? Number(updatedSettings.late_fee_grace_days) : 0,
    };

    return sendSuccess(res, billing, 'Billing settings updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
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

    // Migrate: if old CHAIRMAN data exists, treat it as PRAMUKH (they are the same role).
    const pramukhSaved = { ...(saved.CHAIRMAN || {}), ...(saved.PRAMUKH || {}) };

    const merged = {};
    for (const role of CONFIGURABLE_ROLES) {
      const roleSaved = role === 'PRAMUKH' ? pramukhSaved : (saved[role] || {});
      merged[role] = { ...defaults[role], ...roleSaved };
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
    const currentRolePermissions = currentSettings.rolePermissions || {};

    // Secretary cannot alter PRAMUKH/Chairman settings.
    if (req.user?.role === 'SECRETARY') {
      if (sanitized.PRAMUKH) sanitized.PRAMUKH = { ...(currentRolePermissions.PRAMUKH || {}) };
    }

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
  getBillingSettings,
  updateBillingSettings,
  getRolePermissions,
  updateRolePermissions,
};
