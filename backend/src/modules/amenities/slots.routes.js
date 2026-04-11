const express = require('express');
const router = express.Router();
const { authenticateToken, validateAndSanitizeQuery } = require('../../middleware/auth.middleware');
const slotController = require('./slots.controller');

router.post(
  '/',
  [authenticateToken],
  slotController.createSlot
);

module.exports = router;
