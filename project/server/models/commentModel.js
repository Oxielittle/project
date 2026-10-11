const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  task: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', required: true },
  author: { type: mongoose.Schema.Types.ObjectId, ref: 'Auth', required: true },
  body: { type: String, required: true, trim: true },
}, { timestamps: true });
module.exports = mongoose.model('Comment', schema);
