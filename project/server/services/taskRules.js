const shiftDate = (value, frequency, interval, index) => {
  const date = new Date(value);
  if (frequency === 'daily') date.setDate(date.getDate() + interval * index);
  if (frequency === 'weekly') date.setDate(date.getDate() + 7 * interval * index);
  if (frequency === 'monthly') date.setMonth(date.getMonth() + interval * index);
  return date;
};

const dependencyBlockMessage = (status, incompleteCount) =>
  incompleteCount > 0 && ['in-progress', 'for-review', 'completed'].includes(status)
    ? `This task is blocked by ${incompleteCount} incomplete dependency task(s).`
    : null;

const personalTaskDateError = (body, current = {}) => {
  const start = body.startDate !== undefined ? body.startDate : current.startDate;
  const deadline = body.deadline !== undefined ? body.deadline : current.deadline;
  const reminder = body.reminderAt !== undefined ? body.reminderAt : current.reminderAt;
  if (start && deadline && new Date(deadline) < new Date(start)) return 'Deadline cannot be before the start date.';
  if (reminder && deadline && new Date(reminder) > new Date(deadline)) return 'Reminder cannot be after the deadline.';
  return null;
};

module.exports = { shiftDate, dependencyBlockMessage, personalTaskDateError };
