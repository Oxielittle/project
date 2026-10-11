const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth', required: true },
  title: { type: String, required: true },
  message: { type: String, required: true },
  type: { type: String, default: 'system' },
  entityType: String,
  entityId: mongoose.Schema.Types.ObjectId,
  isRead: { type: Boolean, default: false },
}, { timestamps: true });
module.exports = mongoose.model('Notification', schema);
