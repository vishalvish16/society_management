const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const authService = require('./auth.service');
const { generateAccessToken, generateRefreshToken } = require('../../utils/jwt');
const { sendSuccess, sendError } = require('../../utils/response');

// POST /api/auth/login
exports.login = async (req, res) => {
  try {
    const { phone, email, identifier, password } = req.body;
    const loginId = identifier || email || phone;
    if (!loginId || !password) return sendError(res, 'Phone/email and password are required', 400);

    const user = await prisma.user.findFirst({
      where: { OR: [{ phone: loginId }, { email: loginId }], isActive: true },
    });
    if (!user) return sendError(res, 'Invalid credentials', 401);

    const valid = await authService.comparePasswords(password, user.passwordHash);
    if (!valid) return sendError(res, 'Invalid credentials', 401);

    const payload = { id: user.id, role: user.role, societyId: user.societyId, name: user.name };
    const accessToken  = generateAccessToken(payload);
    const refreshToken = generateRefreshToken(payload);

    await prisma.refreshToken.create({
      data: { userId: user.id, token: refreshToken, expiresAt: new Date(Date.now() + 30*24*60*60*1000) },
    });

    return sendSuccess(res, {
      accessToken, refreshToken,
      user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, societyId: user.societyId, isActive: user.isActive },
    }, 'Login successful');
  } catch (err) {
    console.error('Login error:', err.message);
    return sendError(res, 'Authentication failed', 500);
  }
};

// POST /api/auth/register
exports.register = async (req, res) => {
  try {
    const { name, phone, email, password, role = 'resident', societyId } = req.body;
    if (!name || !phone || !password) return sendError(res, 'Name, phone and password are required', 400);

    const existing = await prisma.user.findFirst({ where: { OR: [{ phone }, ...(email ? [{ email }] : [])] } });
    if (existing) return sendError(res, 'Phone or email already registered', 409);

    const passwordHash = await authService.hashPassword(password);
    const user = await prisma.user.create({ data: { name, phone, email, passwordHash, role, societyId } });

    const payload = { id: user.id, role: user.role, societyId: user.societyId };
    const accessToken = generateAccessToken(payload);

    return sendSuccess(res, {
      accessToken,
      user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role },
    }, 'Registration successful', 201);
  } catch (err) {
    console.error('Register error:', err.message);
    return sendError(res, 'Registration failed', 500);
  }
};

// POST /api/auth/logout
exports.logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) await prisma.refreshToken.deleteMany({ where: { token: refreshToken } });
    return sendSuccess(res, null, 'Logged out successfully');
  } catch (_) {
    return sendSuccess(res, null, 'Logged out');
  }
};

// GET /api/auth/me  (alias for /users/me)
exports.me = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { id: true, name: true, email: true, phone: true, role: true, societyId: true, isActive: true },
    });
    if (!user) return sendError(res, 'User not found', 404);
    return sendSuccess(res, user);
  } catch (err) {
    return sendError(res, 'Failed to fetch user', 500);
  }
};
