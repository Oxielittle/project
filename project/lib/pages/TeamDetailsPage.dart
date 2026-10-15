import 'package:flutter/material.dart';

import '../services/api_client.dart';

class TeamDetailsPage extends StatefulWidget {
  const TeamDetailsPage({super.key, required this.team});

  final Map<String, dynamic> team;

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await ApiClient.get('/teams/${widget.team['_id']}/overview');
      if (!mounted) return;
      setState(() {
        data = Map<String, dynamic>.from(value);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  String name(dynamic user) => user is Map
      ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
      : 'Member';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.team['name'] ?? 'Team')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: load, child: const Text('Retry')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  data?['item']?['description'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                _summary(),
                const SizedBox(height: 20),
                Text('Members', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _memberTile(data?['item']?['manager'], manager: true),
                ...(data?['item']?['members'] as List? ?? const []).map(
                  (member) => _memberTile(member),
                ),
                const SizedBox(height: 20),
                Text('Projects', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if ((data?['projects'] as List? ?? const []).isEmpty)
                  const Text('No projects are linked to this team yet.')
                else
                  ...(data?['projects'] as List).map(
                    (project) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(project['name'] ?? 'Project'),
                        subtitle: Text(project['status'] ?? 'planning'),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if ((data?['tasks'] as List? ?? const []).isEmpty)
                  const Text('No tasks are assigned to this team yet.')
                else
                  ...(data?['tasks'] as List).map(
                    (task) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.task_alt_outlined),
                        title: Text(task['title'] ?? 'Task'),
                        subtitle: Text(
                          '${task['project']?['name'] ?? 'Project'} - ${task['status'] ?? 'todo'}',
                        ),
                        trailing: Text(task['priority'] ?? 'medium'),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Workload', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if ((data?['workload'] as List? ?? const []).isEmpty)
                  const Text('No member workload is available yet.')
                else
                  ...(data?['workload'] as List).map(
                    (entry) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(name(entry['user'])),
                        subtitle: Text(
                          '${entry['completed'] ?? 0} completed of ${entry['assigned'] ?? 0} assigned',
                        ),
                        trailing: Text('${entry['assigned'] ?? 0}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _summary() {
    final summary = Map<String, dynamic>.from(data?['summary'] ?? const {});
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _metric('Projects', summary['projects'] ?? 0),
                _metric('Tasks', summary['tasks'] ?? 0),
                _metric('Completed', summary['completed'] ?? 0),
                _metric('Overdue', summary['overdue'] ?? 0),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: ((summary['progress'] ?? 0) as num) / 100,
            ),
            const SizedBox(height: 6),
            Text('${summary['progress'] ?? 0}% team progress'),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, dynamic value) => Expanded(
    child: Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _memberTile(dynamic user, {bool manager = false}) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Text(name(user).isEmpty ? '?' : name(user)[0])),
      title: Text(name(user)),
      subtitle: Text(manager ? 'Team manager' : 'Team member'),
    ),
  );
}
