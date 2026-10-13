const User = require('../models/authModel');
const Team = require('../models/teamModel');
const Project = require('../models/projectModel');
const Task = require('../models/taskModel');
const ActivityAssignment = require('../models/activityAssignmentModel');
const Comment = require('../models/commentModel');
const Notification = require('../models/notificationModel');
const Activity = require('../models/activityLogModel');
const { logActivity } = require('../services/activity');
const { notify } = require('../services/notifications');
const { emitAll, emitToUser } = require('../services/events');
const fs = require('fs');
const path = require('path');
const { shiftDate, dependencyBlockMessage, personalTaskDateError } = require('../services/taskRules');

const visibleTaskQuery = async (user) => {
  const ownPersonal = { scope: 'personal', owner: user._id };
  if (user.role === 'admin') return { $or: [{ scope: { $ne: 'personal' } }, ownPersonal] };
  const activityIds = await ActivityAssignment.find({ recipient: user._id }).distinct('activity');
  if (user.role === 'manager') {
    const managedProjects = await Project.find({ manager: user._id }).distinct('_id');
    return { $or: [ownPersonal, { scope: { $ne: 'personal' }, reporter: user._id }, { scope: { $ne: 'personal' }, assignee: user._id }, { scope: { $ne: 'personal' }, collaborators: user._id }, { scope: { $ne: 'personal' }, watchers: user._id }, { _id: { $in: activityIds } }, { scope: { $ne: 'personal' }, project: { $in: managedProjects } }] };
  }
  return { $or: [ownPersonal, { scope: { $ne: 'personal' }, assignee: user._id }, { scope: { $ne: 'personal' }, collaborators: user._id }, { scope: { $ne: 'personal' }, watchers: user._id }, { _id: { $in: activityIds } }] };
};

const sendPersonalReminders = async (userId) => {
  const now = new Date();
  const reminderItems = await Task.find({ scope: 'personal', owner: userId, isArchived: false, isCancelled: false, status: { $ne: 'completed' }, reminderAt: { $lte: now }, reminderNotifiedAt: null });
  for (const item of reminderItems) {
    await notify(userId, 'Personal task reminder', item.title, 'reminder', 'Task', item._id);
    item.reminderNotifiedAt = now; await item.save();
  }
  const overdueItems = await Task.find({ scope: 'personal', owner: userId, isArchived: false, isCancelled: false, status: { $ne: 'completed' }, deadline: { $lt: now }, overdueNotifiedAt: null });
  for (const item of overdueItems) {
    await notify(userId, 'Personal task overdue', item.title, 'overdue', 'Task', item._id);
    item.overdueNotifiedAt = now; await item.save();
  }
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const dueSoonItems = await Task.find({ scope: 'personal', owner: userId, isArchived: false, isCancelled: false, status: { $ne: 'completed' }, deadline: { $gte: now, $lte: tomorrow }, dueSoonNotifiedAt: null });
  for (const item of dueSoonItems) {
    await notify(userId, 'Personal task due soon', item.title, 'deadline', 'Task', item._id);
    item.dueSoonNotifiedAt = now; await item.save();
  }
};
const list = (Model, populate = '') => async (req, res, next) => { try {
  const page = Math.max(Number(req.query.page) || 1, 1); const limit = Math.min(Number(req.query.limit) || 50, 100);
  const query = { isArchived: req.query.archived === 'true' };
  if (req.query.search) query.$or = ['name', 'title'].map((key) => ({ [key]: new RegExp(req.query.search, 'i') }));
  const [items, total] = await Promise.all([Model.find(query).populate(populate).sort('-createdAt').skip((page - 1) * limit).limit(limit), Model.countDocuments(query)]);
  res.json({ items, page, pages: Math.ceil(total / limit), total });
} catch (e) { next(e); } };

