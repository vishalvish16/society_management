const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

const getAllAmenities = async (req, res) => {
  try {
    const { societyId } = req.user;
    const amenities = await prisma.amenity.findMany({
      where: { societyId },
      orderBy: { name: 'asc' },
    });
    return sendSuccess(res, amenities, 'Amenities retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const createAmenity = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { name, description, capacity, bookingDuration, openTime, closeTime, bookingFee, maxAdvanceDays, rules, requireApproval } = req.body;

    if (!name || !openTime || !closeTime) {
      return sendError(res, 'name, openTime and closeTime are required', 400);
    }

    const amenity = await prisma.amenity.create({
      data: {
        societyId,
        name,
        description: description || null,
        capacity: capacity ? parseInt(capacity) : null,
        bookingDuration: bookingDuration ? parseInt(bookingDuration) : 60,
        openTime,
        closeTime,
        bookingFee: bookingFee ? Number(bookingFee) : 0,
        maxAdvanceDays: maxAdvanceDays ? parseInt(maxAdvanceDays) : 7,
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

const updateAmenity = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;

    const amenity = await prisma.amenity.findUnique({ where: { id } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);

    const { name, description, status, openTime, closeTime, bookingFee, requireApproval } = req.body;
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (status !== undefined) updateData.status = status;
    if (openTime !== undefined) updateData.openTime = openTime;
    if (closeTime !== undefined) updateData.closeTime = closeTime;
    if (bookingFee !== undefined) updateData.bookingFee = Number(bookingFee);
    if (requireApproval !== undefined) updateData.requireApproval = Boolean(requireApproval);

    const updated = await prisma.amenity.update({ where: { id }, data: updateData });
    return sendSuccess(res, updated, 'Amenity updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

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

// GET /api/amenities/:id/slots?date=YYYY-MM-DD
const getAvailableSlots = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id: amenityId } = req.params;
    const { date } = req.query;

    if (!date) return sendError(res, 'date query param is required (YYYY-MM-DD)', 400);

    const amenity = await prisma.amenity.findUnique({ where: { id: amenityId } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);
    if (amenity.status !== 'ACTIVE') return sendError(res, 'Amenity is not available', 400);

    // Check closure periods
    const bookingDate = new Date(date);
    const closures = amenity.closurePeriods || [];
    const isClosed = closures.some((c) => {
      const from = new Date(c.from);
      const to = new Date(c.to);
      return bookingDate >= from && bookingDate <= to;
    });
    if (isClosed) return sendError(res, 'Amenity is closed on this date', 400);

    // Generate time slots
    const slots = [];
    const [openH, openM] = amenity.openTime.split(':').map(Number);
    const [closeH, closeM] = amenity.closeTime.split(':').map(Number);
    let current = openH * 60 + openM;
    const end = closeH * 60 + closeM;
    while (current + amenity.bookingDuration <= end) {
      const hh = String(Math.floor(current / 60)).padStart(2, '0');
      const mm = String(current % 60).padStart(2, '0');
      const endMin = current + amenity.bookingDuration;
      const ehh = String(Math.floor(endMin / 60)).padStart(2, '0');
      const emm = String(endMin % 60).padStart(2, '0');
      slots.push({ startTime: `${hh}:${mm}`, endTime: `${ehh}:${emm}` });
      current += amenity.bookingDuration;
    }

    // Find already-booked slots
    const booked = await prisma.amenityBooking.findMany({
      where: {
        amenityId,
        bookingDate: new Date(date),
        status: { in: ['pending', 'confirmed'] },
      },
      select: { startTime: true },
    });
    const bookedTimes = new Set(booked.map((b) => b.startTime));

    const available = slots.map((s) => ({ ...s, available: !bookedTimes.has(s.startTime) }));
    return sendSuccess(res, available, 'Available slots retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/amenities/:id/bookings
const getAmenityBookings = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id: amenityId } = req.params;
    const { status, page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const amenity = await prisma.amenity.findUnique({ where: { id: amenityId } });
    if (!amenity || amenity.societyId !== societyId) return sendError(res, 'Amenity not found', 404);

    const where = { amenityId, societyId };
    if (status) where.status = status;

    const [bookings, total] = await Promise.all([
      prisma.amenityBooking.findMany({
        where, skip, take: parseInt(limit),
        include: { unit: { select: { fullCode: true } } },
        orderBy: { bookingDate: 'desc' },
      }),
      prisma.amenityBooking.count({ where }),
    ]);

    return sendSuccess(res, { bookings, total, page: parseInt(page), limit: parseInt(limit) }, 'Bookings retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { getAllAmenities, createAmenity, updateAmenity, deleteAmenityById, getAvailableSlots, getAmenityBookings };
