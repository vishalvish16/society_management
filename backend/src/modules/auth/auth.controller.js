const crypto = require('crypto');
const prisma = require('../../config/db');
const authService = require('./auth.service');
const { generateAccessToken, generateRefreshToken, verifyRefreshToken } = require('../../utils/jwt');
const { sendSuccess, sendError } = require('../../utils/response');
const { isResidentLikeRole } = require('../../utils/unitResident');

// ─── Role enum values (match schema exactly) ───────────────────────────────
const VALID_ROLES = ['SUPER_ADMIN', 'PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER', 'MEMBER', 'RESIDENT', 'WATCHMAN'];

// ─── POST /api/auth/check-societies ───────────────────────────────────────
// Step 1 of multi-society login: validate credentials, return society list if
// the phone/email exists in more than one society. Returns:
//   { requiresSocietySelection: true, societies: [{id, name, logoUrl}] }
//   OR
//   { requiresSocietySelection: false, ...full login payload }
exports.checkSocieties = async (req, res) => {
  try {
    const { identifier, password } = req.body;
    if (!identifier || !password) {
      return sendError(res, 'Phone/email and password are required', 400);
    }

    // Find ALL active user records matching this identifier (across all societies)
    const users = await prisma.user.findMany({
      where: {
        OR: [{ phone: identifier }, { email: identifier }],
        isActive: true,
        deletedAt: null,
      },
      include: {
        society: { select: { id: true, name: true, logoUrl: true, status: true } },
        unitResidents: {
          select: { unit: { select: { id: true, fullCode: true } } },
          take: 1,
        },
      },
    });

    if (users.length === 0) return sendError(res, 'Invalid credentials', 401);

    // Validate password against first matched record (same passwordHash across records for same person)
    const valid = await authService.comparePasswords(password, users[0].passwordHash);
    if (!valid) return sendError(res, 'Invalid credentials', 401);

    // Filter out suspended societies
    const activeUsers = users.filter(u => u.society?.status !== 'suspended' || !u.societyId);

    if (activeUsers.length === 0) {
      return sendError(res, 'All associated societies are suspended. Contact your administrator.', 403);
    }

    // Multiple societies → ask user to pick
    if (activeUsers.length > 1) {
      const societies = activeUsers.map(u => ({
        userId: u.id,
        societyId: u.societyId,
        societyName: u.society?.name ?? 'Unknown Society',
        logoUrl: u.society?.logoUrl ?? null,
        role: u.role,
        unitCode: u.unitResidents?.[0]?.unit?.fullCode ?? null,
      }));
      return sendSuccess(res, { requiresSocietySelection: true, societies }, 'Multiple societies found');
    }

    // Single society → complete login immediately
    const user = activeUsers[0];
    return _issueTokens(res, user);
  } catch (err) {
    console.error('Check societies error:', err.message);
    if (err.code) console.error('  code:', err.code, err.meta || '');
    if (err.stack) console.error(err.stack.split('\n').slice(0, 4).join('\n'));
    const msg = _authFailureMessage(err);
    return sendError(res, msg, 500);
  }
};

// ─── POST /api/auth/login ──────────────────────────────────────────────────
// Accepts optional `userId` (from society selection step) or falls back to
// identifier+password lookup for direct single-society login.
exports.login = async (req, res) => {
  try {
    const { phone, email, identifier, password, userId } = req.body;
    const loginId = identifier || email || phone;
    if (!loginId || !password) return sendError(res, 'Phone/email and password are required', 400);

    let user;

    const societyInclude = {
      select: {
        id: true,
        name: true,
        status: true,
        plan: { select: { name: true, displayName: true, features: true } },
      },
    };

    if (userId) {
      // Society was already selected — fetch that specific user record
      user = await prisma.user.findFirst({
        where: { id: userId, isActive: true, deletedAt: null },
        include: {
          society: societyInclude,
          unitResidents: {
            select: { unit: { select: { id: true, fullCode: true } }, isOwner: true },
            take: 1,
          },
        },
      });
    } else {
      user = await prisma.user.findFirst({
        where: {
          OR: [{ phone: loginId }, { email: loginId }],
          isActive: true,
          deletedAt: null,
        },
        include: {
          society: societyInclude,
          unitResidents: {
            select: { unit: { select: { id: true, fullCode: true } }, isOwner: true },
            take: 1,
          },
        },
      });
    }

    if (!user) return sendError(res, 'Invalid credentials', 401);

    if (user.societyId && user.society?.status === 'suspended') {
      return sendError(res, 'Society is suspended. Contact your administrator.', 403);
    }

    const valid = await authService.comparePasswords(password, user.passwordHash);
    if (!valid) return sendError(res, 'Invalid credentials', 401);

    return _issueTokens(res, user);
  } catch (err) {
    console.error('Login error:', err.message);
    if (err.code) console.error('  code:', err.code, err.meta || '');
    if (err.stack) console.error(err.stack.split('\n').slice(0, 4).join('\n'));
    const msg = _authFailureMessage(err);
    return sendError(res, msg, 500);
  }
};

