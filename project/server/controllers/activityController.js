const fs = require('fs');
const path = require('path');
const Task = require('../models/taskModel');
const Project = require('../models/projectModel');
const Assignment = require('../models/activityAssignmentModel');
const { notify } = require('../services/notifications');
const { logActivity } = require('../services/activity');
const { emitAll } = require('../services/events');
const mongoose = require('mongoose');
const { submissionError, isLateSubmission, canReviewByRole, recipientScope } = require('../services/activityRules');

const id = (value) => String(value?._id || value);
const canReview = async (user, activity) => {
  const managesProject = user.role === 'manager' && Boolean(await Project.exists({ _id: activity.project, manager: user._id }));
  return canReviewByRole({ role: user.role, userId: id(user), reporterId: id(activity.reporter), managesProject });
};

exports.create = async (req, res, next) => {
  let activity, assignments = [];
  try {
    const recipients = [...new Set((req.body.recipients || []).map(String))];
    if (!req.body.title?.trim() || !req.body.project) return res.status(400).json({ message: 'Title and project are required.' });
    if (!recipients.length) return res.status(400).json({ message: 'Select at least one recipient.' });
    const projectQuery = req.user.role === 'admin' ? { _id: req.body.project } : { _id: req.body.project, manager: req.user._id };
    const project = await Project.findOne(projectQuery);
    if (!project) return res.status(403).json({ message: 'You cannot create an activity for this project.' });
    const allowed = new Set(project.members.map(String));
    const invalid = recipients.filter((recipient) => !allowed.has(recipient));
    if (invalid.length) return res.status(400).json({ message: 'Every recipient must be a member of the selected project.' });
    const settings = req.body.activitySettings || {};
    if (!settings.allowTextResponse && !settings.requireAttachment) return res.status(400).json({ message: 'Enable a text response or require an attachment.' });
    const activityData = {
      type: 'individual-activity', title: req.body.title.trim(), description: req.body.description || '', project: project._id,
      reporter: req.user._id, priority: req.body.priority || 'medium', startDate: req.body.startDate, deadline: req.body.deadline,
      activitySettings: settings,
    };
    if (activityData.startDate && activityData.deadline && new Date(activityData.deadline) < new Date(activityData.startDate)) return res.status(400).json({ message: 'Deadline must be after the start date.' });
    const supportsTransactions = ['ReplicaSetWithPrimary', 'Sharded'].includes(mongoose.connection.client?.topology?.description?.type);
    if (supportsTransactions) {
      const session = await mongoose.startSession();
      try {
        await session.withTransaction(async () => {
          [activity] = await Task.create([activityData], { session });
          assignments = await Assignment.insertMany(recipients.map((recipient) => ({ activity: activity._id, recipient, maximumScore: settings.maximumScore || 100 })), { ordered: true, session });
        });
      } finally { await session.endSession(); }
    } else {
      activity = await Task.create(activityData);
      assignments = await Assignment.insertMany(recipients.map((recipient) => ({ activity: activity._id, recipient, maximumScore: settings.maximumScore || 100 })), { ordered: true });
    }
    await Promise.all(recipients.map((recipient) => notify(recipient, 'New individual activity', activity.title, 'assignment', 'Task', activity._id)));
    await logActivity(req.user._id, 'CREATE_INDIVIDUAL_ACTIVITY', 'Task', activity._id, { recipients: recipients.length });
    emitAll('task:changed', activity);
    res.status(201).json({ item: await activity.populate('project reporter'), assignmentCount: assignments.length });
  } catch (error) {
    if (activity?._id) { await Assignment.deleteMany({ activity: activity._id }).catch(() => {}); await Task.deleteOne({ _id: activity._id }).catch(() => {}); }
    next(error);
  }
};

exports.myAssignment = async (req, res, next) => { try {
  const item = await Assignment.findOne(recipientScope(req.user._id, { activity: req.params.id })).populate('activity recipient reviewer');
  if (!item) return res.status(404).json({ message: 'Assignment not found.' });
  res.json({ item });
} catch (error) { next(error); } };

exports.listAssignments = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  const query = { activity: activity._id };
  if (req.query.status) query.status = req.query.status;
  const [items, allStatuses] = await Promise.all([
    Assignment.find(query).populate('recipient reviewer').sort(req.query.sort || 'recipient'),
    Assignment.find({ activity: activity._id }).select('status'),
  ]);
  const counts = allStatuses.reduce((result, item) => { result[item.status] = (result[item.status] || 0) + 1; return result; }, {});
  res.json({ items, total: items.length, counts });
} catch (error) { next(error); } };

