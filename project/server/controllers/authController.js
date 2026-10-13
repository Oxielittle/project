const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Auth = require('../models/authModel');
const { logActivity } = require('../services/activity');
const crypto = require('crypto');
const { sendResetEmail } = require('../services/mail');

const safeUser = (user) => ({ id: user._id, firstName: user.firstName, lastName: user.lastName, birthday: user.birthday, username: user.username, email: user.email, phone: user.phone, role: user.role, avatarUrl: user.avatarUrl });
const fs = require('fs');
const path = require('path');

const removeLocalAvatar = (avatarUrl) => {
  if (!avatarUrl || !avatarUrl.startsWith('/uploads/')) return;
  const filename = path.basename(avatarUrl);
  fs.unlink(path.join(__dirname, '..', 'uploads', filename), () => {});
};
const tokenFor = (user) => jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET || 'development-secret', { expiresIn: '7d' });

const registerUser = async (req, res) => {
try {
const {
firstName,
lastName,
birthday,
username,
email,
phone,
password
} = req.body;


    // Check required fields
    if (
        !firstName ||
        !lastName ||
        !birthday ||
        !username ||
        !email ||
        !phone ||
        !password
    ) {
        return res.status(400).json({
            message: 'All fields are required.'
        });
    }

    // Check if username already exists
    const existingUsername = await Auth.findOne({ username });

    if (existingUsername) {
        return res.status(409).json({
            message: 'Username is already taken.'
        });
    }

    // Check if email already exists
    const existingEmail = await Auth.findOne({
        email: email.toLowerCase()
    });

    if (existingEmail) {
        return res.status(409).json({
            message: 'Email is already registered.'
        });
    }

    // Check if phone already exists
    const existingPhone = await Auth.findOne({ phone });

    if (existingPhone) {
        return res.status(409).json({
            message: 'Phone number is already registered.'
        });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const newUser = new Auth({
        firstName,
        lastName,
        birthday,
        username,
        email: email.toLowerCase(),
        phone,
        password: hashedPassword
    });

    // Save user to MongoDB
    await newUser.save();

    return res.status(201).json({
        message: 'Registration successful.',
        token: tokenFor(newUser),
        user: safeUser(newUser)
    });

} catch (error) {
    console.error('Registration error:', error);

    return res.status(500).json({
        message: 'Server error during registration.'
    });
}


};

const loginUser = async (req, res) => {
try {
const { usernameOrEmail, password } = req.body;


    // Check required fields
    if (!usernameOrEmail || !password) {
        return res.status(400).json({
            message: 'Username/email and password are required.'
        });
    }

    // Find user by username OR email
    const user = await Auth.findOne({
        $or: [
            { username: usernameOrEmail },
            { email: usernameOrEmail.toLowerCase() }
        ]
    });

    // User doesn't exist
    if (!user) {
        return res.status(401).json({
            message: 'Invalid username/email or password.'
        });
    }

    // Compare password
    const passwordMatch = await bcrypt.compare(
        password,
        user.password
    );

    if (!passwordMatch) {
        return res.status(401).json({
            message: 'Invalid username/email or password.'
        });
    }

    if (user.isArchived) return res.status(403).json({ message: 'This account has been archived.' });

    await logActivity(user._id, 'LOGIN', 'User', user._id);

    // Successful login
    return res.status(200).json({
        message: 'Login successful.',
        token: tokenFor(user),
        user: safeUser(user)
    });

} catch (error) {
    console.error('Login error:', error);

    return res.status(500).json({
        message: 'Server error during login.'
    });
}


};

module.exports = {
registerUser,
loginUser,
getMe: (req, res) => res.json({ user: req.user }),
updateMe: async (req, res, next) => {
  try {
    const allowed = ['firstName', 'lastName', 'phone'];
    allowed.forEach((key) => { if (req.body[key] !== undefined) req.user[key] = req.body[key]; });
    await req.user.save();
    res.json({ message: 'Profile updated.', user: safeUser(req.user) });
  } catch (error) { next(error); }
},
uploadAvatar: async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'Please select an image.' });
    const extension = path.extname(req.file.originalname).toLowerCase();
    const allowedExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);
    if (!req.file.mimetype.startsWith('image/') && !allowedExtensions.has(extension)) {
      fs.unlink(req.file.path, () => {});
      return res.status(400).json({ message: 'Profile picture must be an image.' });
    }
    if (req.file.size > 5 * 1024 * 1024) {
      fs.unlink(req.file.path, () => {});
      return res.status(400).json({ message: 'Profile picture must be smaller than 5 MB.' });
    }
    const previous = req.user.avatarUrl;
    req.user.avatarUrl = `/uploads/${req.file.filename}`;
    await req.user.save();
    removeLocalAvatar(previous);
    res.json({ message: 'Profile picture updated.', user: safeUser(req.user) });
  } catch (error) { next(error); }
},
removeAvatar: async (req, res, next) => {
  try {
    const previous = req.user.avatarUrl;
    req.user.avatarUrl = '';
    await req.user.save();
    removeLocalAvatar(previous);
    res.json({ message: 'Profile picture removed.', user: safeUser(req.user) });
  } catch (error) { next(error); }
},
changePassword: async (req, res, next) => {
  try {
    const user = await Auth.findById(req.user._id);
    if (!await bcrypt.compare(req.body.currentPassword || '', user.password)) return res.status(400).json({ message: 'Current password is incorrect.' });
    if (!req.body.newPassword || req.body.newPassword.length < 8) return res.status(400).json({ message: 'New password must contain at least 8 characters.' });
    user.password = await bcrypt.hash(req.body.newPassword, 10);
    await user.save();
    res.json({ message: 'Password changed.' });
  } catch (error) { next(error); }
},
forgotPassword: async (req, res, next) => {
  try {
    const user = await Auth.findOne({ email: String(req.body.email || '').toLowerCase() });
    let resetToken;
    if (user) {
      resetToken = crypto.randomBytes(24).toString('hex');
      user.resetPasswordToken = crypto.createHash('sha256').update(resetToken).digest('hex');
      user.resetPasswordExpires = Date.now() + 30 * 60 * 1000;
      await user.save();
      await sendResetEmail(user.email, resetToken);
    }
    res.json({ message: 'If the account exists, a reset code has been created.', ...(process.env.NODE_ENV !== 'production' && resetToken ? { resetToken } : {}) });
  } catch (error) { next(error); }
},
resetPassword: async (req, res, next) => {
  try {
    const hashed = crypto.createHash('sha256').update(String(req.body.token || '')).digest('hex');
    const user = await Auth.findOne({ resetPasswordToken: hashed, resetPasswordExpires: { $gt: Date.now() } });
    if (!user) return res.status(400).json({ message: 'Reset code is invalid or expired.' });
    if (!req.body.password || req.body.password.length < 8) return res.status(400).json({ message: 'Password must contain at least 8 characters.' });
    user.password = await bcrypt.hash(req.body.password, 10);
    user.resetPasswordToken = undefined; user.resetPasswordExpires = undefined;
    await user.save();
    res.json({ message: 'Password reset successfully.' });
  } catch (error) { next(error); }
}
};