/** Map infra / Prisma errors to a safe client hint (avoid leaking secrets). */
function _authFailureMessage(err) {
  const code = err && err.code;
  const m = (err && err.message) || '';
  if (code === 'P1001' || code === 'P1017') {
    return 'Cannot reach the database. Check DATABASE_URL and that the database is running.';
  }
  if (code === 'P2022' || /column .+ does not exist|Unknown column/i.test(m)) {
    return 'Database schema is out of date. Run pending Prisma migrations on the server.';
  }
  if (/JWT_ACCESS_SECRET|JWT_REFRESH_SECRET|secret or public key must be provided/i.test(m)) {
    return 'Server auth configuration is incomplete (JWT secrets).';
  }
  return 'Authentication failed';
}

// Shared helper — generates tokens and returns full login payload
async function _issueTokens(res, user) {
  // Determine the active unit deterministically for resident-like roles.
  // This avoids Prisma returning an arbitrary UnitResident when the user is linked to multiple units.
  let activeUnit = user.unitResidents?.[0]?.unit || null;
  if (user.societyId && isResidentLikeRole(user.role)) {
    const ur = await prisma.unitResident.findFirst({
      where: {
        userId: user.id,
        isStaying: true,
        unit: { societyId: user.societyId },
      },
      orderBy: [{ isOwner: 'desc' }, { createdAt: 'desc' }],
      select: { unit: { select: { id: true, fullCode: true } } },
    });
    activeUnit = ur?.unit || activeUnit;
  }

  const payload = {
    id: user.id,
    role: user.role,
    societyId: user.societyId,
    name: user.name,
    unitId: activeUnit?.id || null,
  };
  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);

  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      token: refreshToken,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });

  return sendSuccess(res, {
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      societyId: user.societyId,
      society: user.society,
      isActive: user.isActive,
      unit: activeUnit,
      profilePhotoUrl: user.profilePhotoUrl ?? null,
      dateOfBirth: user.dateOfBirth ?? null,
      householdMemberCount: user.householdMemberCount ?? null,
      bio: user.bio ?? null,
      emergencyContactName: user.emergencyContactName ?? null,
      emergencyContactPhone: user.emergencyContactPhone ?? null,
      planFeatures: user.society?.plan?.features ?? null,
    },
  }, 'Login successful');
}

// ─── POST /api/auth/refresh ────────────────────────────────────────────────
exports.refresh = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return sendError(res, 'Refresh token is required', 400);

    // Verify token signature
    let decoded;
    try {
      decoded = verifyRefreshToken(refreshToken);
    } catch {
      return sendError(res, 'Invalid or expired refresh token', 401);
    }

    // Check token exists in DB (not revoked)
    const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!stored || stored.expiresAt < new Date()) {
      return sendError(res, 'Refresh token expired or revoked', 401);
    }

    // Rotate: delete old, issue new
    await prisma.refreshToken.delete({ where: { token: refreshToken } });

    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: { id: true, name: true, role: true, societyId: true, isActive: true },
    });
    if (!user || !user.isActive) return sendError(res, 'User not found or deactivated', 401);

    let activeUnitId = null;
    if (user.societyId && isResidentLikeRole(user.role)) {
      const ur = await prisma.unitResident.findFirst({
        where: {
          userId: user.id,
          isStaying: true,
          unit: { societyId: user.societyId },
        },
        orderBy: [{ isOwner: 'desc' }, { createdAt: 'desc' }],
        select: { unitId: true },
      });
      activeUnitId = ur?.unitId || null;
    }

    const payload = {
      id: user.id,
      role: user.role,
      societyId: user.societyId,
      name: user.name,
      unitId: activeUnitId,
    };
    const newAccessToken  = generateAccessToken(payload);
    const newRefreshToken = generateRefreshToken(payload);

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: newRefreshToken,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    return sendSuccess(res, { accessToken: newAccessToken, refreshToken: newRefreshToken }, 'Token refreshed');
  } catch (err) {
    console.error('Refresh error:', err.message);
    return sendError(res, 'Token refresh failed', 500);
  }
};

