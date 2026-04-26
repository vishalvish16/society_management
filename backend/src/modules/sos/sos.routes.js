const { Router } = require('express');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const sosController = require('./sos.controller');

const router = Router();
router.use(authMiddleware);

// Watchman + society admins can trigger SOS to a unit
router.post(
  '/trigger',
  roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN', 'TREASURER', 'ASSISTANT_SECRETARY', 'ASSISTANT_TREASURER']),
  sosController.triggerSos
);

// Any authenticated user can acknowledge
router.post('/ack', sosController.acknowledgeSos);

module.exports = router;

