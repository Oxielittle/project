import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({
    super.key,
    required this.task,
    required this.onStatusChanged,
  });

  final TaskItem task;
  final void Function(TaskItem, TaskStatus) onStatusChanged;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final _comment = TextEditingController();
  List<dynamic> _comments = [];
  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final items = await TaskService.comments(widget.task.id);
      if (mounted) setState(() => _comments = items);
    } catch (_) {}
  }

  Future<void> _addComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    await TaskService.comment(widget.task.id, text);
    _comment.clear();
    await _loadComments();
  }

  Future<void> _archive() async {
    await TaskService.archive(widget.task.id, true);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _uploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    try {
      final data = await ApiClient.upload(
        '/tasks/${widget.task.id}/attachments',
        file.bytes!,
        file.name,
      );
      if (mounted)
        setState(
          () => widget.task.attachments.add(
            Map<String, dynamic>.from(data['item']),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final root = ApiConfig.api.replaceFirst('/api', '');
    await launchUrl(
      Uri.parse('$root${attachment['url']}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _deleteAttachment(Map<String, dynamic> attachment) async {
    await ApiClient.delete(
      '/tasks/${widget.task.id}/attachments/${attachment['_id']}',
    );
    if (mounted) setState(() => widget.task.attachments.remove(attachment));
  }

  Future<void> _saveSubtasks() async {
    await TaskService.update(widget.task.id, {
      'subtasks': widget.task.subtasks,
    });
    if (mounted) setState(() {});
  }

  Future<void> _addSubtask() async {
    final controller = TextEditingController();
    final add =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add subtask'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Subtask title'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
        ) ??
        false;
    if (add && controller.text.trim().isNotEmpty) {
      widget.task.subtasks.add({
        'title': controller.text.trim(),
        'completed': false,
      });
      await _saveSubtasks();
    }
    controller.dispose();
  }

  Future<void> _edit() async {
    final title = TextEditingController(text: widget.task.title),
        description = TextEditingController(text: widget.task.description);
    final save =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Edit task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
    if (save) {
      await TaskService.update(widget.task.id, {
        'title': title.text.trim(),
        'description': description.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    }
    title.dispose();
    description.dispose();
  }

  Future<void> _delete() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete task?'),
            content: const Text('This action permanently deletes the task.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await TaskService.delete(widget.task.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return Scaffold(
      appBar: AppBar(
        title: Text(task.id),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            task.project,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<TaskStatus>(
            initialValue: task.status,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.sync_alt),
            ),
            items: TaskStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (status) {
              if (status == null) return;
              widget.onStatusChanged(task, status);
              setState(() {});
            },
          ),
          const SizedBox(height: 20),
          _InfoTile(
            icon: Icons.flag_outlined,
            label: 'Priority',
            value: task.priority.label,
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Assignee',
            value: task.assignee,
          ),
          _InfoTile(
            icon: Icons.event_outlined,
            label: 'Deadline',
            value:
                '${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year}',
          ),
          const Divider(height: 32),
          const Text(
            'Description',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(task.description),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtasks',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: _addSubtask, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 8),
          if (task.subtasks.isEmpty)
            const Text('No subtasks added yet.')
          else
            ...task.subtasks.map(
              (subtask) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: subtask['completed'] == true,
                onChanged: (value) {
                  subtask['completed'] = value == true;
                  _saveSubtasks();
                },
                title: Text(subtask['title'] ?? ''),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    widget.task.subtasks.remove(subtask);
                    _saveSubtasks();
                  },
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Collaboration',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._comments.map(
            (c) => Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  c['author'] is Map
                      ? '${c['author']['firstName'] ?? ''} ${c['author']['lastName'] ?? ''}'
                      : 'User',
                ),
                subtitle: Text(c['body'] ?? ''),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _comment,
                  decoration: const InputDecoration(hintText: 'Add a comment'),
                ),
              ),
              IconButton(onPressed: _addComment, icon: const Icon(Icons.send)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attachments',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _uploadAttachment,
                icon: const Icon(Icons.upload_file),
              ),
            ],
          ),
          if (task.attachments.isEmpty)
            const Text('No files attached.')
          else
            ...task.attachments.map(
              (attachment) => Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(attachment['name'] ?? 'Attachment'),
                  subtitle: Text(
                    '${((attachment['size'] ?? 0) / 1024).toStringAsFixed(1)} KB',
                  ),
                  onTap: () => _openAttachment(attachment),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteAttachment(attachment),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _archive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive task'),
          ),
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete task'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
