const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const auth = require('../middleware/auth');
exports.authenticateToken       = auth.authenticateToken;
exports.validateAndSanitizeQuery = auth.validateAndSanitizeQuery;
exports.requireRole             = auth.requireRole;

exports.authenticateUser = (req, res, next) => {
  const token = req.header('Authorization');

  if (!token) return res.status(401).json({ error: 'No token provided' });

  jwt.verify(token, process.env.JWT_SECRET_KEY, async (err, decoded) => {
    if (err) return res.status(401).json({ error: 'Failed to authenticate token' });

    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
    });

    if (!user) return res.status(404).json({ error: 'User not found' });

    req.user = user;
    next();
  });
};
