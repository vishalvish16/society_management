const express = require('express');
const router = express.Router();
const { authenticateToken, validateAndSanitizeQuery } = require('../../middleware/auth.middleware');
const domestichelpController = require('./domestichelp.controller');

router.post(
  '/',
  [authenticateToken],
  domestichelpController.createDomesticHelp
);

router.get(
  '/:id',
  [authenticateToken],
  domestichelpController.getCodeById
);

module.exports = router;
