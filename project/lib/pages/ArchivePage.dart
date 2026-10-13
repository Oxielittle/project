import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});
  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  List<dynamic> projects = [];
  List<TaskItem> tasks = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final role = await SessionService.role();
      final results = await Future.wait([
        if (role != 'member')
          ApiClient.get('/projects?archived=true')
        else
          Future.value({'items': []}),
        ApiClient.get('/tasks?archived=true'),
      ]);
      if (mounted)
        setState(() {
          projects = results[0]['items'] ?? [];
          tasks = (results[1]['items'] as List? ?? [])
              .map((e) => TaskItem.fromJson(e))
              .toList();
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

  Future<void> restore(String type, String id) async {
    if (type == 'personal-tasks') {
      await ApiClient.patch('/personal-tasks/$id/archive', {'archived': false});
    } else {
      await ApiClient.patch('/$type/$id', {'isArchived': false});
    }
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Archived records'),
      bottom: TabBar(
        controller: tabs,
        tabs: const [
          Tab(text: 'Projects'),
          Tab(text: 'Tasks'),
        ],
      ),
    ),
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
        : TabBarView(
            controller: tabs,
            children: [
              _list(
                projects
                    .map(
                      (p) => (
                        p['_id'].toString(),
                        p['name'].toString(),
                        'projects',
                      ),
                    )
                    .toList(),
              ),
              _list(
                tasks
                    .map(
                      (t) => (
                        t.id,
                        t.title,
                        t.isPersonal ? 'personal-tasks' : 'tasks',
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
  );
  Widget _list(List<(String, String, String)> records) => records.isEmpty
      ? const Center(child: Text('No archived records.'))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (_, i) {
            final record = records[i];
            return Card(
              child: ListTile(
                title: Text(record.$2),
                trailing: TextButton.icon(
                  onPressed: () => restore(record.$3, record.$1),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore'),
                ),
              ),
            );
          },
        );
}
