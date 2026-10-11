const mongoose = require('mongoose');
const taskSchema = new mongoose.Schema({
  type: { type: String, enum: ['standard', 'individual-activity'], default: 'standard', index: true },
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
  activitySettings: {
    allowTextResponse: { type: Boolean, default: true },
    requireAttachment: { type: Boolean, default: false },
    allowResubmission: { type: Boolean, default: true },
    maxSubmissions: { type: Number, min: 1, default: 3 },
    maxFileSizeMB: { type: Number, min: 1, max: 25, default: 10 },
    allowedFileTypes: [{ type: String, trim: true }],
    maximumScore: { type: Number, min: 0, default: 100 },
  },
}, { timestamps: true });
module.exports = mongoose.model('Task', taskSchema);
