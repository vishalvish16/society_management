const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

exports.hashPassword = async (password) => {
  const saltRounds = 10;
  return await bcrypt.hash(password, saltRounds);
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

exports.generateToken = (user) => {
  const secretKey = process.env.JWT_SECRET_KEY;
  const payload = { id: user.id, societyId: user.societyId };
  return jwt.sign(payload, secretKey, { expiresIn: '1h' });
};
