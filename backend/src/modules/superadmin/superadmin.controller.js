const superadminService = require('./superadmin.service');
const { sendSuccess } = require('../../utils/response');

async function getDashboard(req, res, next) {
  try {
    const stats = await superadminService.getDashboardStats();
    return sendSuccess(res, stats, 'Dashboard stats retrieved');
  } catch (err) {
    next(err);
  }
}

async function getRevenue(req, res, next) {
  try {
    const { period = '6m' } = req.query;
    const trends = await superadminService.getRevenueTrends(period);
    return sendSuccess(res, trends, 'Revenue trends retrieved');
  } catch (err) {
    next(err);
  }
}

async function getRecentSocieties(req, res, next) {
  try {
    const societies = await superadminService.getRecentSocieties();
    return sendSuccess(res, societies, 'Recent societies retrieved');
  } catch (err) {
    next(err);
  }
}

// ─── Platform Settings ────────────────────────────────────────────────────────

/**
 * GET /api/superadmin/settings
 * Returns all platform-wide settings.
 */
async function getSettings(req, res, next) {
  try {
    const settings = await superadminService.getAllSettings();
    return sendSuccess(res, settings, 'Platform settings retrieved');
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/superadmin/settings/:key
 * Update a single platform setting.
 * Body: { value: string|number }
 */
async function updateSetting(req, res, next) {
  try {
    const { key } = req.params;
    const { value } = req.body;

    if (value === undefined || value === null || String(value).trim() === '') {
      const { sendError } = require('../../utils/response');
      return sendError(res, 'value is required', 400);
    }

    // For visitor_qr_max_hrs: validate it's a positive integer ≥ 1
    if (key === 'visitor_qr_max_hrs') {
      const n = parseInt(value, 10);
      if (!Number.isFinite(n) || n < 1) {
        const { sendError } = require('../../utils/response');
        return sendError(res, 'visitor_qr_max_hrs must be a positive integer', 400);
      }
    }

    const updated = await superadminService.updateSetting(key, value, req.user.id);
    return sendSuccess(res, updated, 'Setting updated');
  } catch (err) {
    next(err);
  }
}

module.exports = { getDashboard, getRevenue, getRecentSocieties, getSettings, updateSetting };
