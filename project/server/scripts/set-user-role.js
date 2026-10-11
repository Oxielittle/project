const mongoose = require('mongoose');
const User = require('../models/authModel');

const username = process.argv[2];
const role = process.argv[3] || 'admin';

if (!username || !['admin', 'manager', 'member'].includes(role)) {
  console.error('Usage: node scripts/set-user-role.js <username> <admin|manager|member>');
  process.exit(1);
}

mongoose
  .connect(process.env.LOCAL_MONGO_URI || 'mongodb://127.0.0.1:27017/project')
  .then(async () => {
    const user = await User.findOneAndUpdate(
      { username },
      { $set: { role } },
      { new: true },
    );
    if (!user) throw new Error(`User "${username}" was not found.`);
    console.log(`${user.username} is now ${user.role}`);
  })
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => mongoose.disconnect());
