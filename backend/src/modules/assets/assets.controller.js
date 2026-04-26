const assetsService = require('./assets.service');
const { sendSuccess, sendError } = require('../../utils/response');

async function listAssets(req, res) {
  try {
    const result = await assetsService.listAssets(req.user.societyId, req.query);
    return sendSuccess(res, result, 'Assets retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getAsset(req, res) {
  try {
    const asset = await assetsService.getAssetById(req.params.id, req.user.societyId);
    if (!asset) return sendError(res, 'Asset not found', 404);
    return sendSuccess(res, asset, 'Asset retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function createAsset(req, res) {
  try {
    const { name, category } = req.body;
    if (!name || !category) {
      return sendError(res, 'Name and category are required', 400);
    }
    const asset = await assetsService.createAsset(
      req.user.id, req.user.societyId, req.body, req.files || []
    );
    return sendSuccess(res, asset, 'Asset created', 201);
  } catch (error) {
    if (error.code === 'P2002') {
      return sendError(res, 'An asset with this tag already exists in your society', 409);
    }
    return sendError(res, error.message, error.status || 500);
  }
}

async function updateAsset(req, res) {
  try {
    const asset = await assetsService.updateAsset(
      req.params.id, req.user.societyId, req.body, req.files || []
    );
    return sendSuccess(res, asset, 'Asset updated');
  } catch (error) {
    if (error.code === 'P2002') {
      return sendError(res, 'An asset with this tag already exists in your society', 409);
    }
    return sendError(res, error.message, error.status || 500);
  }
}

async function deleteAsset(req, res) {
  try {
    await assetsService.deleteAsset(req.params.id, req.user.societyId);
    return sendSuccess(res, null, 'Asset deleted');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function deleteAttachment(req, res) {
  try {
    await assetsService.deleteAttachment(req.params.attachmentId, req.user.societyId);
    return sendSuccess(res, null, 'Attachment deleted');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function addMaintenanceLog(req, res) {
  try {
    const { title } = req.body;
    if (!title) return sendError(res, 'Title is required', 400);
    const log = await assetsService.addMaintenanceLog(
      req.params.id, req.user.id, req.user.societyId, req.body
    );
    return sendSuccess(res, log, 'Maintenance log added', 201);
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getSummary(req, res) {
  try {
    const summary = await assetsService.getAssetSummary(req.user.societyId);
    return sendSuccess(res, summary, 'Asset summary retrieved');
  } catch (error) {
    return sendError(res, error.message, error.status || 500);
  }
}

async function getCategories(_req, res) {
  return sendSuccess(res, assetsService.ASSET_CATEGORIES, 'Categories retrieved');
}

module.exports = {
  listAssets,
  getAsset,
  createAsset,
  updateAsset,
  deleteAsset,
  deleteAttachment,
  addMaintenanceLog,
  getSummary,
  getCategories,
};
