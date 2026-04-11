const jwt = require('jsonwebtoken');

const JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;

if (!JWT_ACCESS_SECRET || !JWT_REFRESH_SECRET) {
  if (process.env.NODE_ENV !== 'test') {
    console.error('CRITICAL: JWT secrets are missing in environment variables!');
    process.exit(1);
  }
}

const ACCESS_EXPIRY = process.env.JWT_ACCESS_EXPIRY || '15m';
const REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '30d';

/**
 * Generate a short-lived access token.
 */
function generateAccessToken(payload) {
  return jwt.sign(payload, JWT_ACCESS_SECRET, { expiresIn: ACCESS_EXPIRY });
}

/**
 * Generate a long-lived refresh token.
 */
function generateRefreshToken(payload) {
  return jwt.sign(payload, JWT_REFRESH_SECRET, { expiresIn: REFRESH_EXPIRY });
}

/**
 * Verify a token with the given secret.
 */
function verifyToken(token, secret) {
  return jwt.verify(token, secret);
}

/**
 * Verify an access token.
 */
function verifyAccessToken(token) {
  return verifyToken(token, JWT_ACCESS_SECRET);
}

/**
 * Verify a refresh token.
 */
function verifyRefreshToken(token) {
  return verifyToken(token, JWT_REFRESH_SECRET);
}

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
  verifyAccessToken,
  verifyRefreshToken,
};