exports.start = async (req, res, next) => { try {
  const item = await Assignment.findOneAndUpdate(recipientScope(req.user._id, { _id: req.params.id, status: 'assigned' }), { status: 'in-progress' }, { new: true });
  if (!item) return res.status(404).json({ message: 'Assignment cannot be started.' });
  emitAll('activity-assignment:changed', item); res.json({ item });
} catch (error) { next(error); } };

exports.addAttachment = async (req, res, next) => { try {
  if (!req.file) return res.status(400).json({ message: 'Choose a file.' });
  const item = await Assignment.findOne(recipientScope(req.user._id, { _id: req.params.id })).populate('activity');
  if (!item) { fs.unlink(req.file.path, () => {}); return res.status(404).json({ message: 'Assignment not found.' }); }
  const settings = item.activity.activitySettings;
  if (req.file.size > (settings.maxFileSizeMB || 10) * 1024 * 1024) { fs.unlink(req.file.path, () => {}); return res.status(400).json({ message: 'File exceeds the activity size limit.' }); }
  const extensions = (settings.allowedFileTypes || []).map((value) => String(value).replace(/^\./, '').toLowerCase());
  const extension = path.extname(req.file.originalname).slice(1).toLowerCase();
  if (extensions.length && !extensions.includes(extension)) { fs.unlink(req.file.path, () => {}); return res.status(400).json({ message: 'This file type is not allowed.' }); }
  item.attachments.push({ name: req.file.originalname, url: `/uploads/${req.file.filename}`, mimeType: req.file.mimetype, size: req.file.size });
  await item.save(); res.status(201).json({ item: item.attachments.at(-1) });
} catch (error) { next(error); } };

exports.deleteAttachment = async (req, res, next) => { try {
  const item = await Assignment.findOne(recipientScope(req.user._id, { _id: req.params.id }));
  if (!item) return res.status(404).json({ message: 'Assignment not found.' });
  const attachment = item.attachments.id(req.params.attachmentId);
  if (!attachment) return res.status(404).json({ message: 'Attachment not found.' });
  const filename = path.basename(attachment.url); attachment.deleteOne(); await item.save();
  fs.unlink(path.join(__dirname, '..', 'uploads', filename), () => {}); res.json({ message: 'Attachment removed.' });
} catch (error) { next(error); } };

exports.submit = async (req, res, next) => { try {
  const item = await Assignment.findOne(recipientScope(req.user._id, { _id: req.params.id })).populate('activity');
  if (!item) return res.status(404).json({ message: 'Assignment not found.' });
  const activity = item.activity, settings = activity.activitySettings;
  if (activity.startDate && new Date(activity.startDate) > new Date()) return res.status(400).json({ message: 'This activity has not started.' });
  const error = submissionError({ activity, assignment: item, textResponse: req.body.textResponse });
  if (error) return res.status(400).json({ message: error });
  const now = new Date(), late = isLateSubmission(activity.deadline, now);
  item.textResponse = String(req.body.textResponse || ''); item.submissionCount += 1; item.firstSubmittedAt ||= now; item.latestSubmittedAt = now; item.isLate = Boolean(late);
  item.status = late ? 'late' : item.submissionCount > 1 ? 'resubmitted' : 'submitted';
  item.submissionHistory.push({ number: item.submissionCount, textResponse: item.textResponse, attachments: item.attachments.map((a) => a.toObject()), submittedAt: now, isLate: Boolean(late) });
  await item.save();
  await notify(activity.reporter, 'Activity submission received', `${req.user.firstName} submitted ${activity.title}`, 'submission', 'Task', activity._id);
  await logActivity(req.user._id, item.submissionCount > 1 ? 'RESUBMIT_ACTIVITY' : 'SUBMIT_ACTIVITY', 'Task', activity._id);
  emitAll('activity-assignment:changed', item); res.json({ item });
} catch (error) { next(error); } };

