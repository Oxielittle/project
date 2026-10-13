import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/models/activity_assignment.dart';
import 'package:project/models/task_item.dart';
import 'package:project/pages/ActivityDetailsPage.dart';
import 'package:project/pages/CreateTaskPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaskItem activityTask() => TaskItem(
  id: 'activity-1',
  title: 'Individual essay',
  description: 'Submit your own response.',
  project: 'Class project',
  projectId: 'project-1',
  assignee: 'Unassigned',
  priority: TaskPriority.medium,
  status: TaskStatus.todo,
  dueDate: DateTime(2026, 10, 20),
  type: 'individual-activity',
  activitySettings: const {
    'allowTextResponse': true,
    'requireAttachment': false,
    'allowResubmission': true,
  },
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_user': '{"role":"manager"}'});
  });
  testWidgets('task type selector reveals individual activity fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CreateTaskPage(
          onCreate: (_) {},
          initialProjects: const [],
          initialUsers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-type-selector')), findsOneWidget);
    expect(find.byKey(const Key('recipient-picker')), findsNothing);
    expect(find.text('Assignee'), findsOneWidget);

    await tester.tap(find.text('Individual activity'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recipient-picker')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Submission settings'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Submission settings'), findsOneWidget);
    expect(find.text('Assignee'), findsNothing);
  });

  testWidgets('standard task form exposes advanced creation options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateTaskPage(
          onCreate: (_) {},
          initialProjects: const [],
          initialUsers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Task options'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Task options'), findsOneWidget);
    expect(find.text('Collaborators'), findsOneWidget);
    expect(find.text('Watchers'), findsOneWidget);
    expect(find.text('Subtasks'), findsOneWidget);
    expect(find.text('Dependencies'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
  });

  testWidgets('recipient submission screen shows private response controls', (
    tester,
  ) async {
    final assignment = ActivityAssignment.fromJson({
      '_id': 'assignment-1',
      'recipient': {'_id': 'student-1', 'firstName': 'Student'},
      'status': 'in-progress',
      'attachments': [],
      'submissionHistory': [],
      'maximumScore': 100,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailsPage(
          task: activityTask(),
          initialReviewerView: false,
          initialAssignment: assignment,
        ),
      ),
    );

    expect(find.text('Your assignment'), findsOneWidget);
    expect(find.text('Your response'), findsOneWidget);
    expect(find.text('Submit activity'), findsOneWidget);
  });

  testWidgets('creator overview renders a useful empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailsPage(
          task: activityTask(),
          initialReviewerView: true,
          initialAssignments: const [],
          initialCounts: const {},
        ),
      ),
    );

    expect(find.text('Submission overview'), findsOneWidget);
    expect(find.text('Search recipients'), findsOneWidget);
    expect(find.text('No assignments match this filter.'), findsOneWidget);
  });
}
