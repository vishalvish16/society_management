const bcrypt = require('bcrypt');
const { SALT_ROUNDS } = require('../../config/constants');

exports.hashPassword = async (password) => {
  return await bcrypt.hash(password, SALT_ROUNDS);
};

exports.comparePasswords = async (candidatePassword, hashedPassword) => {
  if (candidatePassword == null || typeof hashedPassword !== 'string' || !hashedPassword) {
    return false;
  }
  try {
    return await bcrypt.compare(String(candidatePassword), hashedPassword);
  } catch {
    return false;
  }
};
