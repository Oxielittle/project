import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({
    super.key,
    required this.onCreate,
    this.initialProjects,
    this.initialUsers,
  });
  final ValueChanged<TaskItem> onCreate;
  final List<Map<String, dynamic>>? initialProjects, initialUsers;

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _allowedTypes = TextEditingController(
    text: 'pdf, doc, docx, jpg, jpeg, png',
  );
  final _recipientSearch = TextEditingController();
  List<Map<String, dynamic>> _projects = [], _users = [];
  final Set<String> _recipients = {};
  final List<PlatformFile> _referenceFiles = [];
  String? _projectId, _assigneeId;
  bool _loading = true, _saving = false, _isActivity = false;
  bool _allowText = true, _requireAttachment = false, _allowResubmission = true;
  int _maxSubmissions = 3, _maxFileSize = 10, _maximumScore = 100;
  TaskPriority _priority = TaskPriority.medium;
  TaskStatus _status = TaskStatus.todo;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialProjects != null && widget.initialUsers != null) {
      _projects = widget.initialProjects!;
      _users = widget.initialUsers!;
      _loading = false;
    } else {
      _loadOptions();
    }
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
    _allowedTypes.dispose();
    _recipientSearch.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedProject {
    for (final project in _projects) {
      if (project['_id'].toString() == _projectId) return project;
    }
    return null;
  }

  List<Map<String, dynamic>> get _eligibleUsers {
    final project = _selectedProject;
    if (project == null) return const [];
    final members = (project['members'] as List? ?? const [])
        .map(
          (value) => value is Map ? value['_id'].toString() : value.toString(),
        )
        .toSet();
    final query = _recipientSearch.text.trim().toLowerCase();
    return _users.where((user) {
      final name =
          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''} ${user['email'] ?? ''}'
              .toLowerCase();
      return members.contains(user['_id'].toString()) &&
          (query.isEmpty || name.contains(query));
    }).toList();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _startDate : _dueDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null)
      setState(() {
        if (start) {
          _startDate = date;
        } else {
          _dueDate = date;
        }
      });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) return _message('Select a project.');
    if (_isActivity && _recipients.isEmpty)
      return _message('Select at least one recipient.');
    if (_isActivity && !_allowText && !_requireAttachment)
      return _message('Enable a text response or require an attachment.');
    if (_dueDate.isBefore(_startDate))
      return _message('Deadline must be after the start date.');
    setState(() => _saving = true);
    try {
      final common = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'project': _projectId,
        'priority': _priority.name,
        'deadline': _dueDate.toIso8601String(),
      };
      final task = _isActivity
          ? await TaskService.createActivity({
              ...common,
              'recipients': _recipients.toList(),
              'startDate': _startDate.toIso8601String(),
              'activitySettings': {
                'allowTextResponse': _allowText,
                'requireAttachment': _requireAttachment,
                'allowResubmission': _allowResubmission,
                'maxSubmissions': _maxSubmissions,
                'maxFileSizeMB': _maxFileSize,
                'maximumScore': _maximumScore,
                'allowedFileTypes': _allowedTypes.text
                    .split(',')
                    .map((v) => v.trim().replaceFirst('.', '').toLowerCase())
                    .where((v) => v.isNotEmpty)
                    .toList(),
              },
            })
          : await TaskService.create({
              ...common,
              'assignee': _assigneeId,
              'status': _status.api,
            });
      if (_isActivity) {
        var failedUploads = 0;
        for (final file in _referenceFiles) {
          if (file.bytes == null) continue;
          try {
            final data = await ApiClient.upload(
              '/tasks/${task.id}/attachments',
              file.bytes!,
              file.name,
            );
            task.attachments.add(Map<String, dynamic>.from(data['item']));
          } catch (_) {
            failedUploads++;
          }
        }
        if (failedUploads > 0 && mounted) {
          _message(
            'Activity created, but $failedUploads reference file(s) failed to upload.',
          );
        }
      }
      widget.onCreate(task);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(error.toString());
      }
    }
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  String _name(Map<String, dynamic> user) =>
      '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isActivity ? 'Create individual activity' : 'Create task'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            key: const Key('task-type-selector'),
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.task_alt),
                label: Text('Standard task'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.assignment_ind_outlined),
                label: Text('Individual activity'),
              ),
            ],
            selected: {_isActivity},
            onSelectionChanged: (value) =>
                setState(() => _isActivity = value.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _title,
            decoration: InputDecoration(
              labelText: _isActivity ? 'Activity title *' : 'Task title *',
              prefixIcon: const Icon(Icons.title),
            ),
            validator: _required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Instructions / description *',
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
              onChanged: (value) => setState(() {
                _projectId = value;
                _assigneeId = null;
                _recipients.clear();
              }),
            ),
          const SizedBox(height: 16),
          if (_isActivity)
            _recipientPicker()
          else
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
                      child: Text(_name(u)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _assigneeId = value),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: TaskPriority.values
                .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                .toList(),
            onChanged: (v) => setState(() => _priority = v!),
          ),
          if (!_isActivity) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.sync_alt),
              ),
              items: TaskStatus.values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
          ],
          const SizedBox(height: 16),
          if (_isActivity) ...[
            _dateTile('Start date', _startDate, () => _pickDate(true)),
            const SizedBox(height: 12),
          ],
          _dateTile('Deadline', _dueDate, () => _pickDate(false)),
          if (_isActivity) ...[
            const SizedBox(height: 20),
            _settings(),
            const SizedBox(height: 16),
            _referencePicker(),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isActivity ? Icons.campaign_outlined : Icons.add_task),
            label: Text(
              _isActivity
                  ? 'Create for ${_recipients.length} recipient(s)'
                  : 'Create task',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _recipientPicker() {
    final users = _eligibleUsers;
    return Card(
      key: const Key('recipient-picker'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recipients *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${_recipients.length} selected'),
                TextButton(
                  onPressed: users.isEmpty
                      ? null
                      : () => setState(() {
                          final ids = users
                              .map((u) => u['_id'].toString())
                              .toSet();
                          if (ids.every(_recipients.contains)) {
                            _recipients.removeAll(ids);
                          } else {
                            _recipients.addAll(ids);
                          }
                        }),
                  child: const Text('Select all'),
                ),
              ],
            ),
            TextField(
              controller: _recipientSearch,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search project members',
              ),
            ),
            const SizedBox(height: 8),
            if (_projectId == null)
              const Text('Select a project first.')
            else if (users.isEmpty)
              const Text('No matching project members.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: ListView(
                  shrinkWrap: true,
                  children: users.map((user) {
                    final userId = user['_id'].toString();
                    return CheckboxListTile(
                      value: _recipients.contains(userId),
                      title: Text(_name(user)),
                      subtitle: Text(user['email'] ?? ''),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _recipients.add(userId);
                        } else {
                          _recipients.remove(userId);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _settings() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submission settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow text response'),
            value: _allowText,
            onChanged: (v) => setState(() => _allowText = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require attachment'),
            value: _requireAttachment,
            onChanged: (v) => setState(() => _requireAttachment = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow resubmission'),
            value: _allowResubmission,
            onChanged: (v) => setState(() => _allowResubmission = v),
          ),
          TextFormField(
            initialValue: '3',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum submissions'),
            onChanged: (v) => _maxSubmissions = int.tryParse(v) ?? 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '10',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maximum file size (MB)',
            ),
            onChanged: (v) => _maxFileSize = int.tryParse(v) ?? 10,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '100',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum score'),
            onChanged: (v) => _maximumScore = int.tryParse(v) ?? 100,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _allowedTypes,
            decoration: const InputDecoration(
              labelText: 'Allowed file extensions',
              helperText:
                  'Comma-separated. Leave blank to allow any safe file.',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _referencePicker() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reference files',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text('Optional instructions, examples, or templates.'),
          ..._referenceFiles.map(
            (file) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(file.name),
              trailing: IconButton(
                onPressed: () => setState(() => _referenceFiles.remove(file)),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                withData: true,
                allowMultiple: true,
              );
              if (result != null && mounted) {
                setState(
                  () => _referenceFiles.addAll(
                    result.files.where((file) => file.bytes != null),
                  ),
                );
              }
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose reference files'),
          ),
        ],
      ),
    ),
  );

  Widget _dateTile(String title, DateTime date, VoidCallback onTap) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(8),
    ),
    leading: const Icon(Icons.event_outlined),
    title: Text(title),
    subtitle: Text('${date.month}/${date.day}/${date.year}'),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: onTap,
  );
  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}
