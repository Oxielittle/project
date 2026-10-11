import 'package:flutter_test/flutter_test.dart';
import 'package:project/models/activity_assignment.dart';
import 'package:project/models/task_item.dart';

void main() {
  test(
    'parses an individual activity without treating it as a shared task',
    () {
      final task = TaskItem.fromJson({
        '_id': 'activity-1',
        'type': 'individual-activity',
        'title': 'Essay',
        'project': {'_id': 'project-1', 'name': 'Class'},
        'reporter': {'_id': 'teacher-1'},
        'deadline': '2026-10-20T00:00:00.000Z',
        'activitySettings': {'maxSubmissions': 2},
      });

      expect(task.isIndividualActivity, isTrue);
      expect(task.reporterId, 'teacher-1');
      expect(task.activitySettings['maxSubmissions'], 2);
    },
  );

  test('parses recipient-specific submission data', () {
    final assignment = ActivityAssignment.fromJson({
      '_id': 'assignment-1',
      'recipient': {
        '_id': 'student-1',
        'firstName': 'Ada',
        'lastName': 'Lovelace',
      },
      'status': 'submitted',
      'submissionCount': 1,
      'maximumScore': 100,
      'attachments': [],
      'submissionHistory': [],
    });

    expect(assignment.recipient, 'Ada Lovelace');
    expect(assignment.status, 'submitted');
    expect(assignment.submissionCount, 1);
  });
}
