const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

// ── POST /api/amenities/bookings ──────────────────────────────────────────────
async function createBooking(req, res, next) {
  try {
    const { societyId, id: bookedById } = req.user;
    const { amenityId, unitId, bookingDate, startTime, endTime, halfDaySlot,
            monthYear, dailyHoursLimit, guestCount, purpose } = req.body;

    if (!amenityId || !unitId) return sendError(res, 'amenityId and unitId are required', 400);

    const amenity = await prisma.amenity.findUnique({ where: { id: amenityId } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);
    if (amenity.status !== 'ACTIVE') return sendError(res, 'Amenity is not active', 400);

    if (amenity.bookingType === 'FREE') {
      return sendError(res, 'This amenity is free-access and does not require booking', 400);
    }

    let fee = 0;
    let bookingData = { amenityId, societyId, unitId, bookedById, guestCount: guestCount || null, purpose: purpose || null };

    if (amenity.bookingType === 'SLOT') {
      if (!bookingDate || !startTime || !endTime)
        return sendError(res, 'bookingDate, startTime, endTime required for slot booking', 400);

      // Check conflict
      const conflict = await prisma.amenityBooking.findFirst({
        where: { amenityId, bookingDate: new Date(bookingDate), startTime, status: { in: ['PENDING', 'CONFIRMED'] } },
      });
      if (conflict) return sendError(res, 'This time slot is already booked', 409);

      fee = Number(amenity.bookingFee);
      bookingData = { ...bookingData, bookingDate: new Date(bookingDate), startTime, endTime, feeCharged: fee };

    } else if (amenity.bookingType === 'HALF_DAY') {
      if (!bookingDate || !halfDaySlot)
        return sendError(res, 'bookingDate and halfDaySlot (FULL|FIRST_HALF|SECOND_HALF) required', 400);
      if (!['FULL', 'FIRST_HALF', 'SECOND_HALF'].includes(halfDaySlot))
        return sendError(res, 'halfDaySlot must be FULL, FIRST_HALF, or SECOND_HALF', 400);

      // Conflict check
      const existing = await prisma.amenityBooking.findMany({
        where: { amenityId, bookingDate: new Date(bookingDate), status: { in: ['PENDING', 'CONFIRMED'] } },
        select: { halfDaySlot: true },
      });
      const bookedSlots = new Set(existing.map(b => b.halfDaySlot));
      const hasFullDay = bookedSlots.has('FULL');
      const conflict =
        hasFullDay ||
        (halfDaySlot === 'FULL' && (bookedSlots.has('FIRST_HALF') || bookedSlots.has('SECOND_HALF'))) ||
        bookedSlots.has(halfDaySlot);
      if (conflict) return sendError(res, 'Selected slot is not available for this date', 409);

      const split = amenity.firstHalfEnd || '13:00';
      fee = halfDaySlot === 'FULL' ? Number(amenity.fullDayFee) : Number(amenity.halfDayFee);
      bookingData = {
        ...bookingData,
        bookingDate: new Date(bookingDate),
        startTime: halfDaySlot === 'SECOND_HALF' ? split : amenity.openTime,
        endTime: halfDaySlot === 'FIRST_HALF' ? split : amenity.closeTime,
        halfDaySlot,
        feeCharged: fee,
      };

    } else if (amenity.bookingType === 'MONTHLY') {
      if (!monthYear) return sendError(res, 'monthYear required for monthly booking (YYYY-MM)', 400);

      // One monthly booking per unit per amenity per month
      const conflict = await prisma.amenityBooking.findFirst({
        where: { amenityId, unitId, monthYear, status: { in: ['PENDING', 'CONFIRMED'] } },
      });
      if (conflict) return sendError(res, 'This unit already has a monthly booking for this period', 409);

      // Enforce per-amenity daily limit if set
      if (amenity.maxDailyHours && dailyHoursLimit && parseInt(dailyHoursLimit) > amenity.maxDailyHours) {
        return sendError(res, `Max allowed daily hours is ${amenity.maxDailyHours}`, 400);
      }

      fee = Number(amenity.monthlyFee);
      bookingData = { ...bookingData, monthYear, dailyHoursLimit: dailyHoursLimit ? parseInt(dailyHoursLimit) : null, feeCharged: fee };
    }

    const status = amenity.requireApproval ? 'PENDING' : 'CONFIRMED';

    const booking = await prisma.amenityBooking.create({
      data: { ...bookingData, status },
      include: {
        amenity: { select: { id: true, name: true, bookingType: true } },
        unit: { select: { id: true, fullCode: true } },
      },
    });

    return sendSuccess(res, booking, amenity.requireApproval ? 'Booking submitted, awaiting approval' : 'Booking confirmed', 201);
  } catch (err) {
    if (err.code === 'P2002') return sendError(res, 'This slot is already booked', 409);
    next(err);
  }
}

// ── GET /api/amenities/bookings ───────────────────────────────────────────────
async function listBookings(req, res, next) {
  try {
    const { societyId } = req.user;
    const { amenityId, status, page = 1, limit = 20 } = req.query;
    const where = { societyId };
    if (amenityId) where.amenityId = amenityId;
    if (status) where.status = status;

    const [bookings, total] = await Promise.all([
      prisma.amenityBooking.findMany({
        where, skip: (parseInt(page) - 1) * parseInt(limit), take: parseInt(limit),
        include: {
          amenity: { select: { id: true, name: true, bookingType: true } },
          unit: { select: { id: true, fullCode: true } },
          bookedBy: { select: { name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.amenityBooking.count({ where }),
    ]);

    return sendSuccess(res, { bookings, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) { next(err); }
}

// ── GET /api/amenities/bookings/mine ─────────────────────────────────────────
async function listMyBookings(req, res, next) {
  try {
    const { societyId, id: bookedById } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const where = { societyId, bookedById };
    if (status) where.status = status;

    const [bookings, total] = await Promise.all([
      prisma.amenityBooking.findMany({
        where, skip: (parseInt(page) - 1) * parseInt(limit), take: parseInt(limit),
        include: {
          amenity: { select: { id: true, name: true, bookingType: true } },
          unit: { select: { id: true, fullCode: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.amenityBooking.count({ where }),
    ]);

    return sendSuccess(res, { bookings, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) { next(err); }
}

// ── PATCH /api/amenities/bookings/:id/status ──────────────────────────────────
async function updateBookingStatus(req, res, next) {
  try {
    const { id } = req.params;
    const { status, cancelReason } = req.body;
    const societyId = req.user.societyId;

    if (!['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'].includes(status))
      return sendError(res, 'Invalid status', 400);

    const booking = await prisma.amenityBooking.update({
      where: { id, societyId },
      data: {
        status,
        ...(status === 'CANCELLED' ? { cancelledAt: new Date(), cancelReason } : {}),
        ...(status === 'CONFIRMED' ? { approvedById: req.user.id, approvedAt: new Date() } : {}),
      },
      select: { id: true, status: true, updatedAt: true },
    });

    return sendSuccess(res, booking, 'Booking updated');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Booking not found', 404);
    next(err);
  }
}

module.exports = { createBooking, listBookings, listMyBookings, updateBookingStatus };
