import '../models/task_item.dart';
import '../models/activity_assignment.dart';
import 'api_client.dart';

class TaskService {
  static Future<List<TaskItem>> list() async =>
      ((await ApiClient.get('/tasks'))['items'] as List)
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  static Future<List<TaskItem>> forProject(String projectId) async =>
      ((await ApiClient.get('/tasks?project=$projectId'))['items'] as List)
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  static Future<void> updateStatus(TaskItem task, TaskStatus status) async =>
      ApiClient.patch('/tasks/${task.id}', {'status': status.api});
  static Future<List<Map<String, dynamic>>> projects() async =>
      List<Map<String, dynamic>>.from(
        (await ApiClient.get('/projects'))['items'],
      );
  static Future<List<Map<String, dynamic>>> users() async =>
      List<Map<String, dynamic>>.from((await ApiClient.get('/users'))['items']);
  static Future<TaskItem> create(Map<String, dynamic> body) async =>
      TaskItem.fromJson(
        Map<String, dynamic>.from(
          (await ApiClient.post('/tasks', body))['item'],
        ),
      );
  static Future<TaskItem> createActivity(Map<String, dynamic> body) async =>
      TaskItem.fromJson(
        Map<String, dynamic>.from(
          (await ApiClient.post('/activities', body))['item'],
        ),
      );
  static Future<ActivityAssignment> myActivityAssignment(String id) async =>
      ActivityAssignment.fromJson(
        Map<String, dynamic>.from(
          (await ApiClient.get('/activities/$id/my-assignment'))['item'],
        ),
      );
  static Future<Map<String, dynamic>> activityAssignments(
    String id, {
    String? status,
  }) async => Map<String, dynamic>.from(
    await ApiClient.get(
      '/activities/$id/assignments${status == null || status.isEmpty ? '' : '?status=$status'}',
    ),
  );
  static Future<ActivityAssignment> startAssignment(String id) async =>
      ActivityAssignment.fromJson(
        Map<String, dynamic>.from(
          (await ApiClient.patch(
            '/activity-assignments/$id/start',
            const {},
          ))['item'],
        ),
      );
  static Future<ActivityAssignment> submitAssignment(
    String id,
    String textResponse,
  ) async => ActivityAssignment.fromJson(
    Map<String, dynamic>.from(
      (await ApiClient.post('/activity-assignments/$id/submit', {
        'textResponse': textResponse,
      }))['item'],
    ),
  );
  static Future<ActivityAssignment> reviewAssignment(
    String id, {
    required String status,
    String feedback = '',
    num? score,
  }) async => ActivityAssignment.fromJson(
    Map<String, dynamic>.from(
      (await ApiClient.patch('/activity-assignments/$id/review', {
        'status': status,
        'feedback': feedback,
        if (score != null) 'score': score,
      }))['item'],
    ),
  );
  static Future<String> remindActivity(String id) async =>
      (await ApiClient.post('/activities/$id/remind', const {}))['message'];
  static Future<TaskItem> updateActivity(
    String id,
    Map<String, dynamic> body,
  ) async => TaskItem.fromJson(
    Map<String, dynamic>.from(
      (await ApiClient.patch('/activities/$id', body))['item'],
    ),
  );
  static Future<void> addActivityRecipients(
    String id,
    List<String> recipients,
  ) async =>
      ApiClient.post('/activities/$id/recipients', {'recipients': recipients});
  static Future<void> removeActivityRecipient(String id, String userId) async =>
      ApiClient.delete('/activities/$id/recipients/$userId');
  static Future<void> archiveActivity(String id, bool archived) async =>
      ApiClient.patch('/activities/$id/archive', {'archived': archived});
  static Future<void> cancelActivity(String id, String reason) async =>
      ApiClient.patch('/activities/$id/cancel', {'reason': reason});
  static Future<int> reopenActivity(
    String id, {
    List<String>? assignmentIds,
    DateTime? deadline,
    String reason = '',
  }) async =>
      ((await ApiClient.post('/activities/$id/reopen', {
                if (assignmentIds != null) 'assignmentIds': assignmentIds,
                if (deadline != null) 'deadline': deadline.toIso8601String(),
                'reason': reason,
              }))['reopened']
              as num)
          .toInt();
  static Future<TaskItem> update(String id, Map<String, dynamic> body) async =>
      TaskItem.fromJson(
        Map<String, dynamic>.from(
          (await ApiClient.patch('/tasks/$id', body))['item'],
        ),
      );
  static Future<void> archive(String id, bool value) async =>
      ApiClient.patch('/tasks/$id', {'isArchived': value});
  static Future<void> delete(String id) async => ApiClient.delete('/tasks/$id');
  static Future<List<dynamic>> comments(String id) async =>
      (await ApiClient.get('/comments/task/$id'))['items'];
  static Future<void> comment(String id, String body) async =>
      ApiClient.post('/comments/task/$id', {'body': body});
}
