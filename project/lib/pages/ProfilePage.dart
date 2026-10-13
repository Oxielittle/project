import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/theme_service.dart';
import 'ActivityPage.dart';
import 'AdminUsersPage.dart';
import 'ArchivePage.dart';
import 'LoginPage.dart';
import 'TeamsPage.dart';
import 'ProfileSettingsPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? user;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    var value = await SessionService.user();
    try {
      final data = await ApiClient.get('/auth/me');
      if (data['user'] != null) {
        value = Map<String, dynamic>.from(data['user']);
        await SessionService.saveUser(value);
      }
    } catch (_) {}
    if (mounted) setState(() => user = value);
  }

  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final role = user?['role'] ?? 'member';
    final name = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'
        .trim();
    final storedAvatar = (user?['avatarUrl'] ?? '').toString();
    final avatarSource = storedAvatar.isEmpty
        ? null
        : storedAvatar.startsWith('http')
        ? storedAvatar
        : '${ApiConfig.origin}$storedAvatar';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 46,
            foregroundImage: avatarSource == null
                ? null
                : NetworkImage(avatarSource),
            child: avatarSource == null
                ? Text(
                    name.isEmpty ? 'U' : name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 34),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              name.isEmpty ? 'Task Manager User' : name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(child: Text(role.toString().toUpperCase())),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(user?['email'] ?? 'Account details'),
              subtitle: Text(user?['username'] ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileSettingsPage(),
                  ),
                );
                await load();
              },
            ),
          ),
          if (role == 'admin' || role == 'manager')
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Teams and members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const TeamsPage()),
              ),
            ),
          ValueListenableBuilder<bool>(
            valueListenable: ThemeService.lightMode,
            builder: (_, lightMode, __) => Card(
              child: SwitchListTile(
                secondary: Icon(
                  lightMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                title: const Text('Light mode'),
                subtitle: const Text('Dark navy is the default appearance'),
                value: lightMode,
                onChanged: ThemeService.setLightMode,
              ),
            ),
          ),
          if (role == 'admin')
            Card(
              child: ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('User management'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const AdminUsersPage()),
              ),
            ),
          if (role == 'admin')
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Activity history'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const ActivityPage()),
              ),
            ),
          if (role == 'admin' || role == 'manager')
            Card(
              child: ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archived records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const ArchivePage()),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
