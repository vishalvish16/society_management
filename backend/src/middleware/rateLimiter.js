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

module.exports = { loginLimiter, forgotPasswordLimiter, verifyOtpLimiter };
