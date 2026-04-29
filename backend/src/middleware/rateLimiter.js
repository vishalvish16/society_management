const rateLimit = require('express-rate-limit');

/**
 * Rate limiter for login: max 5 attempts per 15 minutes per IP.
 */
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    message: 'Too many login attempts. Please try again after 15 minutes.',
  },
});

/**
 * Rate limiter for forgot-password: max 3 attempts per hour per IP.
 */
const forgotPasswordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    message: 'Too many password reset requests. Please try again after 1 hour.',
  },
});

/**
 * Rate limiter for verify-otp: max 5 attempts per 10 minutes per IP.
 */
const verifyOtpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    message: 'Too many OTP verification attempts. Please try again after 10 minutes.',
  },
});

/**
 * General API limiter: 100 requests per 15 minutes per IP.
 * Applied to all /api/* routes. Authenticated admin users get higher limits.
 */
const generalApiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.user?.role === 'SUPER_ADMIN',
  message: {
    success: false,
    data: null,
    message: 'Too many requests. Please slow down and try again shortly.',
  },
});

/**
 * File upload limiter: max 20 uploads per 15 minutes per IP.
 * Prevents DoS via large repeated uploads.
 */
const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    message: 'Too many file uploads. Please try again later.',
  },
});

/**
 * Payment endpoint limiter: max 10 attempts per 15 minutes per IP.
 */
const paymentLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    message: 'Too many payment requests. Please try again later.',
  },
});

module.exports = {
  loginLimiter,
  forgotPasswordLimiter,
  verifyOtpLimiter,
  generalApiLimiter,
  uploadLimiter,
  paymentLimiter,
};
