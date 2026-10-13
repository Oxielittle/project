const test = require('node:test');
const assert = require('node:assert/strict');
const Task = require('../models/taskModel');
const Assignment = require('../models/activityAssignmentModel');
const { shiftDate, dependencyBlockMessage, personalTaskDateError } = require('../services/taskRules');

test('task schema keeps new collaboration fields backward compatible', () => {
  const task = new Task({ title: 'Task', project: '507f1f77bcf86cd799439011', reporter: '507f191e810c19729de860ea' });
  assert.deepEqual(task.collaborators, []);
  assert.deepEqual(task.watchers, []);
  assert.deepEqual(task.dependencies, []);
  assert.equal(task.recurrence.frequency, 'none');
  assert.equal(task.isCancelled, false);
});

test('recurrence dates advance daily weekly and monthly', () => {
  assert.equal(shiftDate('2026-10-01T00:00:00Z', 'daily', 2, 2).toISOString(), '2026-10-05T00:00:00.000Z');
  assert.equal(shiftDate('2026-10-01T00:00:00Z', 'weekly', 1, 2).toISOString(), '2026-10-15T00:00:00.000Z');
  assert.equal(shiftDate('2026-10-01T00:00:00Z', 'monthly', 1, 2).toISOString(), '2026-12-01T00:00:00.000Z');
});

test('incomplete dependencies block active statuses but not todo', () => {
  assert.equal(dependencyBlockMessage('todo', 2), null);
  assert.match(dependencyBlockMessage('in-progress', 2), /blocked by 2/);
  assert.equal(dependencyBlockMessage('completed', 0), null);
});

test('activity assignments support reopened and cancelled states', () => {
  const values = Assignment.schema.path('status').enumValues;
  assert.ok(values.includes('reopened'));
  assert.ok(values.includes('cancelled'));
});

test('personal tasks are valid without projects and retain private ownership', () => {
  const task = new Task({ title: 'Reminder', scope: 'personal', owner: '507f191e810c19729de860ea', reporter: '507f191e810c19729de860ea', assignee: '507f191e810c19729de860ea' });
  assert.equal(task.validateSync(), undefined);
  assert.equal(task.scope, 'personal');
  assert.equal(String(task.owner), '507f191e810c19729de860ea');
  assert.deepEqual(task.collaborators, []);
  assert.deepEqual(task.dependencies, []);
});

test('project tasks still require a project', () => {
  const task = new Task({ title: 'Project work', reporter: '507f191e810c19729de860ea' });
  assert.match(task.validateSync().message, /project/i);
});

test('personal task dates reject invalid deadline and reminder order', () => {
  assert.match(personalTaskDateError({ startDate: '2026-10-20', deadline: '2026-10-19' }), /Deadline/);
  assert.match(personalTaskDateError({ deadline: '2026-10-20', reminderAt: '2026-10-21' }), /Reminder/);
  assert.equal(personalTaskDateError({ startDate: '2026-10-19', deadline: '2026-10-20', reminderAt: '2026-10-19' }), null);
});
