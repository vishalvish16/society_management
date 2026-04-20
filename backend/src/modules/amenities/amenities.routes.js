const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./amenities.controller');

router.use(auth);

// Bookings mine — must be before /:id routes
router.use('/bookings', require('./bookings.routes'));

router.get('/', checkPlanLimit('amenities'), c.getAllAmenities);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('amenities'), c.createAmenity);
router.get('/:id/slots', checkPlanLimit('amenities'), c.getAvailableSlots);
router.get('/:id/calendar', checkPlanLimit('amenities'), c.getCalendar);
router.get('/:id/bookings', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('amenities'), c.getAmenityBookings);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('amenities'), c.updateAmenity);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('amenities'), c.deleteAmenityById);

module.exports = router;
