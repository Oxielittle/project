const mongoose = require('mongoose');

const attachmentSchema = new mongoose.Schema({
  name: String,
  url: String,
  mimeType: String,
  size: Number,
}, { timestamps: true });

const attemptSchema = new mongoose.Schema({
  number: Number,
  textResponse: String,
  attachments: [attachmentSchema],
  submittedAt: Date,
  isLate: Boolean,
}, { _id: true });

const schema = new mongoose.Schema({
  activity: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', required: true, index: true },
  recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth', required: true, index: true },
  status: { type: String, enum: ['assigned', 'in-progress', 'submitted', 'late', 'returned', 'resubmitted', 'accepted'], default: 'assigned', index: true },
  textResponse: { type: String, default: '' },
  attachments: [attachmentSchema],
  submissionHistory: [attemptSchema],
  submissionCount: { type: Number, default: 0 },
  firstSubmittedAt: Date,
  latestSubmittedAt: Date,
  reviewedAt: Date,
  reviewer: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth' },
  feedback: { type: String, default: '' },
  score: { type: Number, min: 0 },
  maximumScore: { type: Number, min: 0, default: 100 },
  isLate: { type: Boolean, default: false },
}, { timestamps: true });

schema.index({ activity: 1, recipient: 1 }, { unique: true });
module.exports = mongoose.model('ActivityAssignment', schema);
