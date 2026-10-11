const Notification = require('../models/notificationModel');
const { emitToUser } = require('./events');
const notify = async (user, title, message, type, entityType, entityId) => {
  if (!user) return null;
  const item = await Notification.create({ user, title, message, type, entityType, entityId });
  emitToUser(user.toString(), 'notification:new', item);
  return item;
};
module.exports = { notify };
