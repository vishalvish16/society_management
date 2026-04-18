const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// ── helpers ──────────────────────────────────────────────────────────────────

function timeToMin(t) {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
}
function minToTime(m) {
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
}

// ── GET /api/amenities ────────────────────────────────────────────────────────
const getAllAmenities = async (req, res) => {
  try {
    const { societyId } = req.user;
    const amenities = await prisma.amenity.findMany({
      where: { societyId },
      orderBy: { name: 'asc' },
    });
    return sendSuccess(res, amenities);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// ── POST /api/amenities ───────────────────────────────────────────────────────
const createAmenity = async (req, res) => {
  try {
    const { societyId } = req.user;
    const {
      name, description, capacity,
      bookingType = 'SLOT',
      openTime = '06:00', closeTime = '22:00',
      bookingDuration = 60,
      firstHalfEnd,
      maxDailyHours,
      bookingFee = 0, halfDayFee = 0, fullDayFee = 0, monthlyFee = 0,
      maxAdvanceDays = 30,
      rules, requireApproval = false,
    } = req.body;

    if (!name) return sendError(res, 'name is required', 400);
    if (!['FREE', 'SLOT', 'HALF_DAY', 'MONTHLY'].includes(bookingType)) {
      return sendError(res, 'invalid bookingType', 400);
    }

    const amenity = await prisma.amenity.create({
      data: {
        societyId, name,
        description: description || null,
        capacity: capacity ? parseInt(capacity) : null,
        bookingType,
        openTime, closeTime,
        bookingDuration: parseInt(bookingDuration),
        firstHalfEnd: firstHalfEnd || null,
        maxDailyHours: maxDailyHours ? parseInt(maxDailyHours) : null,
        bookingFee: Number(bookingFee),
        halfDayFee: Number(halfDayFee),
        fullDayFee: Number(fullDayFee),
        monthlyFee: Number(monthlyFee),
        maxAdvanceDays: parseInt(maxAdvanceDays),
        rules: rules || null,
        requireApproval: Boolean(requireApproval),
        status: 'ACTIVE',
      },
    });
    return sendSuccess(res, amenity, 'Amenity created', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// ── PATCH /api/amenities/:id ──────────────────────────────────────────────────
const updateAmenity = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const amenity = await prisma.amenity.findUnique({ where: { id } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);

    const fields = [
      'name', 'description', 'status', 'capacity', 'bookingType',
      'openTime', 'closeTime', 'bookingDuration', 'firstHalfEnd',
      'maxDailyHours', 'bookingFee', 'halfDayFee', 'fullDayFee', 'monthlyFee',
      'maxAdvanceDays', 'rules', 'requireApproval',
    ];
    const data = {};
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        if (['capacity', 'bookingDuration', 'maxDailyHours', 'maxAdvanceDays'].includes(f))
          data[f] = req.body[f] === null ? null : parseInt(req.body[f]);
        else if (['bookingFee', 'halfDayFee', 'fullDayFee', 'monthlyFee'].includes(f))
          data[f] = Number(req.body[f]);
        else if (f === 'requireApproval')
          data[f] = Boolean(req.body[f]);
        else
          data[f] = req.body[f];
      }
    }

    const updated = await prisma.amenity.update({ where: { id }, data });
    return sendSuccess(res, updated, 'Amenity updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// ── DELETE /api/amenities/:id ─────────────────────────────────────────────────
const deleteAmenityById = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const amenity = await prisma.amenity.findUnique({ where: { id } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);
    await prisma.amenity.update({ where: { id }, data: { status: 'INACTIVE' } });
    return sendSuccess(res, null, 'Amenity deactivated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// ── GET /api/amenities/:id/slots?date=YYYY-MM-DD ──────────────────────────────
// Returns availability info for a given date depending on booking type
const getAvailableSlots = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id: amenityId } = req.params;
    const { date } = req.query;

    if (!date) return sendError(res, 'date query param required (YYYY-MM-DD)', 400);

    const amenity = await prisma.amenity.findUnique({ where: { id: amenityId } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);
    if (amenity.status !== 'ACTIVE') return sendError(res, 'Amenity is not available', 400);

    // Closure check
    const bookingDate = new Date(date);
    const closures = amenity.closurePeriods || [];
    const isClosed = closures.some(c => new Date(c.from) <= bookingDate && bookingDate <= new Date(c.to));
    if (isClosed) return sendError(res, 'Amenity is closed on this date', 400);

    if (amenity.bookingType === 'FREE') {
      return sendSuccess(res, { bookingType: 'FREE', slots: [] });
    }

    if (amenity.bookingType === 'HALF_DAY') {
      const split = amenity.firstHalfEnd || '13:00';
      const slots = [
        { key: 'FIRST_HALF', label: 'First Half', startTime: amenity.openTime, endTime: split, fee: Number(amenity.halfDayFee) },
        { key: 'SECOND_HALF', label: 'Second Half', startTime: split, endTime: amenity.closeTime, fee: Number(amenity.halfDayFee) },
        { key: 'FULL', label: 'Full Day', startTime: amenity.openTime, endTime: amenity.closeTime, fee: Number(amenity.fullDayFee) },
      ];

      // Find bookings on this date
      const booked = await prisma.amenityBooking.findMany({
        where: { amenityId, bookingDate: new Date(date), status: { in: ['PENDING', 'CONFIRMED'] } },
        select: { halfDaySlot: true },
      });
      const bookedSlots = new Set(booked.map(b => b.halfDaySlot));

      // FULL blocks everything; FIRST/SECOND_HALF block FULL
      const hasFullDay = bookedSlots.has('FULL');
      const hasFirstHalf = bookedSlots.has('FIRST_HALF');
      const hasSecondHalf = bookedSlots.has('SECOND_HALF');

      const result = slots.map(s => ({
        ...s,
        available: s.key === 'FULL'
          ? !hasFirstHalf && !hasSecondHalf && !hasFullDay
          : s.key === 'FIRST_HALF'
          ? !hasFirstHalf && !hasFullDay
          : !hasSecondHalf && !hasFullDay,
      }));

      return sendSuccess(res, { bookingType: 'HALF_DAY', date, slots: result });
    }

    if (amenity.bookingType === 'MONTHLY') {
      // Return already-booked monthly subscriptions for this amenity
      const [year, month] = date.split('-');
      const monthYear = `${year}-${month}`;
      const bookings = await prisma.amenityBooking.findMany({
        where: { amenityId, monthYear, status: { in: ['PENDING', 'CONFIRMED'] } },
        include: { unit: { select: { fullCode: true } }, bookedBy: { select: { name: true } } },
      });
      return sendSuccess(res, {
        bookingType: 'MONTHLY',
        monthYear,
        maxDailyHours: amenity.maxDailyHours,
        bookings,
      });
    }

    // SLOT – hourly slots
    const open = timeToMin(amenity.openTime);
    const close = timeToMin(amenity.closeTime);
    const dur = amenity.bookingDuration;
    const slots = [];
    for (let cur = open; cur + dur <= close; cur += dur) {
      slots.push({ startTime: minToTime(cur), endTime: minToTime(cur + dur), fee: Number(amenity.bookingFee) });
    }

    const booked = await prisma.amenityBooking.findMany({
      where: { amenityId, bookingDate: new Date(date), status: { in: ['PENDING', 'CONFIRMED'] } },
      select: { startTime: true },
    });
    const bookedSet = new Set(booked.map(b => b.startTime));

    return sendSuccess(res, {
      bookingType: 'SLOT',
      date,
      slots: slots.map(s => ({ ...s, available: !bookedSet.has(s.startTime) })),
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// ── GET /api/amenities/:id/bookings ──────────────────────────────────────────
const getAmenityBookings = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id: amenityId } = req.params;
    const { status, page = 1, limit = 30 } = req.query;

    const amenity = await prisma.amenity.findUnique({ where: { id: amenityId } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);

    const where = { amenityId, societyId };
    if (status) where.status = status;

    const [bookings, total] = await Promise.all([
      prisma.amenityBooking.findMany({
        where, skip: (parseInt(page) - 1) * parseInt(limit), take: parseInt(limit),
        include: {
          unit: { select: { fullCode: true } },
          bookedBy: { select: { name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.amenityBooking.count({ where }),
    ]);

    return sendSuccess(res, { bookings, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// ── GET /api/amenities/:id/calendar?month=YYYY-MM ────────────────────────────
// Returns a month-level availability heatmap – one entry per day
const getCalendar = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id: amenityId } = req.params;
    const { month } = req.query; // "2025-06"

    if (!month) return sendError(res, 'month query param required (YYYY-MM)', 400);

    const amenity = await prisma.amenity.findUnique({ where: { id: amenityId } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);

    const [year, mon] = month.split('-').map(Number);
    const from = new Date(year, mon - 1, 1);
    const to = new Date(year, mon, 0, 23, 59, 59);

    if (amenity.bookingType === 'FREE') {
      return sendSuccess(res, { bookingType: 'FREE', month, days: [] });
    }

    if (amenity.bookingType === 'MONTHLY') {
      const bookings = await prisma.amenityBooking.count({
        where: { amenityId, monthYear: month, status: { in: ['PENDING', 'CONFIRMED'] } },
      });
      return sendSuccess(res, { bookingType: 'MONTHLY', month, bookingCount: bookings });
    }

    const bookings = await prisma.amenityBooking.findMany({
      where: {
        amenityId,
        status: { in: ['PENDING', 'CONFIRMED'] },
        bookingDate: { gte: from, lte: to },
      },
      select: { bookingDate: true, startTime: true, halfDaySlot: true },
    });

    // group by date
    const byDate = {};
    for (const b of bookings) {
      const key = b.bookingDate.toISOString().split('T')[0];
      if (!byDate[key]) byDate[key] = [];
      byDate[key].push(b);
    }

    // calculate total possible slots per day
    let totalSlots = 0;
    if (amenity.bookingType === 'SLOT') {
      const open = timeToMin(amenity.openTime);
      const close = timeToMin(amenity.closeTime);
      totalSlots = Math.floor((close - open) / amenity.bookingDuration);
    } else if (amenity.bookingType === 'HALF_DAY') {
      totalSlots = 3; // FIRST_HALF, SECOND_HALF, FULL – but only 2 can be booked simultaneously
    }

    const daysInMonth = new Date(year, mon, 0).getDate();
    const days = [];
    for (let d = 1; d <= daysInMonth; d++) {
      const key = `${year}-${String(mon).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const count = byDate[key]?.length ?? 0;
      let status = 'available';
      if (amenity.bookingType === 'HALF_DAY') {
        const slots = byDate[key] || [];
        const hasFullDay = slots.some(s => s.halfDaySlot === 'FULL');
        const hasBothHalves = slots.filter(s => s.halfDaySlot !== 'FULL').length >= 2;
        status = hasFullDay || hasBothHalves ? 'full' : count > 0 ? 'partial' : 'available';
      } else {
        status = count >= totalSlots ? 'full' : count > 0 ? 'partial' : 'available';
      }
      days.push({ date: key, bookedCount: count, totalSlots, status });
    }

    return sendSuccess(res, { bookingType: amenity.bookingType, month, days });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { getAllAmenities, createAmenity, updateAmenity, deleteAmenityById, getAvailableSlots, getAmenityBookings, getCalendar };
