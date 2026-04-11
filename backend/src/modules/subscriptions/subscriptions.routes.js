const { Router } = require('express');
const subscriptionsController = require('./subscriptions.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// All subscription routes require SUPER_ADMIN
router.use(authMiddleware);
router.use(roleGuard('SUPER_ADMIN'));

router.get('/', subscriptionsController.listSubscriptions);
router.get('/:id', subscriptionsController.getSubscription);
router.post('/', subscriptionsController.assignPlan);
router.post('/:id/renew', subscriptionsController.renewSubscription);

module.exports = router;
