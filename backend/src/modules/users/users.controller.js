const usersService = require('./users.service');
const { sendSuccess, sendError } = require('../../utils/response');
const { validatePassword } = require('../../utils/password');

/**
 * GET /api/v1/users/me
 * Returns the authenticated user's own profile.
 */
async function getMe(req, res) {
  try {
    const user = await usersService.getProfile(req.user.id);
    return sendSuccess(res, user, 'Profile retrieved');
  } catch (error) {
    console.error('Get profile error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * GET /api/v1/users
 * List users in the authenticated user's society. Pramukh and Secretary only.
 */
async function listUsers(req, res) {
  try {
    const { role, isActive, page, limit } = req.query;

    const filters = {};
    if (role) filters.role = role;
    if (isActive !== undefined) filters.isActive = isActive === 'true';
    if (page) filters.page = parseInt(page, 10);
    if (limit) filters.limit = parseInt(limit, 10);

    const result = await usersService.listUsers(req.user.societyId, filters);
    return sendSuccess(res, result, 'Users retrieved');
  } catch (error) {
    console.error('List users error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/users
 * Create a new resident or watchman. Secretary only.
 */
async function createUser(req, res) {
  try {
    const { role, name, email, phone, password } = req.body;

    if (!name || !phone || !password || !role) {
      return sendError(res, 'Name, phone, password, and role are required', 400);
    }

    // Secretary can only create RESIDENT or WATCHMAN
    const allowedRoles = ['RESIDENT', 'WATCHMAN'];
    if (!allowedRoles.includes(role)) {
      return sendError(res, 'Can only create RESIDENT or WATCHMAN users', 400);
    }

    const pwCheck = validatePassword(password);
    if (!pwCheck.valid) {
      return sendError(res, pwCheck.message, 400);
    }

    const user = await usersService.createUser({
      societyId: req.user.societyId,
      role,
      name,
      email,
      phone,
      password,
    });

    return sendSuccess(res, user, 'User created', 201);
  } catch (error) {
    console.error('Create user error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * PATCH /api/v1/users/:id
 * Update a user's profile. Secretary can update anyone in their society;
 * users can update their own profile.
 */
async function updateUser(req, res) {
  try {
    const { id } = req.params;
    const isSelf = id === req.user.id;
    const isSecretary = req.user.role === 'SECRETARY';
    const isPramukh = req.user.role === 'PRAMUKH';
    const isSuperAdmin = req.user.role === 'SUPER_ADMIN';

    if (!isSelf && !isSecretary && !isPramukh && !isSuperAdmin) {
      return sendError(res, 'You can only update your own profile', 403);
    }

    // Self-updates are limited to name, email, phone, fcmToken
    const data = {};
    if (isSelf && !isSecretary && !isPramukh && !isSuperAdmin) {
      const { name, email, phone, fcmToken } = req.body;
      if (name !== undefined) data.name = name;
      if (email !== undefined) data.email = email;
      if (phone !== undefined) data.phone = phone;
      if (fcmToken !== undefined) data.fcmToken = fcmToken;
    } else {
      // Secretary/Pramukh/SuperAdmin can update more fields
      const { name, email, phone, fcmToken, isActive } = req.body;
      if (name !== undefined) data.name = name;
      if (email !== undefined) data.email = email;
      if (phone !== undefined) data.phone = phone;
      if (fcmToken !== undefined) data.fcmToken = fcmToken;
      if (isActive !== undefined) data.isActive = isActive;
    }

    const callerSocietyId = isSuperAdmin ? null : req.user.societyId;
    const user = await usersService.updateUser(id, data, callerSocietyId);
    return sendSuccess(res, user, 'User updated');
  } catch (error) {
    console.error('Update user error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * DELETE /api/v1/users/:id
 * Soft-delete a user. Pramukh only.
 */
async function deleteUser(req, res) {
  try {
    const { id } = req.params;
    const callerSocietyId = req.user.role === 'SUPER_ADMIN' ? null : req.user.societyId;
    const user = await usersService.softDeleteUser(id, callerSocietyId);
    return sendSuccess(res, user, 'User deleted');
  } catch (error) {
    console.error('Delete user error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getMe,
  listUsers,
  createUser,
  updateUser,
  deleteUser,
};
