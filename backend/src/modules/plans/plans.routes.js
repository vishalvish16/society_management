const { Router } = require('express');
const plansController = require('./plans.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// Public endpoint — no auth required (for pricing page)
router.get('/public', plansController.listPublicPlans);

// All other plan routes require SUPER_ADMIN
router.use(authMiddleware);
router.use(roleGuard('SUPER_ADMIN'));

router.get('/', plansController.listPlans);
router.get('/:id', plansController.getPlan);
router.post('/', plansController.createPlan);
router.patch('/:id', plansController.updatePlan);
router.delete('/:id', plansController.deactivatePlan);

module.exports = router;
