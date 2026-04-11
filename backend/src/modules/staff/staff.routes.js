const express = require('express');
const router = express.Router();
const { authenticateToken, validateAndSanitizeQuery } = require('../../middleware/auth.middleware');
const staffController = require('./staff.controller');

router.get(
  '/',
  [authenticateToken, validateAndSanitizeQuery],
  staffController.getAllStaffMembers
);

router.post(
  '/',
  [authenticateToken],
  staffController.createStaffMember
);

router.delete(
  '/:id',
  [authenticateToken],
  staffController.deleteStaffMemberById
);

module.exports = router;
