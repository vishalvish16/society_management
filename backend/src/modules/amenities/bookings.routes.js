const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./bookings.controller');

router.use(auth);

const ALL_SOCIETY = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY',
  'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'MEMBER', 'RESIDENT'];
const ADMIN = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER'];

router.get('/mine', roleGuard(ALL_SOCIETY), checkPlanLimit('amenity_booking'), c.listMyBookings);
router.get('/', roleGuard(ADMIN), checkPlanLimit('amenity_booking'), c.listBookings);
router.post('/', roleGuard(ALL_SOCIETY), checkPlanLimit('amenity_booking'), c.createBooking);
router.patch('/:id/status', roleGuard(ADMIN), checkPlanLimit('amenity_booking'), c.updateBookingStatus);

module.exports = router;
