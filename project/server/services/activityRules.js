const submissionError = ({ activity, assignment, textResponse = '', now = new Date() }) => {
  const settings = activity.activitySettings || {};
  if (activity.startDate && new Date(activity.startDate) > now) return 'This activity has not started.';
  if (assignment.status === 'accepted') return 'An accepted submission cannot be changed.';
  if (assignment.status === 'cancelled') return 'This assignment is cancelled.';
  if (assignment.submissionCount && !settings.allowResubmission) return 'Resubmission is disabled.';
  if (assignment.submissionCount >= (settings.maxSubmissions || 1)) return 'Submission limit reached.';
  if (settings.requireAttachment && !assignment.attachments.length) return 'At least one attachment is required.';
  if (!settings.allowTextResponse && textResponse) return 'Text responses are disabled.';
  if (settings.allowTextResponse && !settings.requireAttachment && !String(textResponse).trim()) return 'Enter a response.';
  return null;
};

const isLateSubmission = (deadline, now = new Date()) => Boolean(deadline && now > new Date(deadline));

const canReviewByRole = ({ role, userId, reporterId, managesProject = false }) =>
  role === 'admin' || String(userId) === String(reporterId) || (role === 'manager' && managesProject);

const recipientScope = (userId, query = {}) => ({ ...query, recipient: userId });

module.exports = { submissionError, isLateSubmission, canReviewByRole, recipientScope };