exports.users = async (req, res, next) => { try { res.json({ items: await User.find({}).select('-password').sort('firstName') }); } catch (e) { next(e); } };
exports.updateUser = async (req, res, next) => { try {
  const allowed = ['role', 'isArchived'];
  const changes = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));
  if (String(req.user._id) === req.params.id && changes.isArchived === true) return res.status(400).json({ message: 'You cannot archive your own account.' });
  const user = await User.findByIdAndUpdate(req.params.id, { $set: changes }, { new: true, runValidators: true }).select('-password');
  if (!user) return res.status(404).json({ message: 'User not found.' });
  await logActivity(req.user._id, 'UPDATE_USER', 'User', user._id, changes);
  res.json({ user });
} catch (e) { next(e); } };
exports.listTeams = list(Team, 'manager members');
exports.createTeam = async (req, res, next) => { try { const item = await Team.create({ ...req.body, manager: req.body.manager || req.user._id }); await logActivity(req.user._id, 'CREATE_TEAM', 'Team', item._id); emitAll('team:changed', item); res.status(201).json({ item }); } catch (e) { next(e); } };
exports.updateTeam = async (req, res, next) => { try { const query = req.user.role === 'admin' ? { _id: req.params.id } : { _id: req.params.id, manager: req.user._id }; const item = await Team.findOneAndUpdate(query, req.body, { new: true, runValidators: true }); if (!item) return res.status(403).json({ message: 'Only this team manager can update it.' }); await logActivity(req.user._id, 'UPDATE_TEAM', 'Team', item._id); emitAll('team:changed', item); res.json({ item }); } catch (e) { next(e); } };
exports.deleteTeam = async (req, res, next) => { try { const item = await Team.findByIdAndDelete(req.params.id); await logActivity(req.user._id, 'DELETE_TEAM', 'Team', req.params.id); res.json({ message: 'Team deleted.', item }); } catch (e) { next(e); } };
exports.setTeamMembers = async (req, res, next) => { try {
  const query = req.user.role === 'admin' ? { _id: req.params.id } : { _id: req.params.id, manager: req.user._id };
  const item = await Team.findOneAndUpdate(query, { members: req.body.members || [] }, { new: true, runValidators: true }).populate('manager members');
  if (!item) return res.status(403).json({ message: 'Only this team manager can update members.' });
  await logActivity(req.user._id, 'UPDATE_TEAM_MEMBERS', 'Team', item._id, { members: item.members.length });
  emitAll('team:changed', item); res.json({ item });
} catch (e) { next(e); } };
exports.listProjects = list(Project, 'team manager members');
exports.createProject = async (req, res, next) => { try { const item = await Project.create({ ...req.body, manager: req.body.manager || req.user._id }); await logActivity(req.user._id, 'CREATE_PROJECT', 'Project', item._id); emitAll('project:changed', item); res.status(201).json({ item }); } catch (e) { next(e); } };
exports.updateProject = async (req, res, next) => { try { const query = req.user.role === 'admin' ? { _id: req.params.id } : { _id: req.params.id, manager: req.user._id }; const item = await Project.findOneAndUpdate(query, req.body, { new: true, runValidators: true }); if (!item) return res.status(403).json({ message: 'Only this project manager can update it.' }); await logActivity(req.user._id, 'UPDATE_PROJECT', 'Project', item._id); emitAll('project:changed', item); res.json({ item }); } catch (e) { next(e); } };
exports.deleteProject = async (req, res, next) => { try { const item = await Project.findByIdAndDelete(req.params.id); await logActivity(req.user._id, 'DELETE_PROJECT', 'Project', req.params.id); res.json({ message: 'Project deleted.', item }); } catch (e) { next(e); } };
exports.listTasks = async (req, res, next) => { try {
  await sendPersonalReminders(req.user._id);
  const query = { ...await visibleTaskQuery(req.user), isArchived: req.query.archived === 'true' };
  ['status', 'priority', 'project', 'assignee', 'type', 'scope'].forEach((key) => { if (req.query[key]) query[key] = req.query[key]; });
  if (req.query.search) query.title = new RegExp(req.query.search, 'i');
  const items = await Task.find(query).populate('project assignee reporter collaborators watchers dependencies').sort(req.query.sort || '-createdAt');
  if (req.user.role !== 'admin') {
    const assignments = await ActivityAssignment.find({ recipient: req.user._id, activity: { $in: items.map((item) => item._id) } }).select('activity status');
    const statuses = new Map(assignments.map((item) => [String(item.activity), item.status]));
    const visibleItems = items.map((item) => ({ ...item.toObject(), myAssignmentStatus: statuses.get(String(item._id)) }));
    return res.json({ items: visibleItems, total: visibleItems.length });
  }
  res.json({ items, total: items.length });
} catch (e) { next(e); } };

exports.listPersonalTasks = async (req, res, next) => { try {
  await sendPersonalReminders(req.user._id);
  const query = { scope: 'personal', owner: req.user._id, isArchived: req.query.archived === 'true' };
  const items = await Task.find(query).populate('owner assignee reporter').sort(req.query.sort || '-createdAt');
  res.json({ items, total: items.length });
} catch (e) { next(e); } };

