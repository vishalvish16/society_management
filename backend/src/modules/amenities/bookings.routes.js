const express = require('express');
const router = express.Router();
const { authenticateToken, validateAndSanitizeQuery } = require('../../middleware/auth.middleware');
const bookingController = require('./bookings.controller');

router.post(
  '/',
  [authenticateToken],
  bookingController.createBooking
);

module.exports = router;