exports.review = async (req, res, next) => { try {
  const item = await Assignment.findById(req.params.id).populate('activity');
  if (!item) return res.status(404).json({ message: 'Assignment not found.' });
  if (!await canReview(req.user, item.activity)) return res.status(403).json({ message: 'Permission denied.' });
  if (!['accepted', 'returned'].includes(req.body.status)) return res.status(400).json({ message: 'Review status must be accepted or returned.' });
  if (!['submitted', 'late', 'resubmitted'].includes(item.status)) return res.status(400).json({ message: 'Only a submitted assignment can be reviewed.' });
  if (req.body.score != null && (Number(req.body.score) < 0 || Number(req.body.score) > item.maximumScore)) return res.status(400).json({ message: `Score must be between 0 and ${item.maximumScore}.` });
  item.status = req.body.status; item.feedback = String(req.body.feedback || ''); item.score = req.body.score; item.reviewer = req.user._id; item.reviewedAt = new Date(); await item.save();
  await notify(item.recipient, req.body.status === 'accepted' ? 'Submission accepted' : 'Submission returned', item.feedback || item.activity.title, 'review', 'Task', item.activity._id);
  await logActivity(req.user._id, req.body.status === 'accepted' ? 'ACCEPT_SUBMISSION' : 'RETURN_SUBMISSION', 'Task', item.activity._id, { recipient: item.recipient });
  emitAll('activity-assignment:changed', item); res.json({ item });
} catch (error) { next(error); } };

exports.remind = async (req, res, next) => { try {
  const activity = await Task.findById(req.params.id);
  if (!activity || !await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  const items = await Assignment.find({ activity: activity._id, status: { $in: ['assigned', 'in-progress', 'returned'] } });
  await Promise.all(items.map((item) => notify(item.recipient, 'Activity reminder', activity.title, 'reminder', 'Task', activity._id)));
  res.json({ message: `Reminder sent to ${items.length} recipient(s).`, count: items.length });
} catch (error) { next(error); } };

exports.update = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  const allowed = ['title', 'description', 'priority', 'startDate', 'deadline', 'activitySettings'];
  const changes = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));
  const start = changes.startDate ?? activity.startDate, deadline = changes.deadline ?? activity.deadline;
  if (start && deadline && new Date(deadline) < new Date(start)) return res.status(400).json({ message: 'Deadline must be after the start date.' });
  const settings = changes.activitySettings ?? activity.activitySettings;
  if (!settings.allowTextResponse && !settings.requireAttachment) return res.status(400).json({ message: 'Enable a text response or require an attachment.' });
  Object.assign(activity, changes); await activity.save();
  if (changes.activitySettings?.maximumScore != null) await Assignment.updateMany({ activity: activity._id }, { maximumScore: changes.activitySettings.maximumScore });
  const recipients = await Assignment.find({ activity: activity._id, status: { $ne: 'cancelled' } }).distinct('recipient');
  await Promise.all(recipients.map((recipient) => notify(recipient, 'Activity updated', activity.title, 'status', 'Task', activity._id)));
  await logActivity(req.user._id, 'UPDATE_INDIVIDUAL_ACTIVITY', 'Task', activity._id, Object.keys(changes));
  emitAll('task:changed', activity); res.json({ item: await activity.populate('project reporter') });
} catch (error) { next(error); } };

exports.addRecipients = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  const requested = [...new Set((req.body.recipients || []).map(String))];
  const project = await Project.findById(activity.project);
  const members = new Set((project?.members || []).map(String));
  if (requested.some((recipient) => !members.has(recipient))) return res.status(400).json({ message: 'Every recipient must be a project member.' });
  const existingItems = await Assignment.find({ activity: activity._id, recipient: { $in: requested } });
  const existing = new Map(existingItems.map((item) => [String(item.recipient), item]));
  const recipients = requested.filter((recipient) => !existing.has(recipient));
  const reactivated = existingItems.filter((item) => item.status === 'cancelled');
  for (const item of reactivated) { item.status = item.submissionCount ? 'reopened' : 'assigned'; item.removedAt = undefined; await item.save(); }
  if (!recipients.length && !reactivated.length) return res.status(409).json({ message: 'All selected recipients already have active assignments.' });
  const items = recipients.length ? await Assignment.insertMany(recipients.map((recipient) => ({ activity: activity._id, recipient, maximumScore: activity.activitySettings.maximumScore || 100 }))) : [];
  const affected = [...recipients, ...reactivated.map((item) => String(item.recipient))];
  await Promise.all(affected.map((recipient) => notify(recipient, 'Added to individual activity', activity.title, 'assignment', 'Task', activity._id)));
  await logActivity(req.user._id, 'ADD_ACTIVITY_RECIPIENTS', 'Task', activity._id, { count: affected.length });
  emitAll('activity-assignment:changed', { activity: activity._id }); res.status(201).json({ items: [...items, ...reactivated], added: affected.length });
} catch (error) { next(error); } };

