const mongoose = require('mongoose');
const teamSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  description: { type: String, default: '' },
  manager: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth', required: true },
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Auth' }],
  isArchived: { type: Boolean, default: false },
}, { timestamps: true });
module.exports = mongoose.model('Team', teamSchema);
