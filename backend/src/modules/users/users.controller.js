const usersService = require('./users.service');
const { sendSuccess, sendError } = require('../../utils/response');
const { validatePassword } = require('../../utils/password');
const prisma = require('../../config/db');

/** Parse optional profile fields from JSON or multipart string values. */
function parseProfileFields(body) {
  const data = {};
  const b = body || {};

  if (b.dateOfBirth !== undefined) {
    if (b.dateOfBirth === null) data.dateOfBirth = null;
    else {
      const raw = String(b.dateOfBirth).trim();
      if (!raw || raw === 'null') data.dateOfBirth = null;
      else {
        const d = new Date(raw);
        if (Number.isNaN(d.getTime())) return { error: 'Invalid date of birth' };
        data.dateOfBirth = d;
      }
    }
  }

  if (b.householdMemberCount !== undefined) {
    if (b.householdMemberCount === null) data.householdMemberCount = null;
    else {
      const raw = String(b.householdMemberCount).trim();
      if (!raw || raw === 'null') data.householdMemberCount = null;
      else {
        const n = parseInt(raw, 10);
        if (Number.isNaN(n) || n < 1 || n > 99) return { error: 'People in home must be between 1 and 99' };
        data.householdMemberCount = n;
      }
    }
  }

  if (b.bio !== undefined) {
    if (b.bio === null) data.bio = null;
    else {
      let t = String(b.bio).trim();
      if (t.length > 500) t = t.slice(0, 500);
      data.bio = t.length ? t : null;
    }
  }

  if (b.emergencyContactName !== undefined) {
    if (b.emergencyContactName === null) data.emergencyContactName = null;
    else {
      const t = String(b.emergencyContactName).trim();
      data.emergencyContactName = t.length ? t : null;
    }
  }

  if (b.emergencyContactPhone !== undefined) {
    if (b.emergencyContactPhone === null) data.emergencyContactPhone = null;
    else {
      const t = String(b.emergencyContactPhone).trim();
      data.emergencyContactPhone = t.length ? t : null;
    }
  }

  if (b.profilePhotoUrl === null || b.profilePhotoUrl === '') {
    data.profilePhotoUrl = null;
  }

  return { data };
}

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
 * List users in the authenticated user's society. Chairman and Secretary only.
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
    // `PATCH /users/me` must hit patchMyProfile, but if it ever matches `/:id`
    // (e.g. older route order), `id` is the literal "me" — treat as self.
    let { id } = req.params;
    if (id === 'me') id = req.user.id;
    const isSelf = String(id) === String(req.user.id);
    const isSecretary = req.user.role === 'SECRETARY';
    const isChairman = req.user.role === 'PRAMUKH' || req.user.role === 'CHAIRMAN';
    const isSuperAdmin = req.user.role === 'SUPER_ADMIN';

    if (!isSelf && !isSecretary && !isChairman && !isSuperAdmin) {
      return sendError(res, 'You can only update your own profile', 403);
    }

    // Secretary can only manage MEMBER/RESIDENT users (or self). Never PRAMUKH/CHAIRMAN/etc.
    if (isSecretary && !isSelf) {
      const target = await prisma.user.findUnique({
        where: { id },
        select: { id: true, role: true, societyId: true, deletedAt: true },
      });
      if (!target || target.deletedAt) return sendError(res, 'User not found', 404);
      if (target.societyId !== req.user.societyId) {
        return sendError(res, 'Cannot modify users outside your society', 403);
      }
      if (!['MEMBER', 'RESIDENT'].includes(target.role)) {
        return sendError(res, `Secretary cannot modify ${target.role} accounts`, 403);
      }
      // Also block secretary from toggling activation in this module (keep de/activation to Chairman flow)
      if (req.body?.isActive !== undefined) {
        return sendError(res, 'Secretary cannot change account status', 403);
      }
    }

    // Self-updates are limited to name, email, phone, fcmToken
    const data = {};
    if (isSelf && !isSecretary && !isChairman && !isSuperAdmin) {
      const { name, email, phone, fcmToken } = req.body;
      if (name !== undefined) data.name = name;
      if (email !== undefined) data.email = email;
      if (phone !== undefined) data.phone = phone;
      if (fcmToken !== undefined) data.fcmToken = fcmToken;
      const parsed = parseProfileFields(req.body);
      if (parsed.error) return sendError(res, parsed.error, 400);
      Object.assign(data, parsed.data);
    } else {
      // Secretary/Chairman/SuperAdmin can update more fields
      const { name, email, phone, fcmToken, isActive } = req.body;
      if (name !== undefined) data.name = name;
      if (email !== undefined) data.email = email;
      if (phone !== undefined) data.phone = phone;
      if (fcmToken !== undefined) data.fcmToken = fcmToken;
      if (isActive !== undefined) data.isActive = isActive;

      if (isSelf) {
        const parsed = parseProfileFields(req.body);
        if (parsed.error) return sendError(res, parsed.error, 400);
        Object.assign(data, parsed.data);
      }
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
 * Soft-delete a user. Chairman only.
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

/**
 * PATCH /api/users/me
 * Update own profile; optional multipart file field `profilePhoto` (JPEG/PNG).
 * Form fields or JSON: name, email, phone, dateOfBirth, householdMemberCount, bio,
 * emergencyContactName, emergencyContactPhone, clearProfilePhoto=true
 */
async function patchMyProfile(req, res) {
  try {
    const b = req.body || {};
    const data = {};

    if (b.name !== undefined) {
      const n = String(b.name).trim();
      if (!n) return sendError(res, 'Name cannot be empty', 400);
      data.name = n;
    }
    if (b.email !== undefined) {
      const e = String(b.email).trim();
      data.email = e.length ? e : null;
    }
    if (b.phone !== undefined) {
      const p = String(b.phone).trim();
      if (!p) return sendError(res, 'Phone cannot be empty', 400);
      data.phone = p;
    }
    if (b.fcmToken !== undefined) data.fcmToken = b.fcmToken;

    const parsed = parseProfileFields(b);
    if (parsed.error) return sendError(res, parsed.error, 400);
    Object.assign(data, parsed.data);

    if (req.file) {
      data.profilePhotoUrl = `/uploads/profiles/${req.file.filename}`;
    } else if (b.clearProfilePhoto === 'true' || b.clearProfilePhoto === true) {
      data.profilePhotoUrl = null;
    }

    const callerSocietyId = req.user.role === 'SUPER_ADMIN' ? null : req.user.societyId;

    if (Object.keys(data).length > 0) {
      await usersService.updateUser(req.user.id, data, callerSocietyId);
    }

    const user = await usersService.getProfile(req.user.id);
    return sendSuccess(res, user, 'Profile updated');
  } catch (error) {
    console.error('Patch profile error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getMe,
  patchMyProfile,
  listUsers,
  createUser,
  updateUser,
  deleteUser,
};
