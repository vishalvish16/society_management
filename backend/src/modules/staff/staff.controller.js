const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// GET /api/staff
async function listStaff(req, res) {
  try {
    const { societyId } = req.user;
    const { isActive, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (isActive !== undefined) where.isActive = isActive === 'true';

    const [staff, total] = await Promise.all([
      prisma.staff.findMany({
        where,
        skip,
        take: parseInt(limit),
        orderBy: { name: 'asc' },
        include: {
          attendance: {
            orderBy: { date: 'desc' },
            take: 1,
          },
          user: { select: { id: true, phone: true, role: true, isActive: true } },
        },
      }),
      prisma.staff.count({ where }),
    ]);

    return sendSuccess(res, { staff, total, page: parseInt(page), limit: parseInt(limit) }, 'Staff retrieved');
  } catch (err) {
    console.error('List staff error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff
async function createStaff(req, res) {
  try {
    const { societyId, id: createdById } = req.user;
    const { name, role, phone, salary, joiningDate, password } = req.body;

    if (!name || !role || salary === undefined) {
      return sendError(res, 'name, role, and salary are required', 400);
    }

    // Watchman: also create a User account so they can log into the app
    let userId = null;
    if (role === 'watchman') {
      if (!phone) return sendError(res, 'Phone is required for watchman login', 400);
      if (!password || password.length < 6) {
        return sendError(res, 'Password (min 6 chars) is required for watchman login', 400);
      }

      const existing = await prisma.user.findFirst({ where: { phone, societyId } });
      if (existing) return sendError(res, 'A user with this phone already exists in this society', 409);

      const bcrypt = require('bcrypt');
      const passwordHash = await bcrypt.hash(password, 12);
      const newUser = await prisma.user.create({
        data: {
          societyId,
          role: 'WATCHMAN',
          name,
          phone,
          passwordHash,
          createdById,
        },
      });
      userId = newUser.id;
    }

    const staff = await prisma.staff.create({
      data: {
        societyId,
        name,
        role,
        phone: phone || null,
        salary: Number(salary),
        joiningDate: joiningDate ? new Date(joiningDate) : null,
        ...(userId ? { userId } : {}),
      },
      include: { user: { select: { id: true, phone: true, role: true, isActive: true } } },
    });

    return sendSuccess(res, staff, 'Staff member created', 201);
  } catch (err) {
    console.error('Create staff error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// PATCH /api/staff/:id
async function updateStaff(req, res) {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const existing = await prisma.staff.findUnique({ where: { id } });
    if (!existing || existing.societyId !== societyId) {
      return sendError(res, 'Staff member not found', 404);
    }

    const { name, role, phone, salary, joiningDate, isActive } = req.body;
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (role !== undefined) updateData.role = role;
    if (phone !== undefined) updateData.phone = phone;
    if (salary !== undefined) updateData.salary = Number(salary);
    if (joiningDate !== undefined) updateData.joiningDate = new Date(joiningDate);
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);

    const updated = await prisma.staff.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Staff member updated');
  } catch (err) {
    console.error('Update staff error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// DELETE /api/staff/:id  (soft-delete)
async function deleteStaff(req, res) {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const existing = await prisma.staff.findUnique({ where: { id } });
    if (!existing || existing.societyId !== societyId) {
      return sendError(res, 'Staff member not found', 404);
    }

    await prisma.staff.update({ where: { id }, data: { isActive: false } });
    return sendSuccess(res, null, 'Staff member deactivated');
  } catch (err) {
    console.error('Delete staff error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff/:id/attendance
async function markAttendance(req, res) {
  try {
    const { societyId, id: markedById } = req.user;
    const { id: staffId } = req.params;
    const { date, status } = req.body;

    if (!date || !status) {
      return sendError(res, 'date and status are required', 400);
    }

    const validStatuses = ['present', 'absent', 'half_day', 'leave'];
    if (!validStatuses.includes(status)) {
      return sendError(res, `Status must be one of: ${validStatuses.join(', ')}`, 400);
    }

    const staff = await prisma.staff.findUnique({ where: { id: staffId } });
    if (!staff || staff.societyId !== societyId) {
      return sendError(res, 'Staff member not found', 404);
    }

    const attendance = await prisma.staffAttendance.upsert({
      where: { staffId_date: { staffId, date: new Date(date) } },
      update: { status: status.toUpperCase(), markedById, markedAt: new Date() },
      create: { staffId, date: new Date(date), status: status.toUpperCase(), markedById },
    });

    return sendSuccess(res, attendance, 'Attendance marked');
  } catch (err) {
    console.error('Mark attendance error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// GET /api/staff/:id/attendance
async function getAttendance(req, res) {
  try {
    const { societyId } = req.user;
    const { id: staffId } = req.params;
    const { month } = req.query;

    const staff = await prisma.staff.findUnique({ where: { id: staffId } });
    if (!staff || staff.societyId !== societyId) {
      return sendError(res, 'Staff member not found', 404);
    }

    const where = { staffId };
    if (month) {
      const d = new Date(month);
      where.date = {
        gte: new Date(d.getFullYear(), d.getMonth(), 1),
        lte: new Date(d.getFullYear(), d.getMonth() + 1, 0),
      };
    }

    const records = await prisma.staffAttendance.findMany({
      where,
      orderBy: { date: 'asc' },
    });

    return sendSuccess(res, records, 'Attendance records retrieved');
  } catch (err) {
    console.error('Get attendance error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff/:id/reset-password  — set or reset watchman's app login password
async function resetWatchmanPassword(req, res) {
  try {
    const { societyId, id: actorId } = req.user;
    const { id } = req.params;
    const { password } = req.body;

    if (!password || password.length < 6) {
      return sendError(res, 'Password must be at least 6 characters', 400);
    }

    const staff = await prisma.staff.findUnique({ where: { id }, include: { user: true } });
    if (!staff || staff.societyId !== societyId) return sendError(res, 'Staff not found', 404);

    const bcrypt = require('bcrypt');
    const passwordHash = await bcrypt.hash(password, 12);

    if (staff.userId) {
      // Already has an account — just update the password
      await prisma.user.update({ where: { id: staff.userId }, data: { passwordHash } });
    } else {
      // No account yet — create one and link it
      if (!staff.phone) return sendError(res, 'Staff has no phone number — edit the staff record to add a phone first', 400);

      const existing = await prisma.user.findFirst({ where: { phone: staff.phone, societyId } });
      if (existing) return sendError(res, 'A user with this phone already exists in this society', 409);

      const newUser = await prisma.user.create({
        data: {
          societyId,
          role: 'WATCHMAN',
          name: staff.name,
          phone: staff.phone,
          passwordHash,
          createdById: actorId,
        },
      });
      await prisma.staff.update({ where: { id }, data: { userId: newUser.id } });
    }

    return sendSuccess(res, null, 'Password set successfully');
  } catch (err) {
    console.error('Reset watchman password error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = { listStaff, createStaff, updateStaff, deleteStaff, markAttendance, getAttendance, resetWatchmanPassword };
