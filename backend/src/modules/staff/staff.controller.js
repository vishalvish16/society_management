const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

function parseStaffShift(raw) {
  const map = { day: 'DAY', night: 'NIGHT', full: 'FULL' };
  const k = raw == null ? 'full' : String(raw).toLowerCase();
  return map[k] || 'FULL';
}

/** @returns {string[]|null} */
function normalizeWingCodes(raw) {
  if (raw == null) return null;
  const arr = Array.isArray(raw)
    ? raw
    : typeof raw === 'string'
      ? raw.split(/[,;\s]+/)
      : [];
  const out = [...new Set(arr.map((s) => String(s).trim()).filter(Boolean))];
  return out.length ? out : null;
}

// GET /api/staff
async function listStaff(req, res) {
  try {
    const { societyId } = req.user;
    const { isActive, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const today = _parseDateOnly(new Date());

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
            where: today ? { date: today } : undefined,
            take: 1,
          },
          user: { select: { id: true, phone: true, role: true, isActive: true } },
          gate: { select: { id: true, name: true, code: true } },
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
    const { name, role, phone, salary, joiningDate, password, shift, gateId, assignedWingCodes } = req.body;

    if (!name || !role || salary === undefined) {
      return sendError(res, 'name, role, and salary are required', 400);
    }

    const shiftEnum = parseStaffShift(shift);
    const wings = normalizeWingCodes(assignedWingCodes);
    let resolvedGateId = gateId || null;
    if (resolvedGateId) {
      const g = await prisma.societyGate.findUnique({ where: { id: resolvedGateId } });
      if (!g || g.societyId !== societyId) {
        return sendError(res, 'Invalid gate for this society', 400);
      }
    } else {
      resolvedGateId = null;
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
        shift: shiftEnum,
        gateId: resolvedGateId,
        assignedWingCodes: wings === null ? undefined : wings,
        ...(userId ? { userId } : {}),
      },
      include: {
        user: { select: { id: true, phone: true, role: true, isActive: true } },
        gate: { select: { id: true, name: true, code: true } },
      },
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

    const { name, role, phone, salary, joiningDate, isActive, shift, gateId, assignedWingCodes } = req.body;
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (role !== undefined) updateData.role = role;
    if (phone !== undefined) updateData.phone = phone;
    if (salary !== undefined) updateData.salary = Number(salary);
    if (joiningDate !== undefined) updateData.joiningDate = new Date(joiningDate);
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);
    if (shift !== undefined) updateData.shift = parseStaffShift(shift);
    if (gateId !== undefined) {
      if (gateId === null || gateId === '') {
        updateData.gateId = null;
      } else {
        const g = await prisma.societyGate.findUnique({ where: { id: gateId } });
        if (!g || g.societyId !== societyId) {
          return sendError(res, 'Invalid gate for this society', 400);
        }
        updateData.gateId = gateId;
      }
    }
    if (assignedWingCodes !== undefined) {
      updateData.assignedWingCodes = normalizeWingCodes(assignedWingCodes);
    }

    const updated = await prisma.staff.update({
      where: { id },
      data: updateData,
      include: {
        user: { select: { id: true, phone: true, role: true, isActive: true } },
        gate: { select: { id: true, name: true, code: true } },
      },
    });
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

function _normalizeAttendanceStatus(raw) {
  const v = String(raw || '').toLowerCase().trim();
  const valid = ['present', 'absent', 'half_day', 'leave'];
  if (!valid.includes(v)) return null;
  return v.toUpperCase();
}

// GET /api/staff/attendance-sheet?date=YYYY-MM-DD
async function getAttendanceSheet(req, res) {
  try {
    const { societyId } = req.user;
    const { date } = req.query;
    if (!date) return sendError(res, 'date is required (YYYY-MM-DD)', 400);
    const day = _parseDateOnly(date);
    if (!day) return sendError(res, 'Invalid date', 400);

    const staff = await prisma.staff.findMany({
      where: { societyId, isActive: true },
      orderBy: { name: 'asc' },
      include: {
        attendance: {
          where: { date: day },
          take: 1,
        },
      },
    });

    const rows = staff.map((s) => {
      const rec = (s.attendance || [])[0] || null;
      return {
        staffId: s.id,
        name: s.name,
        role: s.role,
        phone: s.phone,
        salary: Number(s.salary || 0),
        status: rec ? String(rec.status) : null,
        markedAt: rec?.markedAt || null,
      };
    });

    return sendSuccess(res, { date: day, rows }, 'Attendance sheet retrieved');
  } catch (err) {
    console.error('Get attendance sheet error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff/attendance-bulk
// body: { date: "YYYY-MM-DD", records: [{ staffId, status }] }
async function markAttendanceBulk(req, res) {
  try {
    const { societyId, id: markedById } = req.user;
    const { date, records } = req.body || {};
    if (!date) return sendError(res, 'date is required (YYYY-MM-DD)', 400);
    const day = _parseDateOnly(date);
    if (!day) return sendError(res, 'Invalid date', 400);
    if (!Array.isArray(records) || records.length === 0) {
      return sendError(res, 'records must be a non-empty array', 400);
    }

    const staffIds = [...new Set(records.map((r) => String(r.staffId || '')).filter(Boolean))];
    if (!staffIds.length) return sendError(res, 'No staffId provided in records', 400);

    const found = await prisma.staff.findMany({
      where: { id: { in: staffIds }, societyId, isActive: true },
      select: { id: true },
    });
    const allowed = new Set(found.map((s) => s.id));
    const invalidStaff = staffIds.filter((id) => !allowed.has(id));
    if (invalidStaff.length) {
      return sendError(res, 'Some staffId are invalid/inactive for this society', 400);
    }

    const normalized = records.map((r) => ({
      staffId: String(r.staffId),
      status: _normalizeAttendanceStatus(r.status),
    }));
    const bad = normalized.find((r) => !r.status);
    if (bad) return sendError(res, 'Invalid status in records', 400);

    const ops = normalized.map((r) =>
      prisma.staffAttendance.upsert({
        where: { staffId_date: { staffId: r.staffId, date: day } },
        update: { status: r.status, markedById, markedAt: new Date() },
        create: { staffId: r.staffId, date: day, status: r.status, markedById },
      })
    );

    const results = await prisma.$transaction(ops);
    return sendSuccess(res, { date: day, count: results.length }, 'Bulk attendance marked');
  } catch (err) {
    console.error('Bulk attendance error:', err.message);
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

function _monthBounds(rawMonth) {
  const d = new Date(rawMonth);
  if (Number.isNaN(d.getTime())) return null;
  const from = new Date(d.getFullYear(), d.getMonth(), 1);
  const to = new Date(d.getFullYear(), d.getMonth() + 1, 0);
  return { from, to, daysInMonth: to.getDate() };
}

function _parseDateOnly(raw) {
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function _daysBetweenInclusive(from, to) {
  const MS_PER_DAY = 24 * 60 * 60 * 1000;
  const a = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const b = new Date(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.floor((b.getTime() - a.getTime()) / MS_PER_DAY) + 1;
}

function _parseHolidayList(raw) {
  if (!raw) return new Set();
  const parts = Array.isArray(raw) ? raw : String(raw).split(/[,;\s]+/);
  const out = new Set();
  for (const p of parts) {
    const d = _parseDateOnly(String(p).trim());
    if (d) out.add(d.toISOString().slice(0, 10));
  }
  return out;
}

function _workingDaysBetweenInclusive(from, to, { excludeSundays, excludeSaturdays, holidays }) {
  const MS_PER_DAY = 24 * 60 * 60 * 1000;
  const a = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const b = new Date(to.getFullYear(), to.getMonth(), to.getDate());
  let count = 0;
  for (let t = a.getTime(); t <= b.getTime(); t += MS_PER_DAY) {
    const d = new Date(t);
    const dow = d.getDay(); // 0=Sun ... 6=Sat
    if (excludeSundays && dow === 0) continue;
    if (excludeSaturdays && dow === 6) continue;
    const key = d.toISOString().slice(0, 10);
    if (holidays && holidays.has(key)) continue;
    count += 1;
  }
  return count;
}

async function _ensureStaffInSociety({ societyId, staffId }) {
  const staff = await prisma.staff.findUnique({ where: { id: staffId } });
  if (!staff || staff.societyId !== societyId || staff.isActive !== true) return null;
  return staff;
}

// GET /api/staff/attendance-summary?month=YYYY-MM[-DD]
// or: /api/staff/attendance-summary?from=YYYY-MM-DD&to=YYYY-MM-DD
// optional: paidLeave=true|false, halfDayFactor=0.5
// divisor: divisorMode=calendar|working, excludeSundays=true, excludeSaturdays=true, holidays=YYYY-MM-DD,YYYY-MM-DD
async function getAttendanceSummary(req, res) {
  try {
    const { societyId } = req.user;
    const {
      month,
      staffId,
      from,
      to,
      paidLeave,
      halfDayFactor,
      divisorMode,
      excludeSundays,
      excludeSaturdays,
      holidays,
    } = req.query;

    const paidLeaveFlag = String(paidLeave ?? 'false').toLowerCase() === 'true';
    const halfFactor = halfDayFactor === undefined ? 0.5 : Number(halfDayFactor);
    if (!Number.isFinite(halfFactor) || halfFactor < 0 || halfFactor > 1) {
      return sendError(res, 'halfDayFactor must be a number between 0 and 1', 400);
    }

    const divMode = String(divisorMode ?? 'calendar').toLowerCase(); // calendar | working
    if (!['calendar', 'working'].includes(divMode)) {
      return sendError(res, 'divisorMode must be calendar or working', 400);
    }
    const exSun = String(excludeSundays ?? 'false').toLowerCase() === 'true';
    const exSat = String(excludeSaturdays ?? 'false').toLowerCase() === 'true';
    const holidaySet = _parseHolidayList(holidays);

    let rangeFrom = null;
    let rangeTo = null;
    let periodType = null;
    let divisorDays = null;
    let monthKey = null;

    if (from || to) {
      if (!from || !to) return sendError(res, 'Both from and to are required for date range', 400);
      rangeFrom = _parseDateOnly(from);
      rangeTo = _parseDateOnly(to);
      if (!rangeFrom || !rangeTo) return sendError(res, 'Invalid from/to date', 400);
      if (rangeFrom.getTime() > rangeTo.getTime()) return sendError(res, 'from must be <= to', 400);
      periodType = 'RANGE';
      divisorDays = _daysBetweenInclusive(rangeFrom, rangeTo);
    } else {
      if (!month) return sendError(res, 'month is required (e.g. 2026-04)', 400);
      const bounds = _monthBounds(month);
      if (!bounds) return sendError(res, 'Invalid month value', 400);
      rangeFrom = bounds.from;
      rangeTo = bounds.to;
      periodType = 'MONTH';
      divisorDays = bounds.daysInMonth;
      monthKey = `${bounds.from.getFullYear()}-${String(bounds.from.getMonth() + 1).padStart(2, '0')}`;
    }

    if (divMode === 'working') {
      divisorDays = _workingDaysBetweenInclusive(rangeFrom, rangeTo, {
        excludeSundays: exSun,
        excludeSaturdays: exSat,
        holidays: holidaySet,
      });
      if (divisorDays <= 0) {
        return sendError(res, 'Working days in period is 0; adjust divisor options', 400);
      }
    }

    const whereStaff = { societyId, isActive: true };
    if (staffId) whereStaff.id = String(staffId);

    const staff = await prisma.staff.findMany({
      where: whereStaff,
      orderBy: { name: 'asc' },
      include: {
        attendance: {
          where: { date: { gte: rangeFrom, lte: rangeTo } },
          orderBy: { date: 'asc' },
        },
      },
    });

    const staffIds = staff.map((s) => s.id);
    const payments = staffIds.length
      ? await prisma.staffSalaryPayment.findMany({
          where: {
            societyId,
            staffId: { in: staffIds },
            periodFrom: rangeFrom,
            periodTo: rangeTo,
            cancelledAt: null,
          },
          select: {
            id: true,
            staffId: true,
            amount: true,
            paymentMethod: true,
            note: true,
            paidAt: true,
            paidById: true,
          },
        })
      : [];
    const paymentByStaffId = new Map(payments.map((p) => [p.staffId, p]));

    const summaries = staff.map((s) => {
      let present = 0;
      let absent = 0;
      let halfDay = 0;
      let leave = 0;
      for (const a of s.attendance || []) {
        switch (String(a.status)) {
          case 'PRESENT':
            present += 1;
            break;
          case 'ABSENT':
            absent += 1;
            break;
          case 'HALF_DAY':
            halfDay += 1;
            break;
          case 'LEAVE':
            leave += 1;
            break;
          default:
            break;
        }
      }

      const payableDays =
        present +
        halfDay * halfFactor +
        (paidLeaveFlag ? leave : 0);
      const monthlySalary = Number(s.salary || 0);
      const perDayRate = divisorDays > 0 ? monthlySalary / divisorDays : 0;
      const salaryPayable = perDayRate * payableDays;
      const payment = paymentByStaffId.get(s.id) || null;

      return {
        staffId: s.id,
        name: s.name,
        role: s.role,
        period: {
          type: periodType,
          month: monthKey,
          from: rangeFrom,
          to: rangeTo,
          divisorDays,
        },
        counts: { present, halfDay, absent, leave },
        rules: {
          paidLeave: paidLeaveFlag,
          halfDayFactor: halfFactor,
          divisorMode: divMode,
          excludeSundays: exSun,
          excludeSaturdays: exSat,
          holidays: [...holidaySet],
        },
        payableDays,
        monthlySalary,
        perDayRate,
        salaryPayable,
        payment: payment
          ? {
              id: payment.id,
              amount: Number(payment.amount || 0),
              paymentMethod: payment.paymentMethod,
              note: payment.note,
              paidAt: payment.paidAt,
              paidById: payment.paidById,
            }
          : null,
      };
    });

    return sendSuccess(res, { summaries }, 'Attendance summary retrieved');
  } catch (err) {
    console.error('Attendance summary error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// GET /api/staff/salary-payments?from=YYYY-MM-DD&to=YYYY-MM-DD&staffId=...
async function listSalaryPayments(req, res) {
  try {
    const { societyId } = req.user;
    const { from, to, staffId } = req.query;
    if (!from || !to) return sendError(res, 'from and to are required', 400);
    const rangeFrom = _parseDateOnly(from);
    const rangeTo = _parseDateOnly(to);
    if (!rangeFrom || !rangeTo) return sendError(res, 'Invalid from/to date', 400);

    const where = { societyId, periodFrom: rangeFrom, periodTo: rangeTo };
    if (staffId) where.staffId = String(staffId);

    const payments = await prisma.staffSalaryPayment.findMany({
      where,
      orderBy: [{ paidAt: 'desc' }],
    });

    return sendSuccess(res, { payments }, 'Salary payments retrieved');
  } catch (err) {
    console.error('List salary payments error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// GET /api/staff/salary-payments/history?month=YYYY-MM&page=1&limit=50&q=...
// or: /api/staff/salary-payments/history?from=YYYY-MM-DD&to=YYYY-MM-DD
async function getSalaryPaymentHistory(req, res) {
  try {
    const { societyId } = req.user;
    const { month, from, to, q, page = 1, limit = 50, includeCancelled } = req.query;

    let rangeFrom = null;
    let rangeTo = null;
    if (from || to) {
      if (!from || !to) return sendError(res, 'from and to are required', 400);
      rangeFrom = _parseDateOnly(from);
      rangeTo = _parseDateOnly(to);
      if (!rangeFrom || !rangeTo) return sendError(res, 'Invalid from/to date', 400);
    } else {
      if (!month) return sendError(res, 'month is required (e.g. 2026-04)', 400);
      const bounds = _monthBounds(month);
      if (!bounds) return sendError(res, 'Invalid month value', 400);
      rangeFrom = bounds.from;
      rangeTo = bounds.to;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = parseInt(limit);

    const where = {
      societyId,
      paidAt: { gte: rangeFrom, lte: new Date(rangeTo.getFullYear(), rangeTo.getMonth(), rangeTo.getDate(), 23, 59, 59, 999) },
    };
    if (String(includeCancelled ?? 'false').toLowerCase() !== 'true') {
      where.cancelledAt = null;
    }

    const query = String(q || '').trim().toLowerCase();
    if (query) {
      where.OR = [
        { note: { contains: query, mode: 'insensitive' } },
        { staff: { name: { contains: query, mode: 'insensitive' } } },
        { staff: { role: { contains: query, mode: 'insensitive' } } },
        { staff: { phone: { contains: query, mode: 'insensitive' } } },
      ];
    }

    const [payments, total] = await Promise.all([
      prisma.staffSalaryPayment.findMany({
        where,
        skip,
        take,
        orderBy: [{ paidAt: 'desc' }],
        include: {
          staff: { select: { id: true, name: true, role: true, phone: true } },
          paidBy: { select: { id: true, name: true, role: true, phone: true } },
          cancelledBy: { select: { id: true, name: true, role: true, phone: true } },
        },
      }),
      prisma.staffSalaryPayment.count({ where }),
    ]);

    return sendSuccess(
      res,
      { payments, total, page: parseInt(page), limit: take, from: rangeFrom, to: rangeTo },
      'Salary payment history retrieved'
    );
  } catch (err) {
    console.error('Salary payment history error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

function _computePayableDays({ present, halfDay, leave, paidLeaveFlag, halfFactor }) {
  return present + halfDay * halfFactor + (paidLeaveFlag ? leave : 0);
}

// POST /api/staff/salary-payments/:id/cancel
// body: { reason }
async function cancelSalaryPayment(req, res) {
  try {
    const { societyId, id: actorId } = req.user;
    const { id } = req.params;
    const { reason } = req.body || {};

    const existing = await prisma.staffSalaryPayment.findUnique({
      where: { id: String(id) },
    });
    if (!existing || existing.societyId !== societyId) {
      return sendError(res, 'Payment not found', 404);
    }
    if (existing.cancelledAt) {
      return sendError(res, 'Payment already cancelled', 409);
    }

    const updated = await prisma.staffSalaryPayment.update({
      where: { id: existing.id },
      data: {
        cancelledAt: new Date(),
        cancelledById: actorId,
        cancelReason: reason ? String(reason) : null,
      },
    });

    return sendSuccess(res, updated, 'Payment cancelled');
  } catch (err) {
    console.error('Cancel salary payment error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff/salary-payments/cancel-bulk
// body: { ids: [paymentId], reason }
async function cancelSalaryPaymentsBulk(req, res) {
  try {
    const { societyId, id: actorId } = req.user;
    const { ids, reason } = req.body || {};
    if (!Array.isArray(ids) || ids.length === 0) {
      return sendError(res, 'ids must be a non-empty array', 400);
    }
    const uniq = [...new Set(ids.map((x) => String(x || '')).filter(Boolean))];
    if (!uniq.length) return sendError(res, 'No valid ids provided', 400);

    // Only cancel payments in this society and not already cancelled.
    const result = await prisma.staffSalaryPayment.updateMany({
      where: {
        id: { in: uniq },
        societyId,
        cancelledAt: null,
      },
      data: {
        cancelledAt: new Date(),
        cancelledById: actorId,
        cancelReason: reason ? String(reason) : null,
      },
    });

    return sendSuccess(res, { cancelledCount: result.count }, 'Payments cancelled');
  } catch (err) {
    console.error('Bulk cancel salary payments error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff/salary-payments/bulk
// body: { from, to, paymentMethod, note, rules: { paidLeave, halfDayFactor, divisorMode, excludeSundays, excludeSaturdays, holidays } }
async function markSalaryPaidBulk(req, res) {
  try {
    const { societyId, id: actorId } = req.user;
    const { from, to, paymentMethod, note, rules } = req.body || {};
    if (!from || !to) return sendError(res, 'from and to are required', 400);
    const rangeFrom = _parseDateOnly(from);
    const rangeTo = _parseDateOnly(to);
    if (!rangeFrom || !rangeTo) return sendError(res, 'Invalid from/to date', 400);
    if (rangeFrom.getTime() > rangeTo.getTime()) return sendError(res, 'from must be <= to', 400);

    const ruleObj = (rules && typeof rules === 'object') ? rules : {};
    const paidLeaveFlag = String(ruleObj.paidLeave ?? 'false').toLowerCase() === 'true';
    const halfFactor = ruleObj.halfDayFactor === undefined ? 0.5 : Number(ruleObj.halfDayFactor);
    if (!Number.isFinite(halfFactor) || halfFactor < 0 || halfFactor > 1) {
      return sendError(res, 'rules.halfDayFactor must be a number between 0 and 1', 400);
    }

    const divMode = String(ruleObj.divisorMode ?? 'calendar').toLowerCase();
    if (!['calendar', 'working'].includes(divMode)) {
      return sendError(res, 'rules.divisorMode must be calendar or working', 400);
    }
    const exSun = String(ruleObj.excludeSundays ?? 'false').toLowerCase() === 'true';
    const exSat = String(ruleObj.excludeSaturdays ?? 'false').toLowerCase() === 'true';
    const holidaySet = _parseHolidayList(ruleObj.holidays);

    let divisorDays = _daysBetweenInclusive(rangeFrom, rangeTo);
    if (divMode === 'working') {
      divisorDays = _workingDaysBetweenInclusive(rangeFrom, rangeTo, {
        excludeSundays: exSun,
        excludeSaturdays: exSat,
        holidays: holidaySet,
      });
      if (divisorDays <= 0) return sendError(res, 'Working days in period is 0; adjust divisor options', 400);
    }

    const pm = paymentMethod ? String(paymentMethod).toUpperCase() : 'CASH';
    const validPM = ['CASH', 'BANK', 'UPI', 'ONLINE', 'RAZORPAY'];
    if (!validPM.includes(pm)) return sendError(res, `paymentMethod must be one of: ${validPM.join(', ')}`, 400);

    // Load staff + attendance in range
    const staff = await prisma.staff.findMany({
      where: { societyId, isActive: true },
      orderBy: { name: 'asc' },
      include: {
        attendance: {
          where: { date: { gte: rangeFrom, lte: rangeTo } },
        },
      },
    });

    // Existing payments for this period (skip those staff)
    const staffIds = staff.map((s) => s.id);
    const existing = staffIds.length
      ? await prisma.staffSalaryPayment.findMany({
          where: { societyId, staffId: { in: staffIds }, periodFrom: rangeFrom, periodTo: rangeTo, cancelledAt: null },
          select: { staffId: true },
        })
      : [];
    const alreadyPaid = new Set(existing.map((p) => p.staffId));

    const creates = [];
    let skipped = 0;
    for (const s of staff) {
      if (alreadyPaid.has(s.id)) {
        skipped += 1;
        continue;
      }
      let present = 0, absent = 0, halfDay = 0, leave = 0;
      for (const a of s.attendance || []) {
        switch (String(a.status)) {
          case 'PRESENT': present += 1; break;
          case 'ABSENT': absent += 1; break;
          case 'HALF_DAY': halfDay += 1; break;
          case 'LEAVE': leave += 1; break;
          default: break;
        }
      }

      const payableDays = _computePayableDays({ present, halfDay, leave, paidLeaveFlag, halfFactor });
      const monthlySalary = Number(s.salary || 0);
      const perDayRate = divisorDays > 0 ? monthlySalary / divisorDays : 0;
      const salaryPayable = perDayRate * payableDays;

      creates.push(
        prisma.staffSalaryPayment.create({
          data: {
            societyId,
            staffId: s.id,
            periodFrom: rangeFrom,
            periodTo: rangeTo,
            divisorDays,
            rules: {
              paidLeave: paidLeaveFlag,
              halfDayFactor: halfFactor,
              divisorMode: divMode,
              excludeSundays: exSun,
              excludeSaturdays: exSat,
              holidays: [...holidaySet],
            },
            amount: salaryPayable,
            paymentMethod: pm,
            note: note ? String(note) : null,
            paidById: actorId,
          },
        })
      );
    }

    const created = creates.length
      ? await prisma.$transaction(creates)
      : [];

    return sendSuccess(
      res,
      { createdCount: created.length, skippedAlreadyPaid: skipped, period: { from: rangeFrom, to: rangeTo } },
      'Bulk salary marked as paid'
    );
  } catch (err) {
    console.error('Bulk salary paid error:', err.message);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/staff/salary-payments
// body: { staffId, from, to, amount, paymentMethod, note, divisorDays, rules }
async function markSalaryPaid(req, res) {
  try {
    const { societyId, id: actorId } = req.user;
    const { staffId, from, to, amount, paymentMethod, note, divisorDays, rules } = req.body || {};

    if (!staffId || !from || !to) return sendError(res, 'staffId, from, to are required', 400);
    const rangeFrom = _parseDateOnly(from);
    const rangeTo = _parseDateOnly(to);
    if (!rangeFrom || !rangeTo) return sendError(res, 'Invalid from/to date', 400);
    if (rangeFrom.getTime() > rangeTo.getTime()) return sendError(res, 'from must be <= to', 400);

    const s = await _ensureStaffInSociety({ societyId, staffId: String(staffId) });
    if (!s) return sendError(res, 'Staff member not found', 404);

    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt < 0) return sendError(res, 'amount must be a valid number', 400);
    const divDays = divisorDays === undefined ? null : Number(divisorDays);
    if (divDays !== null && (!Number.isFinite(divDays) || divDays <= 0)) {
      return sendError(res, 'divisorDays must be a positive number', 400);
    }

    const pm = paymentMethod ? String(paymentMethod).toUpperCase() : 'CASH';
    const validPM = ['CASH', 'BANK', 'UPI', 'ONLINE', 'RAZORPAY'];
    if (!validPM.includes(pm)) return sendError(res, `paymentMethod must be one of: ${validPM.join(', ')}`, 400);

    const payment = await prisma.staffSalaryPayment.upsert({
      where: { societyId_staffId_periodFrom_periodTo: { societyId, staffId: s.id, periodFrom: rangeFrom, periodTo: rangeTo } },
      update: {
        amount: amt,
        paymentMethod: pm,
        note: note ? String(note) : null,
        divisorDays: divDays ?? 1,
        rules: rules ?? undefined,
        paidAt: new Date(),
        paidById: actorId,
      },
      create: {
        societyId,
        staffId: s.id,
        periodFrom: rangeFrom,
        periodTo: rangeTo,
        amount: amt,
        paymentMethod: pm,
        note: note ? String(note) : null,
        divisorDays: divDays ?? 1,
        rules: rules ?? undefined,
        paidById: actorId,
      },
    });

    return sendSuccess(res, payment, 'Salary marked as paid');
  } catch (err) {
    console.error('Mark salary paid error:', err.message);
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

module.exports = {
  listStaff,
  createStaff,
  updateStaff,
  deleteStaff,
  markAttendance,
  getAttendanceSheet,
  markAttendanceBulk,
  getAttendance,
  getAttendanceSummary,
  listSalaryPayments,
  getSalaryPaymentHistory,
  markSalaryPaid,
  markSalaryPaidBulk,
  cancelSalaryPayment,
  cancelSalaryPaymentsBulk,
  resetWatchmanPassword,
};
