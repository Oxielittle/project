const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const User = require('../models/authModel');

const [username, password] = process.argv.slice(2);

if (!username || !password) {
  console.error('Usage: node scripts/upsertAdmin.js <username> <password>');
  process.exit(1);
}

const run = async () => {
  await mongoose.connect(process.env.LOCAL_MONGO_URI || 'mongodb://127.0.0.1:27017/project');
  const hashedPassword = await bcrypt.hash(password, 10);
  const existing = await User.findOne({ username });
  const user = existing
    ? await User.findByIdAndUpdate(
        existing._id,
        { $set: { password: hashedPassword, role: 'admin', isArchived: false } },
        { new: true },
      )
    : await User.create({
        firstName: username,
        lastName: 'Administrator',
        birthday: new Date('2000-01-01'),
        username,
        email: `${username.toLowerCase()}.admin@taskmanager.local`,
        phone: `admin-${Date.now()}`,
        password: hashedPassword,
        role: 'admin',
      });
  console.log(`Admin ready: ${user.username} (${user.role})`);
  await mongoose.disconnect();
};

run().catch(async (error) => {
  console.error(error.message);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});
