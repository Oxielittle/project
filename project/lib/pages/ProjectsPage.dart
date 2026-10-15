import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../services/api_client.dart';
import 'ProjectDetailsPage.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key, required this.tasks, required this.canManage});
  final List<TaskItem> tasks;
  final bool canManage;
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<dynamic> projects = [];
  List<dynamic> teams = [];
  List<dynamic> users = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/projects'),
        if (widget.canManage) ApiClient.get('/users'),
        if (widget.canManage) ApiClient.get('/teams'),
      ]);
      final data = results.first;
      if (mounted)
        setState(() {
          projects = data['items'];
          users = widget.canManage ? results[1]['items'] ?? [] : [];
          teams = widget.canManage ? results[2]['items'] ?? [] : [];
          loading = false;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  Future<void> showForm([Map<String, dynamic>? project]) async {
    final name = TextEditingController(text: project?['name'] ?? '');
    final description = TextEditingController(
      text: project?['description'] ?? '',
    );
    final selectedMembers = <String>{
      ...(project?['members'] as List? ?? []).map(
        (member) =>
            member is Map ? member['_id'].toString() : member.toString(),
      ),
    };
    final teamValue = project?['team'];
    String? selectedTeamId = teamValue is Map
        ? teamValue['_id']?.toString()
        : teamValue?.toString();
    final save =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(project == null ? 'Create project' : 'Edit project'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Project name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedTeamId,
                    decoration: const InputDecoration(
                      labelText: 'Team (optional)',
                      helperText: 'Selecting a team adds all of its members.',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Select members manually'),
                      ),
                      ...teams.map(
                        (team) => DropdownMenuItem<String?>(
                          value: team['_id'].toString(),
                          child: Text(team['name'] ?? 'Team'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      selectedTeamId = value;
                      if (value == null) return;
                      final team = teams.firstWhere(
                        (item) => item['_id'].toString() == value,
                      );
                      selectedMembers
                        ..clear()
                        ..addAll(
                          (team['members'] as List? ?? const []).map(
                            (member) => member is Map
                                ? member['_id'].toString()
                                : member.toString(),
                          ),
                        );
                      final manager = team['manager'];
                      if (manager != null) {
                        selectedMembers.add(
                          manager is Map
                              ? manager['_id'].toString()
                              : manager.toString(),
                        );
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Project members',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 420,
                    child: Wrap(
                      spacing: 6,
                      children: users.map((user) {
                        final id = user['_id'].toString();
                        return FilterChip(
                          label: Text(
                            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                .trim(),
                          ),
                          selected: selectedMembers.contains(id),
                          onSelected: selectedTeamId != null
                              ? null
                              : (selected) => setDialogState(
                                  () => selected
                                      ? selectedMembers.add(id)
                                      : selectedMembers.remove(id),
                                ),
                        );
                      }).toList(),
                    ),
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
    if (save && name.text.trim().isNotEmpty) {
      final body = {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'status': 'active',
        'members': selectedMembers.toList(),
        'team': selectedTeamId,
      };
      if (project == null) {
        await ApiClient.post('/projects', body);
      } else {
        await ApiClient.patch('/projects/${project['_id']}', body);
      }
      await load();
    }
    name.dispose();
    description.dispose();
  }

  Future<void> archive(Map<String, dynamic> project) async {
    await ApiClient.patch('/projects/${project['_id']}', {'isArchived': true});
    await load();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(child: Text(error!));
    } else if (projects.isEmpty) {
      body = const Center(child: Text('No projects yet.'));
    } else {
      body = RefreshIndicator(
        onRefresh: load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final project = Map<String, dynamic>.from(projects[index]);
            final tasks = widget.tasks
                .where((task) => task.projectId == project['_id'])
                .toList();
            final completed = tasks
                .where((task) => task.status == TaskStatus.completed)
                .length;
            final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            project['name'] ?? 'Project',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProjectDetailsPage(project: project),
                            ),
                          ),
                          child: const Text('Open'),
                        ),
                        if (widget.canManage)
                          PopupMenuButton<String>(
                            onSelected: (value) => value == 'edit'
                                ? showForm(project)
                                : archive(project),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if ((project['description'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(project['description']),
                      ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text('$completed of ${tasks.length} tasks completed'),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: body,
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: () => showForm(),
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            )
          : null,
    );
  }
}
