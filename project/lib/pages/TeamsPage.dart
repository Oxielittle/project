import 'package:flutter/material.dart';

import '../services/api_client.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  List<dynamic> teams = [];
  List<dynamic> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/teams'),
        ApiClient.get('/users'),
      ]);
      if (!mounted) return;
      setState(() {
        teams = results[0]['items'] ?? [];
        users = results[1]['items'] ?? [];
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load teams: $error')));
    }
  }

  Future<void> showTeamForm([Map<String, dynamic>? team]) async {
    final name = TextEditingController(text: team?['name'] ?? '');
    final description = TextEditingController(text: team?['description'] ?? '');
    final managerValue = team?['manager'];
    String? manager = managerValue is Map
        ? managerValue['_id']?.toString()
        : managerValue?.toString();
    final selectedMembers = <String>{
      ...(team?['members'] as List? ?? []).map(
        (member) =>
            member is Map ? member['_id'].toString() : member.toString(),
      ),
    };

    final shouldSave =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(team == null ? 'Create team' : 'Edit team'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Team name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: manager,
                    decoration: const InputDecoration(labelText: 'Manager'),
                    items: users
                        .map(
                          (user) => DropdownMenuItem<String>(
                            value: user['_id']?.toString(),
                            child: Text(
                              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                  .trim(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => manager = value),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Members',
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
                        final label =
                            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                .trim();
                        return FilterChip(
                          label: Text(label),
                          selected: selectedMembers.contains(id),
                          onSelected: (selected) => setDialogState(() {
                            selected
                                ? selectedMembers.add(id)
                                : selectedMembers.remove(id);
                          }),
                        );
                      }).toList(),
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
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (shouldSave && name.text.trim().isNotEmpty) {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'description': description.text.trim(),
        if (manager != null) 'manager': manager,
      };
      if (team == null) {
        await ApiClient.post('/teams', {
          ...body,
          'members': selectedMembers.toList(),
        });
      } else {
        await ApiClient.patch('/teams/${team['_id']}', body);
        await ApiClient.patch('/teams/${team['_id']}/members', {
          'members': selectedMembers.toList(),
        });
      }
      await load();
    }

    name.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        actions: [
          IconButton(
            onPressed: () => showTeamForm(),
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : teams.isEmpty
          ? const Center(child: Text('No teams yet.'))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final team = Map<String, dynamic>.from(teams[index]);
                  final members = team['members'] as List? ?? [];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.groups_outlined),
                      ),
                      title: Text(team['name'] ?? 'Team'),
                      subtitle: Text('${members.length} members'),
                      trailing: IconButton(
                        onPressed: () => showTeamForm(team),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
