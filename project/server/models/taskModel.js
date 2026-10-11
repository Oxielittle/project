const mongoose = require('mongoose');
const taskSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true },
  description: { type: String, default: '' },
  project: { type: mongoose.Schema.Types.ObjectId, ref: 'Project', required: true },
  assignee: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth' },
  reporter: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth', required: true },
  status: { type: String, enum: ['todo', 'in-progress', 'for-review', 'completed', 'returned'], default: 'todo' },
  priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium' },
  startDate: Date,
  deadline: Date,
  tags: [String],
  subtasks: [{ title: { type: String, required: true }, completed: { type: Boolean, default: false } }],
  attachments: [{ name: String, url: String, mimeType: String, size: Number }],
  progress: { type: Number, min: 0, max: 100, default: 0 },
  isArchived: { type: Boolean, default: false },
}, { timestamps: true });
module.exports = mongoose.model('Task', taskSchema);
