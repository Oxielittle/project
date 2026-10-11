const jwt = require('jsonwebtoken');
const User = require('../models/authModel');

const protect = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.startsWith('Bearer ')
      ? req.headers.authorization.slice(7)
      : null;
    if (!token) return res.status(401).json({ message: 'Authentication required.' });
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'development-secret');
    const user = await User.findById(payload.id).select('-password');
    if (!user || user.isArchived) return res.status(401).json({ message: 'Account unavailable.' });
    req.user = user;
    next();
  } catch (_) {
    return res.status(401).json({ message: 'Invalid or expired token.' });
  }
};

const allow = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role)) return res.status(403).json({ message: 'Permission denied.' });
  next();
};

module.exports = { protect, allow };
