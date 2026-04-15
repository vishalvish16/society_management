const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// GET /api/moverequests
exports.getAllMoveRequests = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { type, status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (type) where.type = type;
    if (status) where.status = status;

    const [moveRequests, total] = await Promise.all([
      prisma.moveRequest.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: { unit: { select: { fullCode: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.moveRequest.count({ where }),
    ]);

    return sendSuccess(res, { moveRequests, total, page: parseInt(page), limit: parseInt(limit) }, 'Move requests retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// POST /api/moverequests
exports.createMoveRequest = async (req, res) => {
  try {
    const { societyId, id: requestedById } = req.user;
    const { unitId, type, residentName, residentPhone, residentEmail, residentType, expectedDate, memberCount, vehicleNumbers } = req.body;

    if (!unitId || !type || !residentName || !residentPhone) {
      return sendError(res, 'unitId, type, residentName, residentPhone are required', 400);
    }

    if (!['move_in', 'move_out'].includes(type)) {
      return sendError(res, 'type must be move_in or move_out', 400);
    }

    const unit = await prisma.unit.findUnique({ where: { id: unitId } });
    if (!unit || unit.societyId !== societyId) {
      return sendError(res, 'Unit not found in your society', 404);
    }

    const moveRequest = await prisma.moveRequest.create({
      data: {
        societyId,
        unitId,
        requestedById,
        type,
        residentName,
        residentPhone,
        residentEmail: residentEmail || null,
        residentType: residentType || 'tenant',
        expectedDate: expectedDate ? new Date(expectedDate) : null,
        memberCount: memberCount ? parseInt(memberCount) : null,
        vehicleNumbers: vehicleNumbers || null,
      },
    });

    return sendSuccess(res, moveRequest, 'Move request submitted', 201);
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/moverequests/:id
exports.updateMoveRequest = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { status, pendingDues, nocIssuedAt } = req.body;

    const moveRequest = await prisma.moveRequest.findUnique({ where: { id } });
    if (!moveRequest || moveRequest.societyId !== societyId) {
      return sendError(res, 'Move request not found', 404);
    }

    const updateData = {};
    if (status) updateData.status = status;
    if (pendingDues !== undefined) updateData.pendingDues = pendingDues;
    if (nocIssuedAt) { updateData.nocIssuedAt = new Date(nocIssuedAt); updateData.nocIssuedById = req.user.id; }

    const updated = await prisma.moveRequest.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Move request updated');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// DELETE /api/moverequests/:id
exports.deleteMoveRequest = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const moveRequest = await prisma.moveRequest.findUnique({ where: { id } });
    if (!moveRequest || moveRequest.societyId !== societyId) {
      return sendError(res, 'Move request not found', 404);
    }

    await prisma.moveRequest.delete({ where: { id } });
    return sendSuccess(res, null, 'Move request deleted');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// GET /api/moverequests/mine
exports.getMyMoveRequests = async (req, res) => {
  try {
    const { societyId, id: userId } = req.user;
    const requests = await prisma.moveRequest.findMany({
      where: { societyId, requestedById: userId },
      include: { unit: { select: { fullCode: true } } },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, requests, 'Your move requests retrieved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/moverequests/:id/check-dues
exports.checkDues = async (req, res) => {
  try {
    const { societyId, id: checkedById } = req.user;
    const { id } = req.params;
    const { pendingDues } = req.body;

    const mr = await prisma.moveRequest.findUnique({ where: { id } });
    if (!mr || mr.societyId !== societyId) return sendError(res, 'Move request not found', 404);

    const updated = await prisma.moveRequest.update({
      where: { id },
      data: { pendingDues: pendingDues !== undefined ? Number(pendingDues) : mr.pendingDues, status: 'DUES_CLEARED' },
    });
    return sendSuccess(res, updated, 'Dues checked');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/moverequests/:id/issue-noc
exports.issueNoc = async (req, res) => {
  try {
    const { societyId, id: nocIssuedById } = req.user;
    const { id } = req.params;

    const mr = await prisma.moveRequest.findUnique({ where: { id } });
    if (!mr || mr.societyId !== societyId) return sendError(res, 'Move request not found', 404);
    if (Number(mr.pendingDues || 0) > 0) return sendError(res, 'Cannot issue NOC with pending dues', 400);

    const updated = await prisma.moveRequest.update({
      where: { id },
      data: { nocIssuedAt: new Date(), nocIssuedById },
    });
    return sendSuccess(res, updated, 'NOC issued');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/moverequests/:id/approve
exports.approveMoveRequest = async (req, res) => {
  try {
    const { societyId, id: approvedById } = req.user;
    const { id } = req.params;

    const mr = await prisma.moveRequest.findUnique({ where: { id } });
    if (!mr || mr.societyId !== societyId) return sendError(res, 'Move request not found', 404);

    const updated = await prisma.moveRequest.update({
      where: { id },
      data: { status: 'APPROVED', approvedAt: new Date(), approvedById },
    });
    return sendSuccess(res, updated, 'Move request approved');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/moverequests/:id/reject
exports.rejectMoveRequest = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { rejectionReason } = req.body;

    const mr = await prisma.moveRequest.findUnique({ where: { id } });
    if (!mr || mr.societyId !== societyId) return sendError(res, 'Move request not found', 404);

    const updated = await prisma.moveRequest.update({
      where: { id },
      data: { status: 'REJECTED', rejectionReason: rejectionReason || null },
    });
    return sendSuccess(res, updated, 'Move request rejected');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};

// PATCH /api/moverequests/:id/complete
exports.completeMoveRequest = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const mr = await prisma.moveRequest.findUnique({ where: { id }, include: { unit: true } });
    if (!mr || mr.societyId !== societyId) return sendError(res, 'Move request not found', 404);

    // Update move request + update unit status if move_out
    await prisma.$transaction(async (tx) => {
      await tx.moveRequest.update({ where: { id }, data: { status: 'COMPLETED', completedAt: new Date() } });
      if (mr.type === 'move_out') {
        await tx.unit.update({ where: { id: mr.unitId }, data: { status: 'VACANT' } });
      } else if (mr.type === 'move_in') {
        await tx.unit.update({ where: { id: mr.unitId }, data: { status: 'OCCUPIED' } });
      }
    });

    return sendSuccess(res, { id, status: 'COMPLETED' }, 'Move request completed');
  } catch (error) {
    return sendError(res, error.message, 500);
  }
};
