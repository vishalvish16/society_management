const societiesService = require('./societies.service');
const { sendSuccess, sendError } = require('../../utils/response');
const { getVisitorQrMaxHrs } = require('../../utils/platformSettings');

async function listSocieties(req, res, next) {
  try {
    const { page = 1, limit = 20, search, status } = req.query;
    const result = await societiesService.listSocieties({
      page: parseInt(page, 10),
      limit: Math.min(parseInt(limit, 10) || 20, 100),
      search,
      status,
    });
    return sendSuccess(res, result, 'Societies retrieved');
  } catch (err) {
    next(err);
  }
}

async function getSociety(req, res, next) {
  try {
    const society = await societiesService.getSocietyById(req.params.id);
    if (!society) return sendError(res, 'Society not found', 404);
    return sendSuccess(res, society, 'Society retrieved');
  } catch (err) {
    next(err);
  }
}

async function _validateSocietySettings(settings) {
  if (!settings) return;
  const { visitor_qr_max_hrs } = settings;
  if (visitor_qr_max_hrs !== undefined) {
    const n = parseInt(visitor_qr_max_hrs, 10);
    if (!isNaN(n)) {
      const platformMax = await getVisitorQrMaxHrs();
      if (n > platformMax) {
        throw Object.assign(
          new Error(`Society Max QR Expiry cannot exceed Platform limit of ${platformMax} hours`),
          { status: 400 }
        );
      }
    }
  }
}

async function createSociety(req, res, next) {
  try {
    const { name, address, city, contactPhone, contactEmail, planName, chairman, trialDays, settings, estimateId } = req.body;

    if (!name) return sendError(res, 'Society name is required', 400);

    if (chairman) {
      if (!chairman.name || !chairman.phone || !chairman.password) {
        return sendError(res, 'Chairman name, phone, and password are required', 400);
      }
      if (chairman.password.length < 8) {
        return sendError(res, 'Password must be at least 8 characters', 400);
      }
    }

    if (settings) {
      await _validateSocietySettings(settings);
    }

    const result = await societiesService.createSociety({
      name, address, city, contactPhone, contactEmail, planName, chairman, trialDays, settings,
    });

    // If created from an estimate, link it (auto-accepts and records society link)
    if (estimateId && result.society?.id) {
      try {
        const { linkEstimateToSociety } = require('../estimates/estimates.service');
        await linkEstimateToSociety(estimateId, result.society.id);
      } catch (linkErr) {
        // Non-fatal: society already created; just log the link failure
        console.error('[estimate-link]', linkErr.message);
      }
    }

    return sendSuccess(res, result, 'Society created successfully', 201);
  } catch (err) {
    if (err.code === 'P2002') {
      const field = err.meta?.target?.[0] || 'field';
      return sendError(res, `A society with this ${field} already exists`, 409);
    }
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function updateSociety(req, res, next) {
  try {
    console.log('[DEBUG] Update Society Request Body:', req.body);
    if (req.body.settings) {
      await _validateSocietySettings(req.body.settings);
    }
    const society = await societiesService.updateSociety(req.params.id, req.body);
    return sendSuccess(res, society, 'Society updated');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Society not found', 404);
    if (err.code === 'P2002') return sendError(res, 'A society with this name already exists', 409);
    next(err);
  }
}

async function deactivateSociety(req, res, next) {
  try {
    const result = await societiesService.deactivateSociety(req.params.id);
    return sendSuccess(res, result, 'Society deactivated');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Society not found', 404);
    next(err);
  }
}

module.exports = { listSocieties, getSociety, createSociety, updateSociety, deactivateSociety, toggleSocietyStatus, resetChairmanPassword, upsertChairman, getSocietySettings, updateSocietySettings };

async function toggleSocietyStatus(req, res, next) {
  try {
    const result = await societiesService.toggleSocietyStatus(req.params.id);
    return sendSuccess(res, result, `Society ${result.status}`);
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function resetChairmanPassword(req, res, next) {
  try {
    const { password, name, mode } = req.body;
    const result = await societiesService.resetChairmanPassword(req.params.id, password, name, mode);
    return sendSuccess(res, result, 'Chairman updated successfully');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function getSocietySettings(req, res, next) {
  try {
    const society = await societiesService.getSocietyById(req.params.id);
    if (!society) return sendError(res, 'Society not found', 404);
    return sendSuccess(res, society.settings ?? {}, 'Society settings retrieved');
  } catch (err) {
    next(err);
  }
}

async function updateSocietySettings(req, res, next) {
  try {
    const { visitor_qr_max_hrs } = req.body;
    const patch = {};

    if (visitor_qr_max_hrs !== undefined) {
      const n = parseInt(visitor_qr_max_hrs, 10);
      if (isNaN(n) || n < 1) return sendError(res, 'visitor_qr_max_hrs must be a positive integer', 400);
      patch.visitor_qr_max_hrs = String(n);
    }

    // Merge with existing settings
    const existing = await societiesService.getSocietyById(req.params.id);
    if (!existing) return sendError(res, 'Society not found', 404);

    const merged = { ...(existing.settings ?? {}), ...patch };

    // Validate merged settings
    await _validateSocietySettings(merged);

    const updated = await societiesService.updateSociety(req.params.id, { settings: merged });
    return sendSuccess(res, updated.settings ?? {}, 'Society settings updated');
  } catch (err) {
    next(err);
  }
}

async function upsertChairman(req, res, next) {
  try {
    const { name, phone, email, password } = req.body;
    if (!name || !phone) return sendError(res, 'Chairman name and phone are required', 400);
    if (password && password.length < 8) {
      return sendError(res, 'Password must be at least 8 characters', 400);
    }
    const result = await societiesService.upsertSocietyChairman(req.params.id, {
      name,
      phone,
      email,
      password,
    });
    return sendSuccess(res, result, 'Chairman saved');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}
