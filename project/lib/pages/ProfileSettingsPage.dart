import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});
  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final first = TextEditingController(),
      last = TextEditingController(),
      phone = TextEditingController();
  final current = TextEditingController(), password = TextEditingController();
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final u = await SessionService.user();
    first.text = u?['firstName'] ?? '';
    last.text = u?['lastName'] ?? '';
    phone.text = u?['phone'] ?? '';
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    phone.dispose();
    current.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    await AuthService.updateProfile({
      'firstName': first.text.trim(),
      'lastName': last.text.trim(),
      'phone': phone.text.trim(),
    });
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  Future<void> savePassword() async {
    await AuthService.changePassword(current.text, password.text);
    current.clear();
    password.clear();
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password changed.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account settings')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: first,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: last,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: saveProfile,
                child: const Text('Save profile'),
              ),
              const Divider(height: 40),
              Text(
                'Change password',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: savePassword,
                child: const Text('Change password'),
              ),
            ],
          ),
  );
}
