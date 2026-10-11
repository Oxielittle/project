const nodemailer = require('nodemailer');

exports.sendResetEmail = async (email, token) => {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    if (process.env.NODE_ENV === 'production') throw new Error('Password email service is not configured.');
    console.log(`Development password reset token for ${email}: ${token}`);
    return;
  }
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: email,
    subject: 'Task Management password reset',
    text: `Your password reset code is: ${token}\nThis code expires in 30 minutes.`,
  });
};
