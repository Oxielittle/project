import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/auth_service.dart';
import '../services/api_config.dart';
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
  bool avatarBusy = false;
  String avatarUrl = '';
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
    avatarUrl = u?['avatarUrl'] ?? '';
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

  String? get avatarSource {
    if (avatarUrl.isEmpty) return null;
    return avatarUrl.startsWith('http')
        ? avatarUrl
        : '${ApiConfig.origin}$avatarUrl';
  }

  Future<void> changeAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an image smaller than 5 MB.')),
        );
      }
      return;
    }
    setState(() => avatarBusy = true);
    try {
      final data = await AuthService.uploadAvatar(file.bytes!, file.name);
      if (!mounted) return;
      setState(() => avatarUrl = data['user']['avatarUrl'] ?? '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => avatarBusy = false);
    }
  }

  Future<void> removeAvatar() async {
    setState(() => avatarBusy = true);
    try {
      final data = await AuthService.removeAvatar();
      if (!mounted) return;
      setState(() => avatarUrl = data['user']['avatarUrl'] ?? '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture removed.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => avatarBusy = false);
    }
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
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      foregroundImage: avatarSource == null
                          ? null
                          : NetworkImage(avatarSource!),
                      child: avatarBusy
                          ? const CircularProgressIndicator()
                          : avatarSource == null
                          ? const Icon(Icons.person, size: 46)
                          : null,
                    ),
                    IconButton.filled(
                      tooltip: 'Change profile picture',
                      onPressed: avatarBusy ? null : changeAvatar,
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: avatarBusy ? null : changeAvatar,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      avatarSource == null
                          ? 'Choose picture'
                          : 'Change picture',
                    ),
                  ),
                  if (avatarSource != null)
                    TextButton.icon(
                      onPressed: avatarBusy ? null : removeAvatar,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                ],
              ),
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
