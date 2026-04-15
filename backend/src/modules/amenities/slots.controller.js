const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * Slots are not a separate model — availability is derived from AmenityBooking.
 * This controller returns available time windows for a given amenity + date.
 */
async function getAvailableSlots(req, res, next) {
  try {
    const { amenityId, date } = req.query;
    const societyId = req.user.societyId;

    if (!amenityId || !date) {
      return sendError(res, 'amenityId and date are required', 400);
    }

    const amenity = await prisma.amenity.findUnique({
      where: { id: amenityId },
      select: { id: true, name: true, status: true, societyId: true },
    });

    if (!amenity || amenity.societyId !== societyId) {
      return sendError(res, 'Amenity not found', 404);
    }

    if (amenity.status !== 'ACTIVE') {
      return sendError(res, 'Amenity is not available for booking', 400);
    }

    // Return booked slots for that date so client can compute availability
    const bookedSlots = await prisma.amenityBooking.findMany({
      where: {
        amenityId,
        societyId,
        bookingDate: new Date(date),
        status: { in: ['pending', 'confirmed'] },
      },
      select: { startTime: true, endTime: true, status: true },
      orderBy: { startTime: 'asc' },
    });

    return sendSuccess(res, { amenity, bookedSlots, date }, 'Slots retrieved');
  } catch (err) {
    next(err);
  }
}

module.exports = { getAvailableSlots };
