const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./bookings.controller');

router.use(auth);

const ALL_SOCIETY = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY',
  'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'MEMBER', 'RESIDENT'];
const ADMIN = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER'];

router.get('/mine', roleGuard(ALL_SOCIETY), c.listMyBookings);
router.get('/', roleGuard(ADMIN), c.listBookings);
router.post('/', roleGuard(ALL_SOCIETY), c.createBooking);
router.patch('/:id/status', roleGuard(ADMIN), c.updateBookingStatus);

module.exports = router;
