import 'package:flutter/material.dart';

import '../services/api_client.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
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
      final data = await ApiClient.get('/users');
      if (mounted)
        setState(() {
          users = data['items'] ?? [];
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

  Future<void> update(String id, Map<String, dynamic> changes) async {
    await ApiClient.patch('/users/$id', changes);
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User management')),
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
        : users.isEmpty
        ? const Center(child: Text('No users found.'))
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = Map<String, dynamic>.from(users[index]);
                final archived = user['isArchived'] == true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        '${user['firstName'] ?? 'U'}'[0].toUpperCase(),
                      ),
                    ),
                    title: Text(
                      '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                          .trim(),
                    ),
                    subtitle: Text(
                      '${user['email']}\n${archived ? 'Archived' : 'Active'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'archive'
                          ? update(user['_id'], {'isArchived': !archived})
                          : update(user['_id'], {'role': value}),
                      itemBuilder: (_) => [
                        for (final role in ['admin', 'manager', 'member'])
                          PopupMenuItem(value: role, child: Text('Make $role')),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(archived ? 'Restore' : 'Archive'),
                        ),
                      ],
                      child: Chip(label: Text(user['role'] ?? 'member')),
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
