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

module.exports = { getDashboard, getRevenue, getRecentSocieties };
