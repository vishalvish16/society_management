const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./bookings.controller');

router.use(auth);

router.get('/mine', roleGuard(['RESIDENT', 'MEMBER']), c.listMyBookings);
router.get('/', c.listBookings);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.createBooking);
router.patch('/:id/status', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateBookingStatus);

module.exports = router;
