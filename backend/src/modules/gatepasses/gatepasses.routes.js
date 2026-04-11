const express = require('express');
const router = express.Router();
const { authenticateToken, validateAndSanitizeQuery } = require('../../middleware/auth.middleware');
const gatepassController = require('./gatepasses.controller');

router.post(
  '/',
  [authenticateToken],
  gatepassController.createGatePass
);

module.exports = router;
