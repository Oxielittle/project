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

module.exports = { shiftDate, dependencyBlockMessage };
