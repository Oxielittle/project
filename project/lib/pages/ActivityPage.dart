import 'package:flutter/material.dart';

import '../services/api_client.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await ApiClient.get('/activity');
      if (mounted)
        setState(() {
          items = data['items'] ?? [];
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity history')),
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
        : items.isEmpty
        ? const Center(child: Text('No activity recorded yet.'))
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, index) {
                final item = items[index], actor = item['actor'];
                final actorName = actor is Map
                    ? '${actor['firstName'] ?? ''} ${actor['lastName'] ?? ''}'
                          .trim()
                    : 'System user';
                final date = DateTime.tryParse(item['createdAt'] ?? '')
                    ?.toLocal();
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history)),
                  title: Text(
                    (item['action'] ?? 'ACTIVITY').toString().replaceAll(
                      '_',
                      ' ',
                    ),
                  ),
                  subtitle: Text('$actorName • ${item['entityType'] ?? ''}'),
                  trailing: Text(
                    date == null
                        ? ''
                        : '${date.month}/${date.day}/${date.year}',
                  ),
                );
              },
            ),
          ),
  );
}
