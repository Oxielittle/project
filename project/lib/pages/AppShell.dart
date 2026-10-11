import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/session_service.dart';
import '../services/realtime_service.dart';
import '../services/api_client.dart';
import 'CreateTaskPage.dart';
import 'DashboardPage.dart';
import 'NotificationsPage.dart';
import 'ProfilePage.dart';
import 'ProjectsPage.dart';
import 'TaskListPage.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final List<TaskItem> _tasks = [];
  bool _loading = true;
  String? _error;
  bool _canManage = false;
  final _realtime = RealtimeService();

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadTasks();
    _realtime.connect(_loadTasks);
  }

  @override
  void dispose() {
    _realtime.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    var role = await SessionService.role();
    try {
      final data = await ApiClient.get('/auth/me');
      if (data['user'] != null) {
        await SessionService.saveUser(Map<String, dynamic>.from(data['user']));
        role = data['user']['role'] ?? role;
      }
    } catch (_) {
      // Keep the cached role when the server is temporarily unavailable.
    }
    if (mounted)
      setState(() => _canManage = role == 'admin' || role == 'manager');
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await TaskService.list();
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _addTask(TaskItem task) {
    setState(() {
      _tasks.insert(0, task);
      _selectedIndex = 2;
    });
  }

  void _updateTaskStatus(TaskItem task, TaskStatus status) {
    final previous = task.status;
    setState(() => task.status = status);
    TaskService.updateStatus(task, status).catchError((error) {
      if (mounted) {
        setState(() => task.status = previous);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });
  }

  void _openCreateTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateTaskPage(onCreate: _addTask)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        tasks: _tasks,
        onViewTasks: () => setState(() => _selectedIndex = 2),
      ),
      ProjectsPage(tasks: _tasks, canManage: _canManage),
      TaskListPage(
        tasks: _tasks,
        onStatusChanged: _updateTaskStatus,
        onRefresh: _loadTasks,
      ),
      const NotificationsPage(),
      const ProfilePage(),
    ];

    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 52),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadTasks, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
      ),
      floatingActionButton: _selectedIndex == 2 && _canManage
          ? FloatingActionButton.extended(
              onPressed: _openCreateTask,
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
