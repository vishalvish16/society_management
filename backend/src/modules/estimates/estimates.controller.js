const estimatesService = require('./estimates.service');
const { sendSuccess, sendError } = require('../../utils/response');

async function listEstimates(req, res, next) {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const result = await estimatesService.listEstimates({
      status, search,
      page: parseInt(page, 10),
      limit: Math.min(parseInt(limit, 10) || 20, 100),
    });
    return sendSuccess(res, result, 'Estimates retrieved');
  } catch (err) { next(err); }
}

async function getEstimate(req, res, next) {
  try {
    const estimate = await estimatesService.getEstimateById(req.params.id);
    if (!estimate) return sendError(res, 'Estimate not found', 404);
    return sendSuccess(res, estimate, 'Estimate retrieved');
  } catch (err) { next(err); }
}

async function createEstimate(req, res, next) {
  try {
    const { planId, unitCount, duration } = req.body;
    if (!planId || !unitCount) return sendError(res, 'planId and unitCount are required', 400);
    const estimate = await estimatesService.createEstimate({ ...req.body, createdById: req.user?.id });
    return sendSuccess(res, estimate, 'Estimate created', 201);
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function updateEstimate(req, res, next) {
  try {
    const estimate = await estimatesService.updateEstimate(req.params.id, req.body);
    return sendSuccess(res, estimate, 'Estimate updated');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function sendEstimate(req, res, next) {
  try {
    const estimate = await estimatesService.sendEstimate(req.params.id);
    return sendSuccess(res, estimate, 'Estimate marked as sent');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function acceptEstimate(req, res, next) {
  try {
    const estimate = await estimatesService.acceptEstimate(req.params.id);
    return sendSuccess(res, estimate, 'Estimate accepted');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function closeEstimate(req, res, next) {
  try {
    const { closeReason, status: targetStatus } = req.body;
    const estimate = await estimatesService.closeEstimate(req.params.id, {
      closeReason, targetStatus,
    });
    return sendSuccess(res, estimate, 'Estimate closed');
  } catch (err) {
    if (err.status) return sendError(res, err.message, err.status);
    next(err);
  }
}

async function getAcceptedUnlinked(req, res, next) {
  try {
    const estimates = await estimatesService.getAcceptedUnlinked();
    return sendSuccess(res, estimates, 'Accepted estimates retrieved');
  } catch (err) { next(err); }
}

module.exports = {
  listEstimates, getEstimate, createEstimate, updateEstimate,
  sendEstimate, acceptEstimate, closeEstimate, getAcceptedUnlinked,
};
