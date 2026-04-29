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

// ─── App Info ─────────────────────────────────────────────────────────────────

const APP_INFO_KEYS = ['app_name', 'app_tagline', 'app_version', 'app_support_email', 'app_support_phone', 'terms_and_conditions'];

/**
 * GET /api/superadmin/app-info
 * Returns all editable app info fields for the SA editor.
 */
async function getAppInfoSettings(req, res, next) {
  try {
    const { getAppInfo } = require('../../utils/platformSettings');
    const info = await getAppInfo();
    return sendSuccess(res, info, 'App info retrieved');
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/superadmin/app-info
 * Body: { appName, appTagline, appVersion, supportEmail, supportPhone, termsAndConditions }
 * Updates all app info platform settings in one request.
 */
async function updateAppInfo(req, res, next) {
  try {
    const { sendError } = require('../../utils/response');
    const { updateSetting } = require('../../utils/platformSettings');

    const fieldMap = {
      appName:            'app_name',
      appTagline:         'app_tagline',
      appVersion:         'app_version',
      supportEmail:       'app_support_email',
      supportPhone:       'app_support_phone',
      termsAndConditions: 'terms_and_conditions',
    };

    const updates = [];
    for (const [bodyKey, dbKey] of Object.entries(fieldMap)) {
      if (req.body[bodyKey] !== undefined) {
        updates.push(updateSetting(dbKey, String(req.body[bodyKey]), req.user.id));
      }
    }

    if (updates.length === 0) {
      return sendError(res, 'No fields provided', 400);
    }

    await Promise.all(updates);
    const { getAppInfo } = require('../../utils/platformSettings');
    const info = await getAppInfo();
    return sendSuccess(res, info, 'App info updated');
  } catch (err) {
    next(err);
  }
}

module.exports = { getDashboard, getRevenue, getRecentSocieties, getSettings, updateSetting, getAppInfoSettings, updateAppInfo };
