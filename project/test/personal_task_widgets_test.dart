import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/models/task_item.dart';
import 'package:project/pages/CreateTaskPage.dart';
import 'package:project/pages/DashboardPage.dart';
import 'package:project/pages/TaskListPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaskItem personalTask({TaskStatus status = TaskStatus.todo}) => TaskItem(
  id: 'personal-1',
  title: 'Private reminder',
  description: 'Remember this',
  project: 'Personal',
  assignee: 'Me',
  priority: TaskPriority.medium,
  status: status,
  dueDate: DateTime(2026, 10, 20),
  scope: 'personal',
);

void main() {
  testWidgets('member can create only a personal task', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_user': '{"role":"member"}'});
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
    expect(find.text('Personal task'), findsOneWidget);
    expect(find.text('Project task'), findsNothing);
    expect(find.text('Individual activity'), findsNothing);
    expect(find.text('Project *'), findsNothing);
    expect(find.text('Assignee'), findsNothing);
    expect(find.text('Private personal task'), findsOneWidget);
  });

  testWidgets('personal badge appears in the task list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TaskListPage(
          tasks: [personalTask()],
          onStatusChanged: (_, __) {},
          onRefresh: () async {},
        ),
      ),
    );
    expect(find.text('Personal'), findsWidgets);
    expect(find.text('Private reminder'), findsOneWidget);
  });

  testWidgets('dashboard offers personal workload filtering', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(tasks: [personalTask()], onViewTasks: () {}),
      ),
    );
    expect(find.byKey(const Key('dashboard-work-filter')), findsOneWidget);
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.text('Task overview'), findsOneWidget);
  });
}