// ─── POST /api/auth/logout ─────────────────────────────────────────────────
exports.logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) await prisma.refreshToken.deleteMany({ where: { token: refreshToken } });
    return sendSuccess(res, null, 'Logged out successfully');
  } catch {
    return sendSuccess(res, null, 'Logged out');
  }
};

// ─── POST /api/auth/change-password (requires auth) ───────────────────────
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return sendError(res, 'currentPassword and newPassword are required', 400);
    }
    if (newPassword.length < 8) {
      return sendError(res, 'New password must be at least 8 characters', 400);
    }

    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) return sendError(res, 'User not found', 404);

    const valid = await authService.comparePasswords(currentPassword, user.passwordHash);
    if (!valid) return sendError(res, 'Current password is incorrect', 400);

    const newHash = await authService.hashPassword(newPassword);
    await prisma.user.update({ where: { id: user.id }, data: { passwordHash: newHash } });

    // Revoke all refresh tokens (force re-login on other devices)
    await prisma.refreshToken.deleteMany({ where: { userId: user.id } });

    return sendSuccess(res, null, 'Password changed successfully');
  } catch (err) {
    console.error('Change password error:', err.message);
    return sendError(res, 'Failed to change password', 500);
  }
};

// ─── POST /api/auth/forgot-password ───────────────────────────────────────
// Generates a 6-digit OTP stored in DB (no Redis/WhatsApp for now)
exports.forgotPassword = async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) return sendError(res, 'Phone number is required', 400);

    const user = await prisma.user.findFirst({ where: { phone, isActive: true, deletedAt: null } });
    // Always return success to avoid user enumeration
    if (!user) return sendSuccess(res, null, 'If account exists, OTP sent');

    const otp = crypto.randomInt(100000, 1000000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Store OTP as a temporary marker in fcmToken field (or a dedicated table if available)
    // We store it as JSON in a special refresh token record with token = "OTP:<otp>"
    await prisma.refreshToken.deleteMany({ where: { userId: user.id, token: { startsWith: 'OTP:' } } });
    await prisma.refreshToken.create({
      data: { userId: user.id, token: `OTP:${otp}`, expiresAt },
    });

    // In development only: log OTP to server console (never to client response)
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[OTP-DEV] User ${user.id}: ${otp}`);
    }
    // TODO: send OTP via WhatsApp/SMS in production

    return sendSuccess(res, null, 'OTP sent successfully');
  } catch (err) {
    console.error('Forgot password error:', err.message);
    return sendError(res, 'Failed to send OTP', 500);
  }
};

// ─── POST /api/auth/verify-otp ────────────────────────────────────────────
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp, newPassword } = req.body;
    if (!phone || !otp || !newPassword) {
      return sendError(res, 'phone, otp and newPassword are required', 400);
    }
    if (newPassword.length < 8) {
      return sendError(res, 'New password must be at least 8 characters', 400);
    }

    const user = await prisma.user.findFirst({ where: { phone, isActive: true, deletedAt: null } });
    if (!user) return sendError(res, 'Invalid OTP', 400);

    const otpRecord = await prisma.refreshToken.findFirst({
      where: { userId: user.id, token: `OTP:${otp}`, expiresAt: { gte: new Date() } },
    });
    if (!otpRecord) return sendError(res, 'Invalid or expired OTP', 400);

    // Delete OTP record
    await prisma.refreshToken.delete({ where: { id: otpRecord.id } });

    // Update password
    const newHash = await authService.hashPassword(newPassword);
    await prisma.user.update({ where: { id: user.id }, data: { passwordHash: newHash } });

    return sendSuccess(res, null, 'Password reset successfully');
  } catch (err) {
    console.error('Verify OTP error:', err.message);
    return sendError(res, 'OTP verification failed', 500);
  }
};

// ─── GET /api/auth/me ──────────────────────────────────────────────────────
exports.me = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true, name: true, email: true, phone: true,
        role: true, societyId: true, isActive: true, fcmToken: true,
        profilePhotoUrl: true,
        dateOfBirth: true,
        householdMemberCount: true,
        bio: true,
        emergencyContactName: true,
        emergencyContactPhone: true,
        society: { select: { id: true, name: true, logoUrl: true } },
        unitResidents: {
          select: {
            isOwner: true,
            unit: { select: { id: true, fullCode: true, wing: true, unitNumber: true } },
          },
        },
      },
    });
    if (!user) return sendError(res, 'User not found', 404);
    return sendSuccess(res, user);
  } catch (err) {
    return sendError(res, 'Failed to fetch user', 500);
  }
};
