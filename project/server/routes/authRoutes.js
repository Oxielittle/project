const express = require('express');

const {
    registerUser,
    loginUser, getMe, updateMe, uploadAvatar, removeAvatar, changePassword, forgotPassword, resetPassword
} = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

router.post('/register', registerUser);
router.post('/login', loginUser);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.get('/me', protect, getMe);
router.patch('/me', protect, updateMe);
router.post('/me/avatar', protect, upload.single('file'), uploadAvatar);
router.delete('/me/avatar', protect, removeAvatar);
router.patch('/change-password', protect, changePassword);

module.exports = router;
