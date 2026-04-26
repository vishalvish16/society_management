const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

function num(value) {
  if (value === null || value === undefined) return 0;
  const n = Number(typeof value === 'object' && value.toString ? value.toString() : value);
  return Number.isFinite(n) ? n : 0;
}

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
        select: { id: true, unitId: true, bookedById: true, societyId: true },
      });
      if (conflict) {
        // Idempotency: if the same user/unit re-submits the same slot, return existing booking
        if (conflict.societyId === societyId && conflict.unitId === unitId && conflict.bookedById === bookedById) {
          const existing = await prisma.amenityBooking.findUnique({
            where: { id: conflict.id },
            include: {
              amenity: { select: { id: true, name: true, bookingType: true } },
              unit: { select: { id: true, fullCode: true } },
            },
          });
          const bill = await prisma.maintenanceBill.findFirst({
            where: {
              societyId,
              unitId,
              category: 'AMENITY',
              notes: `amenityBooking:${conflict.id}`,
              deletedAt: null,
            },
            select: { id: true },
          });
          return sendSuccess(res, { ...existing, billId: bill?.id || null }, 'Booking already exists');
        }
        return sendError(res, 'This time slot is already booked', 409);
      }

      fee = num(amenity.bookingFee);
      bookingData = { ...bookingData, bookingDate: new Date(bookingDate), startTime, endTime, feeCharged: fee };

    } else if (amenity.bookingType === 'HALF_DAY') {
      if (!bookingDate || !halfDaySlot)
        return sendError(res, 'bookingDate and halfDaySlot (FULL|FIRST_HALF|SECOND_HALF) required', 400);
      if (!['FULL', 'FIRST_HALF', 'SECOND_HALF'].includes(halfDaySlot))
        return sendError(res, 'halfDaySlot must be FULL, FIRST_HALF, or SECOND_HALF', 400);

      // Conflict check
      const existing = await prisma.amenityBooking.findMany({
        where: { amenityId, bookingDate: new Date(bookingDate), status: { in: ['PENDING', 'CONFIRMED'] } },
        select: { id: true, unitId: true, bookedById: true, societyId: true, halfDaySlot: true },
      });
      const bookedSlots = new Set(existing.map(b => b.halfDaySlot));
      const hasFullDay = bookedSlots.has('FULL');
      const conflict =
        hasFullDay ||
        (halfDaySlot === 'FULL' && (bookedSlots.has('FIRST_HALF') || bookedSlots.has('SECOND_HALF'))) ||
        bookedSlots.has(halfDaySlot);
      if (conflict) {
        const mine = existing.find((b) => b.societyId === societyId && b.unitId === unitId && b.bookedById === bookedById && b.halfDaySlot === halfDaySlot);
        if (mine) {
          const existingBooking = await prisma.amenityBooking.findUnique({
            where: { id: mine.id },
            include: {
              amenity: { select: { id: true, name: true, bookingType: true } },
              unit: { select: { id: true, fullCode: true } },
            },
          });
          const bill = await prisma.maintenanceBill.findFirst({
            where: {
              societyId,
              unitId,
              category: 'AMENITY',
              notes: `amenityBooking:${mine.id}`,
              deletedAt: null,
            },
            select: { id: true },
          });
          return sendSuccess(res, { ...existingBooking, billId: bill?.id || null }, 'Booking already exists');
        }
        return sendError(res, 'Selected slot is not available for this date', 409);
      }

      const split = amenity.firstHalfEnd || '13:00';
      fee = halfDaySlot === 'FULL' ? num(amenity.fullDayFee) : num(amenity.halfDayFee);
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
        select: { id: true, unitId: true, bookedById: true, societyId: true },
      });
      if (conflict) {
        if (conflict.societyId === societyId && conflict.unitId === unitId && conflict.bookedById === bookedById) {
          const existing = await prisma.amenityBooking.findUnique({
            where: { id: conflict.id },
            include: {
              amenity: { select: { id: true, name: true, bookingType: true } },
              unit: { select: { id: true, fullCode: true } },
            },
          });
          const bill = await prisma.maintenanceBill.findFirst({
            where: {
              societyId,
              unitId,
              category: 'AMENITY',
              notes: `amenityBooking:${conflict.id}`,
              deletedAt: null,
            },
            select: { id: true },
          });
          return sendSuccess(res, { ...existing, billId: bill?.id || null }, 'Booking already exists');
        }
        return sendError(res, 'This unit already has a monthly booking for this period', 409);
      }

      // Enforce per-amenity daily limit if set
      if (amenity.maxDailyHours && dailyHoursLimit && parseInt(dailyHoursLimit) > amenity.maxDailyHours) {
        return sendError(res, `Max allowed daily hours is ${amenity.maxDailyHours}`, 400);
      }

      fee = num(amenity.monthlyFee);
      bookingData = { ...bookingData, monthYear, dailyHoursLimit: dailyHoursLimit ? parseInt(dailyHoursLimit) : null, feeCharged: fee };
    }

    const status = amenity.requireApproval ? 'PENDING' : 'CONFIRMED';

    const booking = await prisma.$transaction(async (tx) => {
      const created = await tx.amenityBooking.create({
        data: { ...bookingData, status, paymentStatus: fee > 0 ? 'UNPAID' : null },
        include: {
          amenity: { select: { id: true, name: true, bookingType: true } },
          unit: { select: { id: true, fullCode: true } },
        },
      });

      let billId = null;
      if (fee > 0) {
        const dueDateForBill = (() => {
          if (created.bookingDate) return new Date(created.bookingDate);
          if (created.monthYear) return new Date(`${created.monthYear}-01T00:00:00.000Z`);
          return new Date();
        })();

        // NOTE: DB has a unique constraint on (unitId, billingMonth) in some deployments.
        // For non-maintenance bills (e.g., AMENITY), we use a unique timestamp so we don't
        // collide with monthly maintenance bills or other charges.
        const billingMonth = new Date();

        const billNotes = `amenityBooking:${created.id}`;
        const existingBill = await tx.maintenanceBill.findFirst({
          where: {
            societyId,
            unitId,
            category: 'AMENITY',
            notes: billNotes,
            deletedAt: null,
          },
          select: { id: true },
        });

        if (!existingBill) {
          const whenLabel = (() => {
            if (created.bookingDate) {
              const d = new Date(created.bookingDate);
              const y = d.getFullYear();
              const m = String(d.getMonth() + 1).padStart(2, '0');
              const day = String(d.getDate()).padStart(2, '0');
              return `${y}-${m}-${day}`;
            }
            if (created.monthYear) return created.monthYear;
            return '';
          })();

          const timeLabel =
            created.startTime && created.endTime ? ` (${created.startTime}-${created.endTime})` : '';

          const createdBill = await tx.maintenanceBill.create({
            data: {
              societyId,
              unitId,
              createdById: bookedById,
              billingMonth,
              amount: Number(fee),
              totalDue: Number(fee),
              paidAmount: 0,
              status: 'PENDING',
              dueDate: dueDateForBill,
              title: `Amenity Booking - ${created.amenity?.name || 'Amenity'}`,
              description: `Booking ${whenLabel}${timeLabel} for unit ${created.unit?.fullCode || ''}`.trim(),
              category: 'AMENITY',
              notes: billNotes,
            },
          });
          billId = createdBill.id;
        } else {
          billId = existingBill.id;
        }
      }

      return { ...created, billId };
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

    const bookingIds = bookings.map((b) => b.id);
    const bills = await prisma.maintenanceBill.findMany({
      where: {
        societyId,
        category: 'AMENITY',
        deletedAt: null,
        notes: { in: bookingIds.map((id) => `amenityBooking:${id}`) },
      },
      select: { id: true, notes: true },
    });
    const billMap = new Map(bills.map((b) => [b.notes, b.id]));
    const enriched = bookings.map((b) => ({ ...b, billId: billMap.get(`amenityBooking:${b.id}`) || null }));

    return sendSuccess(res, { bookings: enriched, total, page: parseInt(page), limit: parseInt(limit) });
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

    const bookingIds = bookings.map((b) => b.id);
    const bills = await prisma.maintenanceBill.findMany({
      where: {
        societyId,
        category: 'AMENITY',
        deletedAt: null,
        notes: { in: bookingIds.map((id) => `amenityBooking:${id}`) },
      },
      select: { id: true, notes: true, status: true, totalDue: true, paidAmount: true, dueDate: true },
    });
    const billMap = new Map(bills.map((b) => [b.notes, b]));
    const enriched = bookings.map((b) => {
      const bill = billMap.get(`amenityBooking:${b.id}`);
      return { ...b, billId: bill?.id || null, bill: bill || null };
    });

    return sendSuccess(res, { bookings: enriched, total, page: parseInt(page), limit: parseInt(limit) });
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

    // Enforce: fee-based bookings must be paid before CONFIRMED.
    if (status === 'CONFIRMED') {
      const bookingRow = await prisma.amenityBooking.findUnique({
        where: { id },
        select: { id: true, societyId: true, unitId: true, feeCharged: true },
      });
      if (!bookingRow || bookingRow.societyId !== societyId) {
        return sendError(res, 'Booking not found', 404);
      }

      const fee = Number(bookingRow.feeCharged || 0);
      if (fee > 0) {
        const bill = await prisma.maintenanceBill.findFirst({
          where: {
            societyId,
            unitId: bookingRow.unitId,
            category: 'AMENITY',
            notes: `amenityBooking:${bookingRow.id}`,
            deletedAt: null,
          },
          select: { id: true, status: true, totalDue: true, paidAmount: true },
        });
        const isPaid = bill?.status === 'PAID' || Number(bill?.paidAmount || 0) >= Number(bill?.totalDue || fee);
        if (!isPaid) {
          return sendError(res, 'Payment required before approving this booking', 400);
        }
      }
    }

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
