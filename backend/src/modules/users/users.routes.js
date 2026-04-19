const { Router } = require('express');
const usersController = require('./users.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const createUploader = require('../../middleware/uploadGeneric');

const router = Router();
const profileUpload = createUploader('profiles');

// All user routes require authentication
router.use(authMiddleware);

// GET /api/v1/users/me — own profile (any authenticated user)
router.get('/me', usersController.getMe);
router.patch('/me', profileUpload.single('profilePhoto'), usersController.patchMyProfile);

// GET /api/v1/users — list users (CHAIRMAN/secretary only)
router.get('/', roleGuard('PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'SUPER_ADMIN'), usersController.listUsers);

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

// DELETE /api/v1/users/:id — soft-delete (CHAIRMAN only)
router.delete('/:id', roleGuard('PRAMUKH', 'CHAIRMAN', 'SUPER_ADMIN'), usersController.deleteUser);

module.exports = router;
