const societiesService = require('./societies.service');
const { sendSuccess, sendError } = require('../../utils/response');

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

async function createSociety(req, res, next) {
  try {
    const { name, address, city, contactPhone, contactEmail, planName, pramukh } = req.body;

    if (!name) return sendError(res, 'Society name is required', 400);

    if (pramukh) {
      if (!pramukh.name || !pramukh.phone || !pramukh.password) {
        return sendError(res, 'Pramukh name, phone, and password are required', 400);
      }
      if (pramukh.password.length < 8) {
        return sendError(res, 'Password must be at least 8 characters', 400);
      }
    }

    const result = await societiesService.createSociety({
      name, address, city, contactPhone, contactEmail, planName, pramukh,
    });
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

module.exports = { listSocieties, getSociety, createSociety, updateSociety, deactivateSociety, toggleSocietyStatus, resetSocietyPassword };

async function toggleSocietyStatus(req, res, next) {
  try {
    const result = await societiesService.toggleSocietyStatus(req.params.id);
    return sendSuccess(res, result, `Society ${result.status}`);
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function resetSocietyPassword(req, res, next) {
  try {
    const { password } = req.body;
    const result = await societiesService.resetPramukhPassword(req.params.id, password);
    return sendSuccess(res, result, 'Pramukh password reset');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}
