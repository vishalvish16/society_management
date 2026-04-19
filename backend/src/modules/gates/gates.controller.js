const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

async function listGates(req, res) {
  try {
    const { societyId } = req.user;
    const gates = await prisma.societyGate.findMany({
      where: { societyId },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
    return sendSuccess(res, { gates }, 'Gates retrieved');
  } catch (err) {
    console.error('List gates error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

async function createGate(req, res) {
  try {
    const { societyId } = req.user;
    const { name, code, sortOrder } = req.body;
    if (!name || !String(name).trim()) {
      return sendError(res, 'name is required', 400);
    }
    const gate = await prisma.societyGate.create({
      data: {
        societyId,
        name: String(name).trim(),
        code: code != null && String(code).trim() ? String(code).trim() : null,
        sortOrder: sortOrder != null ? parseInt(sortOrder, 10) || 0 : 0,
      },
    });
    return sendSuccess(res, gate, 'Gate created', 201);
  } catch (err) {
    if (err.code === 'P2002') {
      return sendError(res, 'A gate with this name already exists in your society', 409);
    }
    console.error('Create gate error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

async function deleteGate(req, res) {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const gate = await prisma.societyGate.findUnique({ where: { id } });
    if (!gate || gate.societyId !== societyId) {
      return sendError(res, 'Gate not found', 404);
    }
    await prisma.societyGate.delete({ where: { id } });
    return sendSuccess(res, null, 'Gate removed');
  } catch (err) {
    console.error('Delete gate error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = { listGates, createGate, deleteGate };