exports.createPersonalTask = async (req, res, next) => { try {
  if (!String(req.body.title || '').trim()) return res.status(400).json({ message: 'Title is required.' });
  const dateError = personalTaskDateError(req.body); if (dateError) return res.status(400).json({ message: dateError });
  const recurrence = req.body.recurrence || { frequency: 'none', count: 1, interval: 1 };
  const allowed = ['title', 'description', 'priority', 'status', 'startDate', 'deadline', 'reminderAt', 'tags', 'category', 'subtasks', 'recurrence'];
  const clean = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));
  const base = { ...clean, type: 'standard', scope: 'personal', project: undefined, owner: req.user._id, reporter: req.user._id, assignee: req.user._id, collaborators: [], watchers: [], dependencies: [] };
  const item = await Task.create(base);
  const copies = [];
  if (recurrence.frequency && recurrence.frequency !== 'none' && Number(recurrence.count) > 1) {
    for (let index = 1; index < Math.min(Number(recurrence.count), 50); index++) {
      const deadline = clean.deadline ? shiftDate(clean.deadline, recurrence.frequency, Number(recurrence.interval || 1), index) : undefined;
      if (recurrence.endDate && deadline && deadline > new Date(recurrence.endDate)) break;
      copies.push({ ...base, recurrenceParent: item._id, occurrenceDate: deadline, deadline, startDate: clean.startDate ? shiftDate(clean.startDate, recurrence.frequency, Number(recurrence.interval || 1), index) : undefined, reminderAt: clean.reminderAt ? shiftDate(clean.reminderAt, recurrence.frequency, Number(recurrence.interval || 1), index) : undefined });
    }
    if (copies.length) await Task.insertMany(copies);
  }
  await notify(req.user._id, 'Personal task created', item.title, 'personal-task', 'Task', item._id);
  await logActivity(req.user._id, 'CREATE_PERSONAL_TASK', 'Task', item._id, { occurrences: copies.length + 1 });
  emitToUser(String(req.user._id), 'task:changed', item);
  res.status(201).json({ item: await item.populate('owner assignee reporter'), occurrences: copies.length + 1 });
} catch (e) { next(e); } };

exports.updatePersonalTask = async (req, res, next) => { try {
  const before = await Task.findOne({ _id: req.params.id, scope: 'personal', owner: req.user._id });
  if (!before) return res.status(404).json({ message: 'Personal task not found.' });
  const dateError = personalTaskDateError(req.body, before); if (dateError) return res.status(400).json({ message: dateError });
  const allowed = ['title', 'description', 'priority', 'status', 'startDate', 'deadline', 'reminderAt', 'tags', 'category', 'subtasks', 'progress'];
  const changes = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));
  if (changes.status === 'completed') changes.completedAt = new Date();
  if (changes.status && changes.status !== 'completed') changes.completedAt = null;
  if (changes.reminderAt || changes.deadline) { changes.reminderNotifiedAt = null; changes.dueSoonNotifiedAt = null; changes.overdueNotifiedAt = null; }
  const item = await Task.findByIdAndUpdate(before._id, { $set: changes }, { new: true, runValidators: true }).populate('owner assignee reporter');
  await notify(req.user._id, changes.status === 'completed' ? 'Personal task completed' : 'Personal task updated', item.title, 'personal-task', 'Task', item._id);
  emitToUser(String(req.user._id), 'task:changed', item); res.json({ item });
} catch (e) { next(e); } };

exports.reopenPersonalTask = async (req, res, next) => { req.body = { ...req.body, status: 'todo' }; return exports.updatePersonalTask(req, res, next); };
exports.archivePersonalTask = async (req, res, next) => { try {
  const item = await Task.findOneAndUpdate({ _id: req.params.id, scope: 'personal', owner: req.user._id }, { isArchived: req.body.archived !== false }, { new: true });
  if (!item) return res.status(404).json({ message: 'Personal task not found.' });
  emitToUser(String(req.user._id), 'task:changed', item); res.json({ item });
} catch (e) { next(e); } };
exports.deletePersonalTask = async (req, res, next) => { try {
  const item = await Task.findOneAndDelete({ _id: req.params.id, scope: 'personal', owner: req.user._id });
  if (!item) return res.status(404).json({ message: 'Personal task not found.' });
  for (const attachment of item.attachments || []) fs.unlink(path.join(__dirname, '..', 'uploads', path.basename(attachment.url || '')), () => {});
  emitToUser(String(req.user._id), 'task:deleted', { id: item._id }); res.json({ message: 'Personal task deleted.' });
} catch (e) { next(e); } };
exports.getTask = async (req, res, next) => { try { const item = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) }).populate('project assignee reporter collaborators watchers dependencies'); if (!item) return res.status(404).json({ message: 'Task not found.' }); res.json({ item }); } catch (e) { next(e); } };

