const crypto = require('crypto');
const redis = require('../config/redis');

const { OTP_TTL_SECONDS, MAX_OTP_ATTEMPTS } = require('../config/constants');


/**
 * Generate a 6-digit numeric OTP and store it in Redis.
 * @param {string} phone - Phone number to associate the OTP with
 * @returns {Promise<string>} The generated OTP
 */
async function generateAndStoreOTP(phone) {
  const otp = crypto.randomInt(100000, 999999).toString();
  const key = `otp:${phone}`;
  const attemptsKey = `otp_attempts:${phone}`;
  
  await Promise.all([
    redis.set(key, otp, 'EX', OTP_TTL_SECONDS),
    redis.set(attemptsKey, '0', 'EX', OTP_TTL_SECONDS)
  ]);
  
  return otp;
}

/**
 * Verify an OTP against the stored value in Redis.
 * Increments an attempt counter; if it exceeds MAX_OTP_ATTEMPTS, the OTP is deleted.
 * @param {string} phone - Phone number the OTP was sent to
 * @param {string} otp - OTP to verify
 * @returns {Promise<boolean>} Whether the OTP is valid
 */
async function verifyOTP(phone, otp) {
  const key = `otp:${phone}`;
  const attemptsKey = `otp_attempts:${phone}`;
  
  const [stored, attempts] = await Promise.all([
    redis.get(key),
    redis.get(attemptsKey)
  ]);

  if (!stored) return false;

  // Check if attempts exceeded
  if (attempts && parseInt(attempts, 10) >= MAX_OTP_ATTEMPTS) {
    await deleteOTP(phone);
    return false;
  }

  if (stored === otp) {
    return true;
  }

  // Increment attempts on failure
  await redis.incr(attemptsKey);
  
  // If this was the last allowed attempt, delete the OTP immediately
  const newAttempts = (parseInt(attempts, 10) || 0) + 1;
  if (newAttempts >= MAX_OTP_ATTEMPTS) {
    await deleteOTP(phone);
  }

  return false;
}

/**
 * Delete the OTP and attempt counter for a given phone number from Redis.
 * @param {string} phone - Phone number whose OTP should be deleted
 * @returns {Promise<void>}
 */
async function deleteOTP(phone) {
  await redis.del(`otp:${phone}`, `otp_attempts:${phone}`);
}

module.exports = { generateAndStoreOTP, verifyOTP, deleteOTP };

