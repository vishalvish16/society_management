const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const bcrypt = require('bcrypt');
const { SALT_ROUNDS } = require('../../config/constants');

const UNIT_LOCKED_ROLES = new Set(['MEMBER', 'RESIDENT', 'VICE_CHAIRMAN', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']);

const getMembers = async (req, res) => {
  try {
    const { societyId, id: requesterId, role: requesterRole } = req.user;
    const { role, page = 1, limit = 20, isActive } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId, role: { not: 'SUPER_ADMIN' }, deletedAt: null };
    if (role) where.role = role;
    if (isActive !== undefined) where.isActive = isActive === 'true';

    // If the requester is a unit-locked role, restrict to their own unit only
    if (UNIT_LOCKED_ROLES.has(requesterRole)) {
      // Find the unitId for the requesting user
      const unitResident = await prisma.unitResident.findFirst({
        where: { userId: requesterId },
        select: { unitId: true },
      });
      if (unitResident?.unitId) {
        where.unitResidents = { some: { unitId: unitResident.unitId } };
      } else {
        // User has no unit assigned — return empty
        return sendSuccess(res, { members: [], total: 0, page: parseInt(page), limit: parseInt(limit) }, 'Members retrieved');
      }
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: parseInt(limit),
        select: {
          id: true, name: true, email: true, phone: true, role: true, isActive: true, createdAt: true,
          unitResidents: { select: { unit: { select: { id: true, fullCode: true } }, isOwner: true } },
        },
        orderBy: { name: 'asc' },
      }),
      prisma.user.count({ where }),
    ]);

    return sendSuccess(res, { members: users, total, page: parseInt(page), limit: parseInt(limit) }, 'Members retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const createMember = async (req, res) => {
  try {
    const { societyId, id: requesterId, role: requesterRole } = req.user;
    let { name, phone, email, password, role = 'RESIDENT', unitId } = req.body;

    if (!name || !phone || !password) return sendError(res, 'name, phone and password are required', 400);

    // Unit-locked roles can only add MEMBER or RESIDENT to their own unit
    if (UNIT_LOCKED_ROLES.has(requesterRole)) {
      const allowedRoles = ['MEMBER', 'RESIDENT'];
      if (!allowedRoles.includes(role)) {
        return sendError(res, 'You can only add members with role MEMBER or RESIDENT', 403);
      }
      // Always use the requester's own unit — ignore what the client sent
      const unitResident = await prisma.unitResident.findFirst({
        where: { userId: requesterId },
        select: { unitId: true },
      });
      if (!unitResident?.unitId) {
        return sendError(res, 'You have no unit assigned. Contact your administrator.', 403);
      }
      unitId = unitResident.unitId;
    }

    const existing = await prisma.user.findFirst({
      where: { OR: [{ phone }, ...(email ? [{ email }] : [])] },
    });
    if (existing) return sendError(res, 'Phone or email already registered', 409);

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: { societyId, name, phone, email: email || null, passwordHash, role },
        select: { id: true, name: true, phone: true, email: true, role: true, societyId: true },
      });

      if (unitId) {
        await tx.unitResident.create({
          data: { unitId, userId: user.id, isOwner: role === 'PRAMUKH' || role === 'CHAIRMAN' || role === 'RESIDENT' },
        });
        // Update unit status to occupied
        await tx.unit.update({
          where: { id: unitId },
          data: { status: 'OCCUPIED' },
        });
      }
      return user;
    });

    return sendSuccess(res, result, 'Member created', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const updateMember = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { name, email, phone, isActive, unitId } = req.body;

    const member = await prisma.user.findUnique({ where: { id } });
    if (!member || member.societyId !== societyId) return sendError(res, 'Member not found', 404);

    const updateData = {};
    if (name) updateData.name = name;
    if (email) updateData.email = email;
    if (phone) updateData.phone = phone;
    if (isActive !== undefined) updateData.isActive = isActive;

    const result = await prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id },
        data: updateData,
        select: { id: true, name: true, phone: true, email: true, role: true },
      });

      if (unitId) {
        // Simple logic: delete old linked units and link new one 
        // (or upsert if we want to support only one link per member in this UI)
        await tx.unitResident.deleteMany({ where: { userId: id } });
        await tx.unitResident.create({
          data: { unitId, userId: id, isOwner: updated.role === 'PRAMUKH' || role === 'CHAIRMAN' || updated.role === 'RESIDENT' },
        });
        // Ensure unit is marked as occupied
        await tx.unit.update({
          where: { id: unitId },
          data: { status: 'OCCUPIED' },
        });
      }
      return updated;
    });

    return sendSuccess(res, result, 'Member updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const deleteMember = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const member = await prisma.user.findUnique({ where: { id } });
    if (!member || member.societyId !== societyId) return sendError(res, 'Member not found', 404);

    await prisma.user.update({
      where: { id },
      data: { isActive: false, deletedAt: new Date() },
    });
    return sendSuccess(res, null, 'Member deactivated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const resetPassword = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { password } = req.body;

    if (!password || password.length < 6) {
      return sendError(res, 'Password must be at least 6 characters', 400);
    }

    const member = await prisma.user.findUnique({ where: { id } });
    if (!member || member.societyId !== societyId) {
      return sendError(res, 'Member not found', 404);
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    await prisma.user.update({
      where: { id },
      data: { passwordHash },
    });

    return sendSuccess(res, null, 'Password reset successful');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { getMembers, createMember, updateMember, deleteMember, resetPassword };