exports.removeRecipient = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  const item = await Assignment.findOne({ activity: activity._id, recipient: req.params.userId });
  if (!item) return res.status(404).json({ message: 'Recipient assignment not found.' });
  if (item.submissionCount > 0) { item.status = 'cancelled'; item.removedAt = new Date(); await item.save(); }
  else await item.deleteOne();
  await notify(item.recipient, 'Removed from activity', activity.title, 'status', 'Task', activity._id);
  await logActivity(req.user._id, 'REMOVE_ACTIVITY_RECIPIENT', 'Task', activity._id, { recipient: item.recipient, preservedHistory: item.submissionCount > 0 });
  emitAll('activity-assignment:changed', item); res.json({ message: item.submissionCount > 0 ? 'Recipient removed; submission history was preserved.' : 'Recipient removed.' });
} catch (error) { next(error); } };

exports.archive = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  activity.isArchived = req.body.archived !== false; await activity.save();
  await logActivity(req.user._id, activity.isArchived ? 'ARCHIVE_ACTIVITY' : 'RESTORE_ACTIVITY', 'Task', activity._id);
  emitAll('task:changed', activity); res.json({ item: activity });
} catch (error) { next(error); } };

exports.cancel = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  activity.isCancelled = true; activity.isArchived = true; await activity.save();
  const assignments = await Assignment.find({ activity: activity._id });
  const cancellable = assignments.filter((item) => !['accepted', 'cancelled'].includes(item.status));
  await Assignment.updateMany({ _id: { $in: cancellable.map((item) => item._id) } }, { status: 'cancelled' });
  await Promise.all(assignments.map((item) => notify(item.recipient, 'Activity cancelled', activity.title, 'status', 'Task', activity._id)));
  await logActivity(req.user._id, 'CANCEL_ACTIVITY', 'Task', activity._id, { reason: req.body.reason || '' });
  emitAll('task:changed', activity); res.json({ item: activity });
} catch (error) { next(error); } };

exports.reopen = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  if (req.body.deadline) activity.deadline = req.body.deadline;
  activity.isCancelled = false; activity.isArchived = false; await activity.save();
  const query = { activity: activity._id, status: { $in: ['accepted', 'cancelled'] } };
  if (Array.isArray(req.body.assignmentIds) && req.body.assignmentIds.length) query._id = { $in: req.body.assignmentIds };
  const items = await Assignment.find(query);
  for (const item of items) {
    item.status = 'reopened'; item.reopenedAt = new Date(); item.reopenedBy = req.user._id; item.reopenReason = String(req.body.reason || '');
    if (item.submissionCount >= (activity.activitySettings.maxSubmissions || 1)) activity.activitySettings.maxSubmissions = item.submissionCount + 1;
    await item.save();
    await notify(item.recipient, 'Activity reopened', `${activity.title}${req.body.reason ? `: ${req.body.reason}` : ''}`, 'status', 'Task', activity._id);
  }
  await activity.save(); await logActivity(req.user._id, 'REOPEN_ACTIVITY', 'Task', activity._id, { assignments: items.length, reason: req.body.reason || '' });
  emitAll('activity-assignment:changed', { activity: activity._id }); res.json({ item: activity, reopened: items.length });
} catch (error) { next(error); } };

const csv = (value) => `"${String(value ?? '').replace(/"/g, '""')}"`;
exports.exportCsv = async (req, res, next) => { try {
  const activity = await Task.findOne({ _id: req.params.id, type: 'individual-activity' });
  if (!activity) return res.status(404).json({ message: 'Activity not found.' });
  if (!await canReview(req.user, activity)) return res.status(403).json({ message: 'Permission denied.' });
  const items = await Assignment.find({ activity: activity._id }).populate('recipient reviewer').sort('recipient');
  const rows = [['Recipient', 'Email', 'Status', 'Submissions', 'First submitted', 'Latest submitted', 'Late', 'Score', 'Maximum score', 'Feedback']];
  for (const item of items) rows.push([`${item.recipient?.firstName || ''} ${item.recipient?.lastName || ''}`.trim(), item.recipient?.email || '', item.status, item.submissionCount, item.firstSubmittedAt?.toISOString() || '', item.latestSubmittedAt?.toISOString() || '', item.isLate ? 'Yes' : 'No', item.score ?? '', item.maximumScore, item.feedback]);
  res.setHeader('Content-Type', 'text/csv; charset=utf-8'); res.setHeader('Content-Disposition', `attachment; filename="${activity.title.replace(/[^a-z0-9]+/gi, '-')}-results.csv"`);
  res.send(rows.map((row) => row.map(csv).join(',')).join('\n'));
} catch (error) { next(error); } };
