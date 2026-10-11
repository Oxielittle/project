import 'package:flutter/material.dart';

import '../services/api_client.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
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
      final d = await ApiClient.get('/notifications');
      if (mounted)
        setState(() {
          items = d['items'];
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

  Future<void> readAll() async {
    await ApiClient.patch('/notifications/read-all', {});
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          onPressed: readAll,
          tooltip: 'Mark all read',
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(child: Text(error!))
        : items.isEmpty
        ? const Center(child: Text('No notifications yet.'))
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final n = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      n['isRead'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                    ),
                    title: Text(n['title'] ?? 'Notification'),
                    subtitle: Text(n['message'] ?? ''),
                    onTap: () async {
                      await ApiClient.patch(
                        '/notifications/${n['_id']}/read',
                        {},
                      );
                      load();
                    },
                  ),
                );
              },
            ),
          ),
  );
}
