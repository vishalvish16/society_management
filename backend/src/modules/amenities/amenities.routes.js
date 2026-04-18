const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./amenities.controller');

router.use(auth);

// Bookings mine — must be before /:id routes
router.use('/bookings', require('./bookings.routes'));

router.get('/', c.getAllAmenities);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createAmenity);
router.get('/:id/slots', c.getAvailableSlots);
router.get('/:id/calendar', c.getCalendar);
router.get('/:id/bookings', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getAmenityBookings);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateAmenity);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteAmenityById);

module.exports = router;
