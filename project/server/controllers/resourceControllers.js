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
const { emitAll } = require('../services/events');
const fs = require('fs');
const path = require('path');

const visibleTaskQuery = async (user) => {
  if (user.role === 'admin') return {};
  const activityIds = await ActivityAssignment.find({ recipient: user._id }).distinct('activity');
  if (user.role === 'manager') {
    const managedProjects = await Project.find({ manager: user._id }).distinct('_id');
    return { $or: [{ reporter: user._id }, { assignee: user._id }, { _id: { $in: activityIds } }, { project: { $in: managedProjects } }] };
  }
  return { $or: [{ assignee: user._id }, { _id: { $in: activityIds } }] };
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
  const query = { ...await visibleTaskQuery(req.user), isArchived: req.query.archived === 'true' };
  ['status', 'priority', 'project', 'assignee', 'type'].forEach((key) => { if (req.query[key]) query[key] = req.query[key]; });
  if (req.query.search) query.title = new RegExp(req.query.search, 'i');
  const items = await Task.find(query).populate('project assignee reporter').sort(req.query.sort || '-createdAt');
  if (req.user.role !== 'admin') {
    const assignments = await ActivityAssignment.find({ recipient: req.user._id, activity: { $in: items.map((item) => item._id) } }).select('activity status');
    const statuses = new Map(assignments.map((item) => [String(item.activity), item.status]));
    const visibleItems = items.map((item) => ({ ...item.toObject(), myAssignmentStatus: statuses.get(String(item._id)) }));
    return res.json({ items: visibleItems, total: visibleItems.length });
  }
  res.json({ items, total: items.length });
} catch (e) { next(e); } };
exports.getTask = async (req, res, next) => { try { const item = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) }).populate('project assignee reporter'); if (!item) return res.status(404).json({ message: 'Task not found.' }); res.json({ item }); } catch (e) { next(e); } };
exports.createTask = async (req, res, next) => { try { const item = await Task.create({ ...req.body, reporter: req.user._id }); await logActivity(req.user._id, 'CREATE_TASK', 'Task', item._id); await notify(item.assignee, 'New task assigned', item.title, 'assignment', 'Task', item._id); emitAll('task:changed', item); res.status(201).json({ item }); } catch (e) { next(e); } };
exports.updateTask = async (req, res, next) => { try { const before = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) }); if (!before) return res.status(404).json({ message: 'Task not found.' }); if (before.type === 'individual-activity' && req.user.role === 'member') return res.status(403).json({ message: 'Use your individual assignment to update this activity.' }); let changes = req.body; if (req.user.role === 'member') { const allowed = ['status', 'subtasks', 'progress']; changes = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key))); } const item = await Task.findByIdAndUpdate(req.params.id, changes, { new: true, runValidators: true }); await logActivity(req.user._id, 'UPDATE_TASK', 'Task', item._id, { status: item.status }); if (before.status !== item.status) await notify(item.assignee, 'Task status updated', `${item.title}: ${item.status}`, 'status', 'Task', item._id); emitAll('task:changed', item); res.json({ item }); } catch (e) { next(e); } };
exports.deleteTask = async (req, res, next) => { try { const query = req.user.role === 'admin' ? { _id: req.params.id } : { _id: req.params.id, reporter: req.user._id }; const item = await Task.findOneAndDelete(query); if (!item) return res.status(403).json({ message: 'Only the creator or an administrator can delete this task.' }); if (item.type === 'individual-activity') await ActivityAssignment.deleteMany({ activity: item._id }); await logActivity(req.user._id, 'DELETE_TASK', 'Task', req.params.id); emitAll('task:deleted', { id: req.params.id }); res.json({ message: 'Task deleted.', item }); } catch (e) { next(e); } };
exports.addAttachment = async (req, res, next) => { try {
  if (!req.file) return res.status(400).json({ message: 'Choose a file to upload.' });
  const task = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) });
  if (!task) return res.status(404).json({ message: 'Task not found.' });
  if (task.type === 'individual-activity' && req.user.role === 'member') { fs.unlink(req.file.path, () => {}); return res.status(403).json({ message: 'Upload files to your private activity assignment.' }); }
  const attachment = { name: req.file.originalname, url: `/uploads/${req.file.filename}`, mimeType: req.file.mimetype, size: req.file.size };
  task.attachments.push(attachment); await task.save();
  await logActivity(req.user._id, 'ADD_ATTACHMENT', 'Task', task._id, { name: attachment.name });
  emitAll('task:changed', task); res.status(201).json({ item: attachment, task });
} catch (e) { next(e); } };
exports.deleteAttachment = async (req, res, next) => { try {
  const task = await Task.findOne({ _id: req.params.id, ...await visibleTaskQuery(req.user) });
  if (!task) return res.status(404).json({ message: 'Task not found.' });
  if (task.type === 'individual-activity' && req.user.role === 'member') return res.status(403).json({ message: 'Only an activity creator or reviewer can delete reference files.' });
  const attachment = task.attachments.id(req.params.attachmentId);
  if (!attachment) return res.status(404).json({ message: 'Attachment not found.' });
  const filename = path.basename(attachment.url); attachment.deleteOne(); await task.save();
  fs.unlink(path.join(__dirname, '..', 'uploads', filename), () => {});
  emitAll('task:changed', task); res.json({ message: 'Attachment deleted.' });
} catch (e) { next(e); } };
exports.listComments = async (req, res, next) => { try { res.json({ items: await Comment.find({ task: req.params.taskId }).populate('author').sort('createdAt') }); } catch (e) { next(e); } };
exports.createComment = async (req, res, next) => { try { const item = await Comment.create({ task: req.params.taskId, author: req.user._id, body: req.body.body }); await logActivity(req.user._id, 'COMMENT_TASK', 'Task', req.params.taskId); emitAll('comment:new', item); res.status(201).json({ item }); } catch (e) { next(e); } };
exports.updateComment = async (req, res, next) => { try { const item = await Comment.findOneAndUpdate({ _id: req.params.id, author: req.user._id }, { body: req.body.body }, { new: true, runValidators: true }); if (!item) return res.status(404).json({ message: 'Comment not found.' }); res.json({ item }); } catch (e) { next(e); } };
exports.deleteComment = async (req, res, next) => { try { const query = req.user.role === 'admin' ? { _id: req.params.id } : { _id: req.params.id, author: req.user._id }; const item = await Comment.findOneAndDelete(query); if (!item) return res.status(404).json({ message: 'Comment not found.' }); res.json({ message: 'Comment deleted.' }); } catch (e) { next(e); } };
exports.notifications = async (req, res, next) => { try { res.json({ items: await Notification.find({ user: req.user._id }).sort('-createdAt') }); } catch (e) { next(e); } };
exports.readNotification = async (req, res, next) => { try { res.json({ item: await Notification.findOneAndUpdate({ _id: req.params.id, user: req.user._id }, { isRead: true }, { new: true }) }); } catch (e) { next(e); } };
exports.readAll = async (req, res, next) => { try { await Notification.updateMany({ user: req.user._id }, { isRead: true }); res.json({ message: 'Notifications marked as read.' }); } catch (e) { next(e); } };
exports.deleteNotification = async (req, res, next) => { try { await Notification.deleteOne({ _id: req.params.id, user: req.user._id }); res.json({ message: 'Notification deleted.' }); } catch (e) { next(e); } };
exports.activity = async (req, res, next) => { try { res.json({ items: await Activity.find({}).populate('actor').sort('-createdAt').limit(200) }); } catch (e) { next(e); } };
exports.dashboard = async (req, res, next) => { try { const tq = await visibleTaskQuery(req.user); const [projects, total, todo, inProgress, review, completed, overdue, recent] = await Promise.all([Project.countDocuments({ isArchived: false }), Task.countDocuments(tq), Task.countDocuments({ ...tq, status: 'todo' }), Task.countDocuments({ ...tq, status: 'in-progress' }), Task.countDocuments({ ...tq, status: 'for-review' }), Task.countDocuments({ ...tq, status: 'completed' }), Task.countDocuments({ ...tq, deadline: { $lt: new Date() }, status: { $ne: 'completed' } }), Activity.find({}).populate('actor').sort('-createdAt').limit(10)]); res.json({ projects, total, todo, inProgress, review, completed, overdue, recent }); } catch (e) { next(e); } };
