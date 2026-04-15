const service = require('./domestichelp.service');
const { sendSuccess, sendError } = require('../../utils/response');

async function list(req, res) {
  try {
    const result = await service.listDomesticHelp(req.user.societyId, req.query);
    return sendSuccess(res, result, 'Domestic help retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function create(req, res) {
  try {
    const item = await service.createDomesticHelp(req.user.societyId, req.user.id, req.body);
    return sendSuccess(res, item, 'Domestic help registered', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function update(req, res) {
  try {
    const updated = await service.updateDomesticHelp(req.params.id, req.user.societyId, req.body);
    return sendSuccess(res, updated, 'Domestic help updated');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function getByCode(req, res) {
  try {
    const item = await service.getDomesticHelpByCode(req.params.code, req.user.societyId);
    return sendSuccess(res, item, 'Domestic help found');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function logEntry(req, res) {
  try {
    const { entryCode, type } = req.body;
    if (!entryCode || !type) return sendError(res, 'entryCode and type (entry/exit) are required', 400);
    if (!['entry', 'exit'].includes(type)) return sendError(res, 'type must be entry or exit', 400);

    const log = await service.logEntry(entryCode, req.user.id, type, req.user.societyId);
    return sendSuccess(res, log, `${type} logged successfully`);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function suspend(req, res) {
  try {
    const updated = await service.updateDomesticHelp(req.params.id, req.user.societyId, { status: 'SUSPENDED' });
    return sendSuccess(res, updated, 'Domestic help suspended');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function remove(req, res) {
  try {
    const updated = await service.updateDomesticHelp(req.params.id, req.user.societyId, { status: 'REMOVED' });
    return sendSuccess(res, updated, 'Domestic help removed');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function getLogs(req, res) {
  try {
    const result = await service.getLogs(req.params.id, req.user.societyId, req.query);
    return sendSuccess(res, result, 'Logs retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function getTodayLogs(req, res) {
  try {
    const logs = await service.getTodayLogs(req.user.societyId);
    return sendSuccess(res, logs, "Today's logs retrieved");
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function getByUnit(req, res) {
  try {
    const { societyId } = req.user;
    const { id: unitId } = req.params;
    const prisma = require('../../config/db');

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) return sendError(res, 'Unit not found', 404);

    const helpers = await prisma.domesticHelp.findMany({
      where: { unitId, societyId, isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, helpers, 'Domestic help for unit retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = { list, create, update, getByCode, logEntry, getByUnit, suspend, remove, getLogs, getTodayLogs };
