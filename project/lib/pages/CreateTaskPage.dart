import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';

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
  final _tags = TextEditingController();
  final _category = TextEditingController();
  final _subtask = TextEditingController();
  List<Map<String, dynamic>> _projects = [], _users = [];
  List<TaskItem> _tasks = [];
  final Set<String> _recipients = {};
  final Set<String> _collaborators = {}, _watchers = {}, _dependencies = {};
  final List<String> _subtasks = [];
  final List<PlatformFile> _referenceFiles = [];
  String? _projectId, _assigneeId;
  bool _loading = true, _saving = false, _isActivity = false;
  bool _isPersonal = true;
  String _role = 'admin';
  bool _allowText = true, _requireAttachment = false, _allowResubmission = true;
  int _maxSubmissions = 3, _maxFileSize = 10, _maximumScore = 100;
  TaskPriority _priority = TaskPriority.medium;
  TaskStatus _status = TaskStatus.todo;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  DateTime _startDate = DateTime.now();
  DateTime? _reminderAt;
  String _recurrence = 'none';
  int _recurrenceInterval = 1, _recurrenceCount = 2;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final role = await SessionService.role();
      if (widget.initialProjects != null && widget.initialUsers != null) {
        if (mounted)
          setState(() {
            _role = role;
            _isPersonal = _role == 'member';
            _projects = widget.initialProjects!;
            _users = widget.initialUsers!;
            _loading = false;
          });
        return;
      }
      final tasks = await TaskService.list();
      final projects = role == 'member'
          ? <Map<String, dynamic>>[]
          : await TaskService.projects();
      final users = role == 'member'
          ? <Map<String, dynamic>>[]
          : await TaskService.users();
      if (mounted)
        setState(() {
          _role = role;
          _isPersonal = _role == 'member';
          _projects = projects;
          _users = users;
          _tasks = tasks;
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
    _tags.dispose();
    _category.dispose();
    _subtask.dispose();
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
    final manager = project['manager'];
    if (manager != null)
      members.add(
        manager is Map ? manager['_id'].toString() : manager.toString(),
      );
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

  Future<void> _pickReminder() async {
    final initial = _reminderAt ?? _dueDate.subtract(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: _dueDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (value.isAfter(_dueDate))
      return _message('Reminder cannot be after the deadline.');
    setState(() => _reminderAt = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPersonal && _projectId == null)
      return _message('Select a project.');
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
        if (!_isPersonal) 'project': _projectId,
        'priority': _priority.name,
        'startDate': _startDate.toIso8601String(),
        'deadline': _dueDate.toIso8601String(),
      };
      final task = _isPersonal
          ? await TaskService.createPersonal({
              ...common,
              'reminderAt': _reminderAt?.toIso8601String(),
              'subtasks': _subtasks
                  .map((title) => {'title': title, 'completed': false})
                  .toList(),
              'tags': _tags.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(),
              'category': _category.text.trim(),
              'recurrence': {
                'frequency': _recurrence,
                'interval': _recurrenceInterval,
                'count': _recurrenceCount,
              },
              'status': _status.api,
            })
          : _isActivity
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
              'collaborators': _collaborators.toList(),
              'watchers': _watchers.toList(),
              'subtasks': _subtasks
                  .map((title) => {'title': title, 'completed': false})
                  .toList(),
              'tags': _tags.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(),
              'category': _category.text.trim(),
              'dependencies': _dependencies.toList(),
              'recurrence': {
                'frequency': _recurrence,
                'interval': _recurrenceInterval,
                'count': _recurrenceCount,
              },
              'status': _status.api,
            });
      if (_referenceFiles.isNotEmpty) {
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
            '${_isActivity ? 'Activity' : 'Task'} created, but $failedUploads file(s) failed to upload.',
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
      title: Text(
        _isPersonal
            ? 'Create personal task'
            : _isActivity
            ? 'Create individual activity'
            : 'Create project task',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              key: const Key('task-type-selector'),
              segments: [
                const ButtonSegment(
                  value: 'personal',
                  icon: Icon(Icons.person_pin_circle_outlined),
                  label: Text('Personal task'),
                ),
                if (_role != 'member')
                  const ButtonSegment(
                    value: 'project',
                    icon: Icon(Icons.task_alt),
                    label: Text('Project task'),
                  ),
                if (_role != 'member')
                  const ButtonSegment(
                    value: 'activity',
                    icon: Icon(Icons.assignment_ind_outlined),
                    label: Text('Individual activity'),
                  ),
              ],
              selected: {
                _isPersonal
                    ? 'personal'
                    : _isActivity
                    ? 'activity'
                    : 'project',
              },
              onSelectionChanged: (value) => setState(() {
                _isPersonal = value.first == 'personal';
                _isActivity = value.first == 'activity';
              }),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _title,
            decoration: InputDecoration(
              labelText: _isActivity
                  ? 'Activity title *'
                  : _isPersonal
                  ? 'Personal task title *'
                  : 'Task title *',
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
          if (!_isPersonal && _loading)
            const LinearProgressIndicator()
          else if (!_isPersonal)
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
                _dependencies.clear();
              }),
            ),
          const SizedBox(height: 16),
          if (_isPersonal)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline),
              title: Text('Private personal task'),
              subtitle: Text('Only you can view and manage this task.'),
            )
          else if (_isActivity)
            _recipientPicker()
          else
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(
                labelText: 'Assignee',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: _eligibleUsers
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
          _dateTile('Start date', _startDate, () => _pickDate(true)),
          const SizedBox(height: 12),
          _dateTile('Deadline', _dueDate, () => _pickDate(false)),
          if (_isPersonal) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Reminder'),
              subtitle: Text(
                _reminderAt == null
                    ? 'No reminder'
                    : '${_reminderAt!.month}/${_reminderAt!.day}/${_reminderAt!.year}',
              ),
              trailing: Wrap(
                children: [
                  if (_reminderAt != null)
                    IconButton(
                      onPressed: () => setState(() => _reminderAt = null),
                      icon: const Icon(Icons.close),
                    ),
                  IconButton(
                    onPressed: _pickReminder,
                    icon: const Icon(Icons.edit_calendar),
                  ),
                ],
              ),
            ),
          ],
          if (_isActivity) ...[
            const SizedBox(height: 20),
            _settings(),
          ] else ...[
            const SizedBox(height: 20),
            _standardSettings(personal: _isPersonal),
          ],
          const SizedBox(height: 16),
          _referencePicker(),
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
                  : _isPersonal
                  ? 'Create personal task'
                  : 'Create project task',
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

  Widget _standardSettings({bool personal = false}) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Task options',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Tags',
              helperText: 'Comma-separated',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
          ),
          const SizedBox(height: 12),
          if (!personal) ...[
            _multiSelectTile('Collaborators', _collaborators, _eligibleUsers),
            _multiSelectTile('Watchers', _watchers, _eligibleUsers),
          ],
          const Divider(height: 28),
          const Text('Subtasks', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._subtasks.map(
            (title) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              leading: const Icon(Icons.check_box_outline_blank),
              trailing: IconButton(
                onPressed: () => setState(() => _subtasks.remove(title)),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtask,
                  decoration: const InputDecoration(hintText: 'Add a subtask'),
                ),
              ),
              IconButton(
                onPressed: () {
                  final value = _subtask.text.trim();
                  if (value.isNotEmpty)
                    setState(() {
                      _subtasks.add(value);
                      _subtask.clear();
                    });
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (!personal) ...[
            const Divider(height: 28),
            const Text(
              'Dependencies',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_tasks
                .where(
                  (task) =>
                      task.projectId == _projectId &&
                      !task.isIndividualActivity,
                )
                .isEmpty)
              const Text('No existing Standard Tasks in this project.'),
            ..._tasks
                .where(
                  (task) =>
                      task.projectId == _projectId &&
                      !task.isIndividualActivity,
                )
                .map(
                  (task) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _dependencies.contains(task.id),
                    title: Text(task.title),
                    subtitle: Text(task.status.label),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _dependencies.add(task.id);
                      } else {
                        _dependencies.remove(task.id);
                      }
                    }),
                  ),
                ),
          ],
          const Divider(height: 28),
          DropdownButtonFormField<String>(
            initialValue: _recurrence,
            decoration: const InputDecoration(
              labelText: 'Repeat',
              prefixIcon: Icon(Icons.repeat),
            ),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (value) => setState(() => _recurrence = value!),
          ),
          if (_recurrence != 'none') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repeat every',
                    ),
                    onChanged: (value) =>
                        _recurrenceInterval = int.tryParse(value) ?? 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: '2',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Occurrences'),
                    onChanged: (value) =>
                        _recurrenceCount = int.tryParse(value) ?? 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _multiSelectTile(
    String title,
    Set<String> selected,
    List<Map<String, dynamic>> users,
  ) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text('${selected.length} selected'),
    children: users.map((user) {
      final id = user['_id'].toString();
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: selected.contains(id),
        title: Text(_name(user)),
        onChanged: (value) => setState(() {
          if (value == true) {
            selected.add(id);
          } else {
            selected.remove(id);
          }
        }),
      );
    }).toList(),
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
