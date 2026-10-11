import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../services/task_service.dart';
import 'TaskDetailsPage.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({super.key, required this.project});
  final Map<String, dynamic> project;
  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  List<TaskItem> tasks = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final items = await TaskService.forProject(widget.project['_id']);
      if (mounted)
        setState(() {
          tasks = items;
          loading = false;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = e.toString();
        });
    }
  }

  Future<void> change(TaskItem task, TaskStatus status) async {
    await TaskService.updateStatus(task, status);
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.project['name'] ?? 'Project')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                FilledButton(onPressed: load, child: const Text('Retry')),
              ],
            ),
          )
        : DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Kanban'),
                  ],
                ),
                Expanded(child: TabBarView(children: [_overview(), _kanban()])),
              ],
            ),
          ),
  );
  Widget _overview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        widget.project['description'] ?? '',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          title: const Text('Status'),
          trailing: Text(widget.project['status'] ?? 'planning'),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('Tasks'),
          trailing: Text('${tasks.length}'),
        ),
      ),
      ...tasks.map(
        (task) => Card(
          child: ListTile(
            title: Text(task.title),
            subtitle: Text('${task.status.label} • ${task.assignee}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetailsPage(
                    task: task,
                    onStatusChanged: (t, s) => change(t, s),
                  ),
                ),
              );
              load();
            },
          ),
        ),
      ),
    ],
  );
  Widget _kanban() => ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.all(12),
    children: TaskStatus.values
        .map(
          (status) => Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      CircleAvatar(
                        radius: 13,
                        child: Text(
                          '${tasks.where((t) => t.status == status).length}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: tasks
                        .where((t) => t.status == status)
                        .map(
                          (task) => Card(
                            child: ListTile(
                              title: Text(task.title),
                              subtitle: Text(task.assignee),
                              onTap: () => _move(task),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
  Future<void> _move(TaskItem task) async {
    final status = await showModalBottomSheet<TaskStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskStatus.values
              .map(
                (s) => ListTile(
                  title: Text('Move to ${s.label}'),
                  onTap: () => Navigator.pop(context, s),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (status != null) await change(task, status);
  }
}
