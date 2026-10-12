import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/activity_assignment.dart';
import '../models/task_item.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/session_service.dart';
import '../services/task_service.dart';

class ActivityDetailsPage extends StatefulWidget {
  const ActivityDetailsPage({
    super.key,
    required this.task,
    this.initialAssignment,
    this.initialAssignments,
    this.initialCounts,
    this.initialReviewerView,
  });
  final TaskItem task;
  final ActivityAssignment? initialAssignment;
  final List<ActivityAssignment>? initialAssignments;
  final Map<String, dynamic>? initialCounts;
  final bool? initialReviewerView;

  @override
  State<ActivityDetailsPage> createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  final _response = TextEditingController();
  final _reviewSearch = TextEditingController();
  bool _loading = true, _busy = false, _reviewerView = false;
  String? _error, _statusFilter;
  String _sort = 'name';
  ActivityAssignment? _mine;
  List<ActivityAssignment> _assignments = [];
  Map<String, dynamic> _counts = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialReviewerView != null) {
      _reviewerView = widget.initialReviewerView!;
      _mine = widget.initialAssignment;
      _assignments = widget.initialAssignments ?? [];
      _counts = widget.initialCounts ?? {};
      _response.text = _mine?.textResponse ?? '';
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await SessionService.user();
      final mayReview =
          user?['role'] == 'admin' ||
          user?['role'] == 'manager' ||
          user?['_id']?.toString() == widget.task.reporterId ||
          user?['id']?.toString() == widget.task.reporterId;
      if (mayReview) {
        try {
          final data = await TaskService.activityAssignments(
            widget.task.id,
            status: _statusFilter,
          );
          _reviewerView = true;
          _assignments = (data['items'] as List? ?? const [])
              .map(
                (value) => ActivityAssignment.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList();
          _counts = Map<String, dynamic>.from(data['counts'] ?? const {});
        } catch (_) {
          _reviewerView = false;
          _mine = await TaskService.myActivityAssignment(widget.task.id);
          _response.text = _mine!.textResponse;
        }
      } else {
        _mine = await TaskService.myActivityAssignment(widget.task.id);
        _response.text = _mine!.textResponse;
      }
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _response.dispose();
    _reviewSearch.dispose();
    super.dispose();
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  Future<void> _perform(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) _message(error.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _start() => _perform(() async {
    _mine = await TaskService.startAssignment(_mine!.id);
  });
  Future<void> _submit() => _perform(() async {
    _mine = await TaskService.submitAssignment(
      _mine!.id,
      _response.text.trim(),
    );
  });

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    await _perform(() async {
      await ApiClient.upload(
        '/activity-assignments/${_mine!.id}/attachments',
        file.bytes!,
        file.name,
      );
    });
  }

  Future<void> _uploadReference() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    await _perform(() async {
      final data = await ApiClient.upload(
        '/tasks/${widget.task.id}/attachments',
        file.bytes!,
        file.name,
      );
      widget.task.attachments.add(Map<String, dynamic>.from(data['item']));
    });
  }

  Future<void> _deleteReference(Map<String, dynamic> attachment) =>
      _perform(() async {
        await ApiClient.delete(
          '/tasks/${widget.task.id}/attachments/${attachment['_id']}',
        );
        widget.task.attachments.remove(attachment);
      });

  Future<void> _deleteAttachment(Map<String, dynamic> attachment) =>
      _perform(() async {
        await ApiClient.delete(
          '/activity-assignments/${_mine!.id}/attachments/${attachment['_id']}',
        );
      });

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final root = ApiConfig.api.replaceFirst('/api', '');
    await launchUrl(
      Uri.parse('$root${attachment['url']}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _review(ActivityAssignment assignment, String status) async {
    final feedback = TextEditingController(text: assignment.feedback);
    final score = TextEditingController(
      text: assignment.score?.toString() ?? '',
    );
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              status == 'accepted' ? 'Accept submission' : 'Return submission',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: feedback,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Feedback'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: score,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Score (0-${assignment.maximumScore})',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(status == 'accepted' ? 'Accept' : 'Return'),
              ),
            ],
          ),
        ) ??
        false;
    if (approved)
      await _perform(() async {
        await TaskService.reviewAssignment(
          assignment.id,
          status: status,
          feedback: feedback.text.trim(),
          score: num.tryParse(score.text),
        );
      });
    feedback.dispose();
    score.dispose();
  }

  Future<void> _remind() => _perform(() async {
    _message(await TaskService.remindActivity(widget.task.id));
  });

  Future<void> _editActivity() async {
    final title = TextEditingController(text: widget.task.title);
    final description = TextEditingController(text: widget.task.description);
    final maxSubmissions = TextEditingController(
      text: '${widget.task.activitySettings['maxSubmissions'] ?? 3}',
    );
    final maxFileSize = TextEditingController(
      text: '${widget.task.activitySettings['maxFileSizeMB'] ?? 10}',
    );
    final maximumScore = TextEditingController(
      text: '${widget.task.activitySettings['maximumScore'] ?? 100}',
    );
    final allowedTypes = TextEditingController(
      text:
          (widget.task.activitySettings['allowedFileTypes'] as List? ??
                  const [])
              .join(', '),
    );
    var allowText = widget.task.activitySettings['allowTextResponse'] != false;
    var requireAttachment =
        widget.task.activitySettings['requireAttachment'] == true;
    var allowResubmission =
        widget.task.activitySettings['allowResubmission'] != false;
    var startDate = widget.task.startDate ?? DateTime.now();
    var priority = widget.task.priority;
    var deadline = widget.task.dueDate;
    final save =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Edit activity'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start date'),
                      subtitle: Text(_date(startDate)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (value != null) {
                          setDialogState(() => startDate = value);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Deadline'),
                      subtitle: Text(_date(deadline)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: deadline,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (value != null)
                          setDialogState(() => deadline = value);
                      },
                    ),
                    DropdownButtonFormField<TaskPriority>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: TaskPriority.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow text response'),
                      value: allowText,
                      onChanged: (value) =>
                          setDialogState(() => allowText = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Require attachment'),
                      value: requireAttachment,
                      onChanged: (value) =>
                          setDialogState(() => requireAttachment = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow resubmission'),
                      value: allowResubmission,
                      onChanged: (value) =>
                          setDialogState(() => allowResubmission = value),
                    ),
                    TextField(
                      controller: maxSubmissions,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum submissions',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxFileSize,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum file size (MB)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maximumScore,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum score',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: allowedTypes,
                      decoration: const InputDecoration(
                        labelText: 'Allowed file types',
                        hintText: 'pdf, docx, jpg',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (save)
      await _perform(() async {
        final settings = {
          ...widget.task.activitySettings,
          'allowTextResponse': allowText,
          'requireAttachment': requireAttachment,
          'allowResubmission': allowResubmission,
          'maxSubmissions': int.tryParse(maxSubmissions.text) ?? 3,
          'maxFileSizeMB': int.tryParse(maxFileSize.text) ?? 10,
          'maximumScore': int.tryParse(maximumScore.text) ?? 100,
          'allowedFileTypes': allowedTypes.text
              .split(',')
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toList(),
        };
        final updated = await TaskService.updateActivity(widget.task.id, {
          'title': title.text.trim(),
          'description': description.text.trim(),
          'startDate': startDate.toIso8601String(),
          'deadline': deadline.toIso8601String(),
          'priority': priority.name,
          'activitySettings': settings,
        });
        widget.task.title = updated.title;
        widget.task.description = updated.description;
        widget.task.startDate = updated.startDate;
        widget.task.dueDate = updated.dueDate;
        widget.task.activitySettings = updated.activitySettings;
      });
    title.dispose();
    description.dispose();
    maxSubmissions.dispose();
    maxFileSize.dispose();
    maximumScore.dispose();
    allowedTypes.dispose();
  }

  Future<void> _addRecipients() async {
    final results = await Future.wait([
      TaskService.users(),
      TaskService.projects(),
    ]);
    final allUsers = results[0];
    final projects = results[1];
    final project = projects.cast<Map<String, dynamic>?>().firstWhere(
      (value) => value?['_id'].toString() == widget.task.projectId,
      orElse: () => null,
    );
    final memberIds = (project?['members'] as List? ?? const [])
        .map(
          (value) => value is Map ? value['_id'].toString() : value.toString(),
        )
        .toSet();
    final users = allUsers
        .where((user) => memberIds.contains(user['_id'].toString()))
        .toList();
    final existing = _assignments.map((item) => item.recipientId).toSet();
    final selected = <String>{};
    if (!mounted) return;
    final add =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Add recipients'),
              content: SizedBox(
                width: 420,
                child: ListView(
                  shrinkWrap: true,
                  children: users
                      .where(
                        (user) => !existing.contains(user['_id'].toString()),
                      )
                      .map((user) {
                        final id = user['_id'].toString();
                        return CheckboxListTile(
                          value: selected.contains(id),
                          title: Text(
                            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                .trim(),
                          ),
                          subtitle: Text(user['email'] ?? ''),
                          onChanged: (value) => setDialogState(() {
                            if (value == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        );
                      })
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (add)
      await _perform(
        () => TaskService.addActivityRecipients(
          widget.task.id,
          selected.toList(),
        ),
      );
  }

  Future<void> _removeRecipient(ActivityAssignment item) => _perform(
    () => TaskService.removeActivityRecipient(widget.task.id, item.recipientId),
  );

  Future<void> _reopen({ActivityAssignment? item}) async {
    final reason = TextEditingController();
    var deadline = widget.task.dueDate.isAfter(DateTime.now())
        ? widget.task.dueDate
        : DateTime.now().add(const Duration(days: 7));
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                item == null
                    ? 'Reopen closed assignments'
                    : 'Reopen ${item.recipient}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('New deadline'),
                    subtitle: Text(_date(deadline)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (date != null) setDialogState(() => deadline = date);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Reopen'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (confirmed)
      await _perform(() async {
        final count = await TaskService.reopenActivity(
          widget.task.id,
          assignmentIds: item == null ? null : [item.id],
          deadline: deadline,
          reason: reason.text.trim(),
        );
        widget.task.dueDate = deadline;
        _message('$count assignment(s) reopened.');
      });
    reason.dispose();
  }

  Future<void> _exportResults() async {
    try {
      final bytes = await ApiClient.download(
        '/activities/${widget.task.id}/export.csv',
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save activity results',
        fileName:
            '${widget.task.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}-results.csv',
        bytes: bytes,
      );
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<void> _archiveOrCancel(bool cancel) async {
    if (cancel) {
      final reason = TextEditingController();
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel activity?'),
              content: TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep activity'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Cancel activity'),
                ),
              ],
            ),
          ) ??
          false;
      if (confirmed)
        await _perform(
          () => TaskService.cancelActivity(widget.task.id, reason.text.trim()),
        );
      reason.dispose();
    } else
      await _perform(() => TaskService.archiveActivity(widget.task.id, true));
    if (mounted) Navigator.pop(context);
  }

  List<ActivityAssignment> get _visibleAssignments {
    final query = _reviewSearch.text.trim().toLowerCase();
    final values = _assignments
        .where((item) => item.recipient.toLowerCase().contains(query))
        .toList();
    values.sort((a, b) {
      if (_sort == 'status') return a.status.compareTo(b.status);
      if (_sort == 'submitted') {
        return (b.latestSubmittedAt ?? DateTime(1900)).compareTo(
          a.latestSubmittedAt ?? DateTime(1900),
        );
      }
      return a.recipient.compareTo(b.recipient);
    });
    return values;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Individual activity'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        if (_reviewerView)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editActivity();
              if (value == 'add') _addRecipients();
              if (value == 'reopen') _reopen();
              if (value == 'export') _exportResults();
              if (value == 'archive') _archiveOrCancel(false);
              if (value == 'cancel') _archiveOrCancel(true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit activity / deadline'),
              ),
              PopupMenuItem(value: 'add', child: Text('Add recipients')),
              PopupMenuItem(
                value: 'reopen',
                child: Text('Reopen closed assignments'),
              ),
              PopupMenuItem(value: 'export', child: Text('Export results CSV')),
              PopupMenuItem(value: 'archive', child: Text('Archive activity')),
              PopupMenuItem(value: 'cancel', child: Text('Cancel activity')),
            ],
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _errorState()
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _activityHeader(),
                const SizedBox(height: 16),
                if (_reviewerView) _reviewerBody() else _recipientBody(),
              ],
            ),
          ),
  );

  Widget _activityHeader() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_ind_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Chip(label: Text('INDIVIDUAL ACTIVITY')),
            ],
          ),
          Text(
            widget.task.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(widget.task.description),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.folder_outlined, size: 16),
                label: Text(widget.task.project),
              ),
              Chip(
                avatar: const Icon(Icons.event_outlined, size: 16),
                label: Text(_deadlineLabel()),
              ),
              if (widget.task.startDate != null)
                Chip(
                  avatar: const Icon(Icons.play_circle_outline, size: 16),
                  label: Text('Starts ${_date(widget.task.startDate!)}'),
                ),
              Chip(
                avatar: const Icon(Icons.flag_outlined, size: 16),
                label: Text(widget.task.priority.label),
              ),
              if (widget.task.reporter.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text('By ${widget.task.reporter}'),
                ),
            ],
          ),
          if (!_reviewerView && widget.task.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Reference files',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...widget.task.attachments.map(
              (file) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(file['name'] ?? 'Reference file'),
                onTap: () => _openAttachment(file),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _recipientBody() {
    final item = _mine!;
    final settings = widget.task.activitySettings;
    final canSubmit =
        [
          'assigned',
          'in-progress',
          'returned',
          'reopened',
        ].contains(item.status) ||
        (settings['allowResubmission'] == true &&
            [
              'submitted',
              'late',
              'accepted',
              'resubmitted',
            ].contains(item.status));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Your assignment', [
          Row(
            children: [
              const Text('Status'),
              const Spacer(),
              Chip(label: Text(_status(item.status))),
            ],
          ),
          if (item.isLate)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.schedule, color: Colors.orange),
              title: Text('Submitted late'),
            ),
          if (item.feedback.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Reviewer feedback'),
              subtitle: Text(item.feedback),
            ),
          if (item.score != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.grade_outlined),
              title: const Text('Score'),
              trailing: Text(
                '${item.score}/${item.maximumScore}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (item.status == 'assigned')
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start activity'),
            ),
        ]),
        const SizedBox(height: 12),
        if (settings['allowTextResponse'] != false)
          _section('Your response', [
            TextField(
              controller: _response,
              minLines: 5,
              maxLines: 10,
              enabled: canSubmit && !_busy,
              decoration: const InputDecoration(
                hintText: 'Write your individual response here…',
                alignLabelWithHint: true,
              ),
            ),
          ]),
        const SizedBox(height: 12),
        _section('Attachments', [
          if (item.attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No files uploaded yet.'),
            ),
          ...item.attachments.map(
            (attachment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(attachment['name'] ?? 'File'),
              onTap: () => _openAttachment(attachment),
              trailing: canSubmit
                  ? IconButton(
                      onPressed: _busy
                          ? null
                          : () => _deleteAttachment(attachment),
                      icon: const Icon(Icons.delete_outline),
                    )
                  : null,
            ),
          ),
          OutlinedButton.icon(
            onPressed: canSubmit && !_busy ? _upload : null,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload attachment'),
          ),
          if (settings['requireAttachment'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('At least one attachment is required.'),
            ),
        ]),
        const SizedBox(height: 12),
        if (canSubmit)
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.send),
            label: Text(
              item.submissionCount == 0
                  ? 'Submit activity'
                  : 'Resubmit activity',
            ),
          ),
        if (item.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section(
            'Submission history',
            item.history.reversed
                .map(
                  (attempt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${attempt['number']}')),
                    title: Text(
                      attempt['isLate'] == true
                          ? 'Late submission'
                          : 'Submitted',
                    ),
                    subtitle: Text(
                      _date(
                        DateTime.tryParse(attempt['submittedAt'] ?? '') ??
                            DateTime.now(),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _reviewerBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section('Submission overview', [
        Row(
          children: [
            Expanded(child: _metric('Recipients', _recipientTotal.toString())),
            const SizedBox(width: 8),
            Expanded(child: _metric('Submitted', '${_completionPercent()}%')),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'assigned',
                    'in-progress',
                    'submitted',
                    'late',
                    'returned',
                    'reopened',
                    'resubmitted',
                    'accepted',
                    'cancelled',
                  ]
                  .map(
                    (status) => ChoiceChip(
                      label: Text('${_status(status)} ${_counts[status] ?? 0}'),
                      selected: _statusFilter == status,
                      onSelected: (selected) {
                        setState(
                          () => _statusFilter = selected ? status : null,
                        );
                        _load();
                      },
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _remind,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Remind pending recipients'),
        ),
      ]),
      const SizedBox(height: 12),
      _section('Reference files', [
        if (widget.task.attachments.isEmpty)
          const Text('No reference files attached.'),
        ...widget.task.attachments.map(
          (file) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(file['name'] ?? 'Reference file'),
            onTap: () => _openAttachment(file),
            trailing: IconButton(
              onPressed: _busy ? null : () => _deleteReference(file),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _uploadReference,
          icon: const Icon(Icons.upload_file),
          label: const Text('Add reference file'),
        ),
      ]),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reviewSearch,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search recipients',
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sort,
            items: const [
              DropdownMenuItem(value: 'name', child: Text('Name')),
              DropdownMenuItem(value: 'status', child: Text('Status')),
              DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
            ],
            onChanged: (value) => setState(() => _sort = value!),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_visibleAssignments.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No assignments match this filter.')),
          ),
        )
      else
        ..._visibleAssignments.map(
          (item) => Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                child: Text(
                  item.recipient.isEmpty
                      ? '?'
                      : item.recipient[0].toUpperCase(),
                ),
              ),
              title: Text(item.recipient),
              subtitle: Text(
                '${_status(item.status)} • ${item.submissionCount} submission(s)',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (item.textResponse.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.textResponse),
                  ),
                ...item.attachments.map(
                  (attachment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text(attachment['name'] ?? 'File'),
                    onTap: () => _openAttachment(attachment),
                  ),
                ),
                if (item.feedback.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Feedback'),
                    subtitle: Text(item.feedback),
                  ),
                if (['submitted', 'late', 'resubmitted'].contains(item.status))
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _review(item, 'returned'),
                          icon: const Icon(Icons.undo),
                          label: const Text('Return'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _review(item, 'accepted'),
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                if (item.status == 'accepted' || item.status == 'cancelled')
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reopen(item: item),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Reopen assignment'),
                  ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _removeRecipient(item),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Remove recipient'),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );
  int get _recipientTotal =>
      _counts.values.fold<num>(0, (sum, value) => sum + (value as num)).toInt();
  int _completionPercent() {
    if (_recipientTotal == 0) return 0;
    final submitted = [
      'submitted',
      'late',
      'resubmitted',
      'accepted',
    ].fold<num>(0, (sum, key) => sum + ((_counts[key] ?? 0) as num));
    return (submitted * 100 / _recipientTotal).round();
  }

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .35),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    ),
  );
  String _deadlineLabel() {
    final difference = widget.task.dueDate.difference(DateTime.now()).inDays;
    if (difference < 0) return 'Overdue by ${difference.abs()} day(s)';
    if (difference == 0) return 'Due today';
    return 'Due in $difference day(s)';
  }

  String _date(DateTime value) => '${value.month}/${value.day}/${value.year}';
  String _status(String value) => value
      .split('-')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
