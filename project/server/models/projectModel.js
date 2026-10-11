const mongoose = require('mongoose');
const projectSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  description: { type: String, default: '' },
  startDate: Date,
  deadline: Date,
  status: { type: String, enum: ['planning', 'active', 'on-hold', 'completed'], default: 'planning' },
  priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium' },
  team: { type: mongoose.Schema.Types.ObjectId, ref: 'Team' },
  manager: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth', required: true },
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Auth' }],
  isArchived: { type: Boolean, default: false },
}, { timestamps: true });
module.exports = mongoose.model('Project', projectSchema);
