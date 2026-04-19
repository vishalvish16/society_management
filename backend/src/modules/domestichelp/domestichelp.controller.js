const prisma = require('../../config/db');
const service = require('./domestichelp.service');
const { sendSuccess, sendError } = require('../../utils/response');
const { isResidentLikeRole, canViewAllDomesticHelp, unitIdsForUser, userHasUnit } = require('../../utils/unitResident');

async function list(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const query = { ...req.query };
    if (!canViewAllDomesticHelp(role)) {
      const ids = await unitIdsForUser(userId, societyId);
      if (!ids.length) {
        return sendSuccess(
          res,
          { items: [], total: 0, page: parseInt(query.page) || 1, limit: parseInt(query.limit) || 20 },
          'Domestic help retrieved'
        );
      }
      if (query.unitId && !ids.includes(query.unitId)) {
        return sendError(res, 'You can only view domestic help for your own unit', 403);
      }
      query.unitIdsIn = query.unitId ? [query.unitId] : ids;
    }
    const result = await service.listDomesticHelp(societyId, query);
    return sendSuccess(res, result, 'Domestic help retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function create(req, res) {
  try {
    const data = { ...req.body };
    if (req.file) {
      data.photoUrl = `/uploads/domestichelp/${req.file.filename}`;
    }
    if (isResidentLikeRole(req.user.role)) {
      if (!data.unitId) {
        return sendError(res, 'unitId is required', 400);
      }
      const ok = await userHasUnit(req.user.id, req.user.societyId, data.unitId);
      if (!ok) {
        return sendError(res, 'You can only register domestic help for your own unit', 403);
      }
    }
    const item = await service.createDomesticHelp(req.user.societyId, req.user.id, data);
    return sendSuccess(res, item, 'Domestic help registered', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function update(req, res) {
  try {
    const data = { ...req.body };
    if (req.file) {
      data.photoUrl = `/uploads/domestichelp/${req.file.filename}`;
    }
    if (isResidentLikeRole(req.user.role)) {
      const existing = await prisma.domesticHelp.findUnique({ where: { id: req.params.id } });
      if (!existing || existing.societyId !== req.user.societyId) {
        return sendError(res, 'Domestic help not found', 404);
      }
      const ok = await userHasUnit(req.user.id, req.user.societyId, existing.unitId);
      if (!ok) {
        return sendError(res, 'You can only update domestic help for your own unit', 403);
      }
    }
    const updated = await service.updateDomesticHelp(req.params.id, req.user.societyId, data);
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
    if (isResidentLikeRole(req.user.role)) {
      const existing = await prisma.domesticHelp.findUnique({ where: { id: req.params.id } });
      if (!existing || existing.societyId !== req.user.societyId) {
        return sendError(res, 'Domestic help not found', 404);
      }
      const ok = await userHasUnit(req.user.id, req.user.societyId, existing.unitId);
      if (!ok) {
        return sendError(res, 'You can only change domestic help for your own unit', 403);
      }
    }
    const updated = await service.updateDomesticHelp(req.params.id, req.user.societyId, { status: 'SUSPENDED' });
    return sendSuccess(res, updated, 'Domestic help suspended');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function remove(req, res) {
  try {
    if (isResidentLikeRole(req.user.role)) {
      const existing = await prisma.domesticHelp.findUnique({ where: { id: req.params.id } });
      if (!existing || existing.societyId !== req.user.societyId) {
        return sendError(res, 'Domestic help not found', 404);
      }
      const ok = await userHasUnit(req.user.id, req.user.societyId, existing.unitId);
      if (!ok) {
        return sendError(res, 'You can only change domestic help for your own unit', 403);
      }
    }
    const updated = await service.updateDomesticHelp(req.params.id, req.user.societyId, { status: 'REMOVED' });
    return sendSuccess(res, updated, 'Domestic help removed');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function getLogs(req, res) {
  try {
    if (isResidentLikeRole(req.user.role)) {
      const existing = await prisma.domesticHelp.findUnique({ where: { id: req.params.id } });
      if (!existing || existing.societyId !== req.user.societyId) {
        return sendError(res, 'Domestic help not found', 404);
      }
      const ok = await userHasUnit(req.user.id, req.user.societyId, existing.unitId);
      if (!ok) {
        return sendError(res, 'You can only view logs for your own unit', 403);
      }
    }
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
    const { societyId, id: userId, role } = req.user;
    const { id: unitId } = req.params;

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) return sendError(res, 'Unit not found', 404);

    if (!canViewAllDomesticHelp(role)) {
      const ok = await userHasUnit(userId, societyId, unitId);
      if (!ok) return sendError(res, 'You can only view domestic help for your own unit', 403);
    }

    const helpers = await prisma.domesticHelp.findMany({
      where: { unitId, societyId, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, helpers, 'Domestic help for unit retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = { list, create, update, getByCode, logEntry, getByUnit, suspend, remove, getLogs, getTodayLogs };
