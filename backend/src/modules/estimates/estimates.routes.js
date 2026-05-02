const { Router } = require('express');
const ctrl = require('./estimates.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// All estimate routes require SUPER_ADMIN
router.use(authMiddleware);
router.use(roleGuard('SUPER_ADMIN'));

router.get('/', ctrl.listEstimates);
router.get('/accepted-unlinked', ctrl.getAcceptedUnlinked);
router.get('/:id', ctrl.getEstimate);
router.post('/', ctrl.createEstimate);
router.patch('/:id', ctrl.updateEstimate);
router.post('/:id/send', ctrl.sendEstimate);
router.post('/:id/accept', ctrl.acceptEstimate);
router.post('/:id/close', ctrl.closeEstimate);

module.exports = router;
