const svc = require('./donations.service');
const { sendSuccess, sendError } = require('../../utils/response');

exports.listCampaigns = async (req, res) => {
  try {
    const data = await svc.listCampaigns(req.user.societyId);
    return sendSuccess(res, data);
  } catch (e) {
    return sendError(res, 'Failed to load campaigns', 500);
  }
};

exports.createCampaign = async (req, res) => {
  try {
    const data = await svc.createCampaign(req.user.societyId, req.user.id, req.body);
    return sendSuccess(res, data, 'Campaign created', 201);
  } catch (e) {
    return sendError(res, e.message || 'Failed to create campaign', 500);
  }
};

exports.updateCampaign = async (req, res) => {
  try {
    const data = await svc.updateCampaign(req.params.id, req.user.societyId, req.body);
    return sendSuccess(res, data, 'Campaign updated');
  } catch (e) {
    return sendError(res, e.message || 'Failed to update campaign', 500);
  }
};

exports.listDonations = async (req, res) => {
  try {
    const { campaignId, page, limit } = req.query;
    const data = await svc.listDonations(req.user.societyId, {
      campaignId,
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 20,
    });
    return sendSuccess(res, data);
  } catch (e) {
    return sendError(res, 'Failed to load donations', 500);
  }
};

exports.makeDonation = async (req, res) => {
  try {
    const data = await svc.makeDonation(req.user.societyId, req.user.id, req.body);
    return sendSuccess(res, data, 'Donation recorded', 201);
  } catch (e) {
    return sendError(res, e.message || 'Failed to record donation', 500);
  }
};

exports.getSocietyBalance = async (req, res) => {
  try {
    const data = await svc.getSocietyBalance(req.user.societyId);
    return sendSuccess(res, data);
  } catch (e) {
    return sendError(res, 'Failed to load balance', 500);
  }
};
