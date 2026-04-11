const { Router } = require('express');
const usersController = require('./users.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

// All user routes require authentication
router.use(authMiddleware);

// GET /api/v1/users/me — own profile (any authenticated user)
router.get('/me', usersController.getMe);

// GET /api/v1/users — list users (pramukh/secretary only)
router.get('/', roleGuard('PRAMUKH', 'SECRETARY', 'SUPER_ADMIN'), usersController.listUsers);

// POST /api/v1/users — create resident/watchman (secretary only)
// Dynamic plan limit check based on the role being created
router.post(
  '/',
  roleGuard('SECRETARY', 'SUPER_ADMIN'),
  (req, res, next) => {
    const role = req.body.role;
    if (role === 'RESIDENT') return checkPlanLimit('residents')(req, res, next);
    if (role === 'WATCHMAN') return checkPlanLimit('watchmen')(req, res, next);
    next();
  },
  usersController.createUser
);

// PATCH /api/v1/users/:id — update profile (secretary or self)
router.patch('/:id', usersController.updateUser);

// DELETE /api/v1/users/:id — soft-delete (pramukh only)
router.delete('/:id', roleGuard('PRAMUKH', 'SUPER_ADMIN'), usersController.deleteUser);

module.exports = router;
