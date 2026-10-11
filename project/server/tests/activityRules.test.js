const test = require('node:test');
const assert = require('node:assert/strict');
const Task = require('../models/taskModel');
const Assignment = require('../models/activityAssignmentModel');
const { submissionError, isLateSubmission, canReviewByRole, recipientScope } = require('../services/activityRules');

const activity = (settings = {}) => ({ activitySettings: { allowTextResponse: true, requireAttachment: false, allowResubmission: true, maxSubmissions: 3, ...settings } });
const assignment = (values = {}) => ({ status: 'assigned', submissionCount: 0, attachments: [], ...values });

test('existing task documents default to standard tasks', () => {
  assert.equal(new Task({ title: 'Old task', project: '507f1f77bcf86cd799439011', reporter: '507f191e810c19729de860ea' }).type, 'standard');
});

test('assignment schema prevents duplicate activity and recipient pairs', () => {
  const index = Assignment.schema.indexes().find(([keys]) => keys.activity === 1 && keys.recipient === 1);
  assert.equal(index[1].unique, true);
});

test('validates required attachments and resubmission limits', () => {
  assert.equal(submissionError({ activity: activity({ requireAttachment: true }), assignment: assignment(), textResponse: '' }), 'At least one attachment is required.');
  assert.equal(submissionError({ activity: activity({ maxSubmissions: 1 }), assignment: assignment({ submissionCount: 1 }), textResponse: 'done' }), 'Submission limit reached.');
});

test('detects on-time and late submissions', () => {
  const deadline = new Date('2026-10-10T12:00:00Z');
  assert.equal(isLateSubmission(deadline, new Date('2026-10-10T11:59:00Z')), false);
  assert.equal(isLateSubmission(deadline, new Date('2026-10-10T12:01:00Z')), true);
});

test('accepted submissions are immutable and valid text can submit', () => {
  assert.equal(submissionError({ activity: activity(), assignment: assignment({ status: 'accepted' }), textResponse: 'changed' }), 'An accepted submission cannot be changed.');
  assert.equal(submissionError({ activity: activity(), assignment: assignment(), textResponse: 'my own answer' }), null);
});

test('review permissions reject unrelated managers and members', () => {
  assert.equal(canReviewByRole({ role: 'admin', userId: 'a', reporterId: 'b' }), true);
  assert.equal(canReviewByRole({ role: 'manager', userId: 'creator', reporterId: 'creator' }), true);
  assert.equal(canReviewByRole({ role: 'manager', userId: 'other', reporterId: 'creator', managesProject: true }), true);
  assert.equal(canReviewByRole({ role: 'manager', userId: 'other', reporterId: 'creator', managesProject: false }), false);
  assert.equal(canReviewByRole({ role: 'member', userId: 'student', reporterId: 'creator' }), false);
});

test('recipient queries are always scoped to the signed-in user', () => {
  assert.deepEqual(recipientScope('student-a', { _id: 'assignment-1' }), { _id: 'assignment-1', recipient: 'student-a' });
});
