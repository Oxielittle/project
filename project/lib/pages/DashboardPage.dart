import 'package:flutter/material.dart';

import '../models/task_item.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.tasks,
    required this.onViewTasks,
  });

  final List<TaskItem> tasks;
  final VoidCallback onViewTasks;

  int _count(TaskStatus status) =>
      tasks.where((task) => task.status == status).length;

  @override
  Widget build(BuildContext context) {
    final overdue = tasks.where((task) => task.isOverdue).length;
    final upcoming = [
      ...tasks.where((task) => task.status != TaskStatus.completed),
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard'),
              Text(
                'Your work at a glance',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3155D9), Color(0xFF6C63FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Let\'s make progress today.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: onViewTasks,
                      child: const Text('View my tasks'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Task overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _MetricCard(
                    label: 'To Do',
                    value: _count(TaskStatus.todo),
                    icon: Icons.inbox_outlined,
                    color: Colors.blue,
                  ),
                  _MetricCard(
                    label: 'In Progress',
                    value: _count(TaskStatus.inProgress),
                    icon: Icons.timelapse,
                    color: Colors.orange,
                  ),
                  _MetricCard(
                    label: 'For Review',
                    value: _count(TaskStatus.forReview),
                    icon: Icons.rate_review_outlined,
                    color: Colors.purple,
                  ),
                  _MetricCard(
                    label: 'Completed',
                    value: _count(TaskStatus.completed),
                    icon: Icons.task_alt,
                    color: Colors.green,
                  ),
                ],
              ),
              if (overdue > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(
                      '$overdue overdue task${overdue == 1 ? '' : 's'}',
                    ),
                    subtitle: const Text(
                      'Review these tasks and update their deadlines.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onViewTasks,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming deadlines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: onViewTasks,
                    child: const Text('See all'),
                  ),
                ],
              ),
              ...upcoming
                  .take(3)
                  .map(
                    (task) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(task.project.characters.first),
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '${task.project} • ${_formatDate(task.dueDate)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