const validateDependencies = async (taskId, projectId, dependencies = []) => {
  const ids = [...new Set(dependencies.map(String))];
  if (taskId && ids.includes(String(taskId))) return 'A task cannot depend on itself.';
  const valid = await Task.countDocuments({ _id: { $in: ids }, project: projectId, type: 'standard' });
  if (valid !== ids.length) return 'Dependencies must be Standard Tasks in the same project.';
  if (taskId) {
    const visit = async (idsToVisit, seen = new Set()) => { for (const current of idsToVisit) { if (String(current) === String(taskId)) return true; if (seen.has(String(current))) continue; seen.add(String(current)); const task = await Task.findById(current).select('dependencies'); if (task && await visit(task.dependencies, seen)) return true; } return false; };
    if (await visit(ids)) return 'This dependency would create a cycle.';
  }
  return null;
};

exports.createTask = async (req, res, next) => { try {
  const project = await Project.findById(req.body.project);
  if (!project) return res.status(404).json({ message: 'Project not found.' });
  const allowedMembers = new Set([String(project.manager), ...(project.members || []).map(String)]);
  const participants = [req.body.assignee, ...(req.body.collaborators || []), ...(req.body.watchers || [])].filter(Boolean).map(String);
  if (participants.some((userId) => !allowedMembers.has(userId))) return res.status(400).json({ message: 'Assignee, collaborators, and watchers must belong to the project.' });
  const dependencyError = await validateDependencies(null, req.body.project, req.body.dependencies || []);
  if (dependencyError) return res.status(400).json({ message: dependencyError });
  if (req.body.status && (req.body.dependencies || []).length) { const incomplete = await Task.countDocuments({ _id: { $in: req.body.dependencies }, status: { $ne: 'completed' } }); const message = dependencyBlockMessage(req.body.status, incomplete); if (message) return res.status(409).json({ message }); }
  const recurrence = req.body.recurrence || { frequency: 'none', count: 1, interval: 1 };
  const item = await Task.create({ ...req.body, type: 'standard', reporter: req.user._id });
  const occurrences = [item];
  if (recurrence.frequency && recurrence.frequency !== 'none' && recurrence.count > 1) {
    const copies = [];
    for (let index = 1; index < Math.min(Number(recurrence.count), 50); index++) {
      const deadline = req.body.deadline ? shiftDate(req.body.deadline, recurrence.frequency, Number(recurrence.interval || 1), index) : undefined;
      if (recurrence.endDate && deadline && deadline > new Date(recurrence.endDate)) break;
      copies.push({ ...req.body, type: 'standard', reporter: req.user._id, recurrenceParent: item._id, occurrenceDate: deadline, deadline, startDate: req.body.startDate ? shiftDate(req.body.startDate, recurrence.frequency, Number(recurrence.interval || 1), index) : undefined, recurrence });
    }
    if (copies.length) occurrences.push(...await Task.insertMany(copies));
  }
  const recipients = [...new Set([item.assignee, ...(item.collaborators || []), ...(item.watchers || [])].filter(Boolean).map(String))];
  await Promise.all(recipients.map((recipient) => notify(recipient, 'New task assigned', item.title, 'assignment', 'Task', item._id)));
  await logActivity(req.user._id, 'CREATE_TASK', 'Task', item._id, { occurrences: occurrences.length }); emitAll('task:changed', item);
  res.status(201).json({ item: await item.populate('project assignee reporter collaborators watchers dependencies'), occurrences: occurrences.length });
} catch (e) { next(e); } };

