const ActivityLog = require('../models/activityLogModel');
const logActivity = (actor, action, entityType, entityId, metadata = {}) =>
  ActivityLog.create({ actor, action, entityType, entityId, metadata });
module.exports = { logActivity };
