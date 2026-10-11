import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../services/task_service.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key, required this.onCreate});

  final ValueChanged<TaskItem> onCreate;

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  List<Map<String, dynamic>> _projects = [], _users = [];
  String? _projectId, _assigneeId;
  bool _loading = true, _saving = false;
  TaskPriority _priority = TaskPriority.medium;
  TaskStatus _status = TaskStatus.todo;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        TaskService.projects(),
        TaskService.users(),
      ]);
      if (mounted)
        setState(() {
          _projects = results[0];
          _users = results[1];
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a project.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final task = await TaskService.create({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'project': _projectId,
        'assignee': _assigneeId,
        'priority': _priority.name,
        'status': _status.api,
        'deadline': _dueDate.toIso8601String(),
      });
      widget.onCreate(task);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Task title *',
                prefixIcon: Icon(Icons.title),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description *',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                decoration: const InputDecoration(
                  labelText: 'Project *',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: _projects
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['_id'].toString(),
                        child: Text(p['name'] ?? 'Project'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _projectId = v),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(
                labelText: 'Assignee',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: _users
                  .map(
                    (u) => DropdownMenuItem(
                      value: u['_id'].toString(),
                      child: Text(
                        '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _assigneeId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: TaskPriority.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _priority = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.sync_alt),
              ),
              items: TaskStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.event_outlined),
              title: const Text('Deadline'),
              subtitle: Text(
                '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _selectDueDate,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task),
              label: const Text('Create task'),
            ),
          ],
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}
