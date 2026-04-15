const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

async function createBooking(req, res, next) {
  try {
    const { amenityId, unitId, bookingDate, startTime, endTime, guestCount, purpose } = req.body;
    const societyId  = req.user.societyId;
    const bookedById = req.user.id;

    if (!amenityId || !unitId || !bookingDate || !startTime || !endTime) {
      return sendError(res, 'amenityId, unitId, bookingDate, startTime, endTime are required', 400);
    }

    const booking = await prisma.amenityBooking.create({
      data: {
        amenityId,
        societyId,
        unitId,
        bookedById,
        bookingDate: new Date(bookingDate),
        startTime,
        endTime,
        guestCount: guestCount || null,
        purpose:    purpose    || null,
      },
      select: {
        id: true, bookingDate: true, startTime: true, endTime: true,
        status: true, guestCount: true, purpose: true, createdAt: true,
        amenity: { select: { id: true, name: true } },
        unit:    { select: { id: true, fullCode: true } },
      },
    });

    return sendSuccess(res, booking, 'Booking created', 201);
  } catch (err) {
    if (err.code === 'P2002') return sendError(res, 'This time slot is already booked', 409);
    next(err);
  }
}

async function listBookings(req, res, next) {
  try {
    const societyId = req.user.societyId;
    const { amenityId, status, page = 1, limit = 20 } = req.query;
    const where = { societyId };
    if (amenityId) where.amenityId = amenityId;
    if (status)    where.status    = status;

    const [bookings, total] = await Promise.all([
      prisma.amenityBooking.findMany({
        where,
        select: {
          id: true, bookingDate: true, startTime: true, endTime: true,
          status: true, guestCount: true, purpose: true, feeCharged: true, createdAt: true,
          amenity:  { select: { id: true, name: true } },
          unit:     { select: { id: true, fullCode: true } },
        },
        orderBy: { bookingDate: 'desc' },
        skip: (parseInt(page) - 1) * parseInt(limit),
        take: parseInt(limit),
      }),
      prisma.amenityBooking.count({ where }),
    ]);

    return sendSuccess(res, { bookings, total, page: parseInt(page), limit: parseInt(limit) }, 'Bookings retrieved');
  } catch (err) {
    next(err);
  }
}

async function updateBookingStatus(req, res, next) {
  try {
    const { id } = req.params;
    const { status, cancelReason } = req.body;
    const societyId = req.user.societyId;

    const booking = await prisma.amenityBooking.update({
      where: { id, societyId },
      data: {
        status,
        ...(status === 'cancelled' ? { cancelledAt: new Date(), cancelReason } : {}),
        ...(status === 'confirmed' ? { approvedById: req.user.id, approvedAt: new Date() } : {}),
      },
      select: { id: true, status: true, updatedAt: true },
    });

    return sendSuccess(res, booking, 'Booking updated');
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Booking not found', 404);
    next(err);
  }
}

async function listMyBookings(req, res, next) {
  try {
    const { societyId, id: bookedById } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const where = { societyId, bookedById };
    if (status) where.status = status;

    const [bookings, total] = await Promise.all([
      prisma.amenityBooking.findMany({
        where,
        select: {
          id: true, bookingDate: true, startTime: true, endTime: true,
          status: true, guestCount: true, purpose: true, feeCharged: true, createdAt: true,
          amenity: { select: { id: true, name: true } },
          unit:    { select: { id: true, fullCode: true } },
        },
        orderBy: { bookingDate: 'desc' },
        skip: (parseInt(page) - 1) * parseInt(limit),
        take: parseInt(limit),
      }),
      prisma.amenityBooking.count({ where }),
    ]);

    return sendSuccess(res, { bookings, total, page: parseInt(page), limit: parseInt(limit) }, 'Your bookings retrieved');
  } catch (err) {
    next(err);
  }
}

module.exports = { createBooking, listBookings, listMyBookings, updateBookingStatus };