exports.updateTask = async (req, res, next) => { try {
  const before = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) }); if (!before) return res.status(404).json({ message: 'Task not found.' });
  if (before.scope === 'personal') return exports.updatePersonalTask(req, res, next);
  if (before.type === 'individual-activity' && req.user.role === 'member') return res.status(403).json({ message: 'Use your individual assignment to update this activity.' });
  let changes = req.body;
  if (req.user.role === 'member') { if (String(before.assignee) !== String(req.user._id) && !(before.collaborators || []).map(String).includes(String(req.user._id))) return res.status(403).json({ message: 'Watchers cannot modify this task.' }); const allowed = ['status', 'subtasks', 'progress']; changes = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key))); }
  if (changes.dependencies) { const error = await validateDependencies(before._id, before.project, changes.dependencies); if (error) return res.status(400).json({ message: error }); }
  const effectiveDependencies = changes.dependencies || before.dependencies;
  if (changes.status && effectiveDependencies.length) { const incomplete = await Task.countDocuments({ _id: { $in: effectiveDependencies }, status: { $ne: 'completed' } }); const message = dependencyBlockMessage(changes.status, incomplete); if (message) return res.status(409).json({ message }); }
  const item = await Task.findByIdAndUpdate(req.params.id, changes, { new: true, runValidators: true }).populate('project assignee reporter collaborators watchers dependencies');
  await logActivity(req.user._id, 'UPDATE_TASK', 'Task', item._id, { status: item.status });
  if (before.status !== item.status) { const recipients = [...new Set([item.assignee, ...(item.collaborators || []), ...(item.watchers || [])].filter(Boolean).map((value) => String(value._id || value)))]; await Promise.all(recipients.map((recipient) => notify(recipient, 'Task status updated', `${item.title}: ${item.status}`, 'status', 'Task', item._id))); }
  emitAll('task:changed', item); res.json({ item });
} catch (e) { next(e); } };
exports.deleteTask = async (req, res, next) => { try { const query = req.user.role === 'admin' ? { _id: req.params.id, scope: { $ne: 'personal' } } : { _id: req.params.id, scope: { $ne: 'personal' }, reporter: req.user._id }; const item = await Task.findOneAndDelete(query); if (!item) return res.status(403).json({ message: 'Only the creator or an administrator can delete this task.' }); if (item.type === 'individual-activity') await ActivityAssignment.deleteMany({ activity: item._id }); await logActivity(req.user._id, 'DELETE_TASK', 'Task', req.params.id); emitAll('task:deleted', { id: req.params.id }); res.json({ message: 'Task deleted.', item }); } catch (e) { next(e); } };
exports.addAttachment = async (req, res, next) => { try {
  if (!req.file) return res.status(400).json({ message: 'Choose a file to upload.' });
  const task = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) });
  if (!task) return res.status(404).json({ message: 'Task not found.' });
  if (task.scope === 'personal') {
    const allowed = new Set(['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.webp', '.txt', '.xls', '.xlsx']);
    if (!allowed.has(path.extname(req.file.originalname).toLowerCase())) { fs.unlink(req.file.path, () => {}); return res.status(400).json({ message: 'Unsupported personal task attachment type.' }); }
  }
  if (task.type === 'individual-activity' && req.user.role === 'member') { fs.unlink(req.file.path, () => {}); return res.status(403).json({ message: 'Upload files to your private activity assignment.' }); }
  if (task.type === 'standard' && req.user.role === 'member' && String(task.assignee) !== String(req.user._id) && !(task.collaborators || []).map(String).includes(String(req.user._id))) { fs.unlink(req.file.path, () => {}); return res.status(403).json({ message: 'Watchers cannot upload task files.' }); }
  const attachment = { name: req.file.originalname, url: `/uploads/${req.file.filename}`, mimeType: req.file.mimetype, size: req.file.size };
  task.attachments.push(attachment); await task.save();
  if (task.recurrence?.frequency && task.recurrence.frequency !== 'none' && !task.recurrenceParent) await Task.updateMany({ recurrenceParent: task._id }, { $push: { attachments: attachment } });
  await logActivity(req.user._id, 'ADD_ATTACHMENT', 'Task', task._id, { name: attachment.name });
  if (task.scope === 'personal') emitToUser(String(req.user._id), 'task:changed', task); else emitAll('task:changed', task); res.status(201).json({ item: attachment, task });
} catch (e) { next(e); } };
exports.deleteAttachment = async (req, res, next) => { try {
  const task = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) });
  if (!task) return res.status(404).json({ message: 'Task not found.' });
  if (task.type === 'individual-activity' && req.user.role === 'member') return res.status(403).json({ message: 'Only an activity creator or reviewer can delete reference files.' });
  if (task.type === 'standard' && req.user.role === 'member' && String(task.assignee) !== String(req.user._id) && !(task.collaborators || []).map(String).includes(String(req.user._id))) return res.status(403).json({ message: 'Watchers cannot delete task files.' });
  const attachment = task.attachments.id(req.params.attachmentId);
  if (!attachment) return res.status(404).json({ message: 'Attachment not found.' });
  const attachmentUrl = attachment.url, filename = path.basename(attachmentUrl); attachment.deleteOne(); await task.save();
  if (task.recurrence?.frequency && task.recurrence.frequency !== 'none' && !task.recurrenceParent) await Task.updateMany({ recurrenceParent: task._id }, { $pull: { attachments: { url: attachmentUrl } } });
  fs.unlink(path.join(__dirname, '..', 'uploads', filename), () => {});
  if (task.scope === 'personal') emitToUser(String(req.user._id), 'task:changed', task); else emitAll('task:changed', task); res.json({ message: 'Attachment deleted.' });
} catch (e) { next(e); } };
exports.listComments = async (req, res, next) => { try { const task = await Task.findOne({ _id: req.params.taskId, ...await visibleTaskQuery(req.user) }); if (!task) return res.status(404).json({ message: 'Task not found.' }); res.json({ items: await Comment.find({ task: task._id }).populate('author').sort('createdAt') }); } catch (e) { next(e); } };
exports.createComment = async (req, res, next) => { try { const task = await Task.findOne({ _id: req.params.taskId, ...await visibleTaskQuery(req.user) }); if (!task) return res.status(404).json({ message: 'Task not found.' }); const item = await Comment.create({ task: task._id, author: req.user._id, body: req.body.body }); await logActivity(req.user._id, 'COMMENT_TASK', 'Task', task._id); if (task.scope === 'personal') emitToUser(String(req.user._id), 'comment:new', item); else emitAll('comment:new', item); res.status(201).json({ item }); } catch (e) { next(e); } };
exports.updateComment = async (req, res, next) => { try { const item = await Comment.findOneAndUpdate({ _id: req.params.id, author: req.user._id }, { body: req.body.body }, { new: true, runValidators: true }); if (!item) return res.status(404).json({ message: 'Comment not found.' }); res.json({ item }); } catch (e) { next(e); } };
exports.deleteComment = async (req, res, next) => { try { const query = req.user.role === 'admin' ? { _id: req.params.id } : { _id: req.params.id, author: req.user._id }; const item = await Comment.findOneAndDelete(query); if (!item) return res.status(404).json({ message: 'Comment not found.' }); res.json({ message: 'Comment deleted.' }); } catch (e) { next(e); } };
exports.notifications = async (req, res, next) => { try { res.json({ items: await Notification.find({ user: req.user._id }).sort('-createdAt') }); } catch (e) { next(e); } };
exports.readNotification = async (req, res, next) => { try { res.json({ item: await Notification.findOneAndUpdate({ _id: req.params.id, user: req.user._id }, { isRead: true }, { new: true }) }); } catch (e) { next(e); } };
exports.readAll = async (req, res, next) => { try { await Notification.updateMany({ user: req.user._id }, { isRead: true }); res.json({ message: 'Notifications marked as read.' }); } catch (e) { next(e); } };
exports.deleteNotification = async (req, res, next) => { try { await Notification.deleteOne({ _id: req.params.id, user: req.user._id }); res.json({ message: 'Notification deleted.' }); } catch (e) { next(e); } };
exports.activity = async (req, res, next) => { try { res.json({ items: await Activity.find({}).populate('actor').sort('-createdAt').limit(200) }); } catch (e) { next(e); } };
exports.dashboard = async (req, res, next) => { try { const tq = await visibleTaskQuery(req.user); const [projects, total, todo, inProgress, review, completed, overdue, recent] = await Promise.all([Project.countDocuments({ isArchived: false }), Task.countDocuments(tq), Task.countDocuments({ ...tq, status: 'todo' }), Task.countDocuments({ ...tq, status: 'in-progress' }), Task.countDocuments({ ...tq, status: 'for-review' }), Task.countDocuments({ ...tq, status: 'completed' }), Task.countDocuments({ ...tq, deadline: { $lt: new Date() }, status: { $ne: 'completed' } }), Activity.find({}).populate('actor').sort('-createdAt').limit(10)]); res.json({ projects, total, todo, inProgress, review, completed, overdue, recent }); } catch (e) { next(e); } };
