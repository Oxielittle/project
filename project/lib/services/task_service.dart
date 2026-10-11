import '../models/task_item.dart';
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
