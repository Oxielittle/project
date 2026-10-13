import 'package:flutter/material.dart';

import '../models/task_item.dart';
import 'TaskDetailsPage.dart';
import 'CalendarPage.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({
    super.key,
    required this.tasks,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final List<TaskItem> tasks;
  final void Function(TaskItem, TaskStatus) onStatusChanged;
  final Future<void> Function() onRefresh;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  String _query = '';
  TaskStatus? _status;
  TaskPriority? _priority;
  String _sort = 'deadline';
  String _scope = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.tasks.where((task) {
          final query = _query.toLowerCase();
          final matchesQuery =
              task.title.toLowerCase().contains(query) ||
              task.project.toLowerCase().contains(query) ||
              task.assignee.toLowerCase().contains(query);
          return matchesQuery &&
              (_scope == 'all' ||
                  (_scope == 'personal' && task.isPersonal) ||
                  (_scope == 'project' &&
                      !task.isPersonal &&
                      !task.isIndividualActivity) ||
                  (_scope == 'activity' && task.isIndividualActivity)) &&
              (_status == null || task.status == _status) &&
              (_priority == null || task.priority == _priority);
        }).toList()..sort(
          (a, b) => switch (_sort) {
            'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            'priority' => b.priority.index.compareTo(a.priority.index),
            _ => a.dueDate.compareTo(b.dueDate),
          },
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Deadline calendar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CalendarPage(tasks: widget.tasks),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search tasks, projects, or members',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              key: const Key('task-scope-filter'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final option in const {
                  'all': 'All My Tasks',
                  'personal': 'Personal',
                  'project': 'Project Tasks',
                  'activity': 'Activities',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(option.value),
                      selected: _scope == option.key,
                      onSelected: (_) => setState(() => _scope = option.key),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All statuses'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                const SizedBox(width: 8),
                ...TaskStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status.label),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaskPriority?>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All priorities'),
                      ),
                      ...TaskPriority.values.map(
                        (priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _priority = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sort,
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                      prefixIcon: Icon(Icons.sort),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'deadline',
                        child: Text('Deadline'),
                      ),
                      DropdownMenuItem(
                        value: 'priority',
                        child: Text('Priority'),
                      ),
                      DropdownMenuItem(value: 'title', child: Text('Title')),
                    ],
                    onChanged: (value) =>
                        setState(() => _sort = value ?? 'deadline'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _scope == 'personal'
                          ? 'No personal tasks yet. Create one to keep track of your own work.'
                          : 'No tasks match the selected filters.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      return _TaskCard(
                        task: task,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailsPage(
                                task: task,
                                onStatusChanged: widget.onStatusChanged,
                              ),
                            ),
                          );
                          await widget.onRefresh();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});

  final TaskItem task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priority) {
      TaskPriority.low => Colors.green,
      TaskPriority.medium => Colors.blue,
      TaskPriority.high => Colors.orange,
      TaskPriority.urgent => Colors.red,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(task.project, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (task.isIndividualActivity)
                    const Chip(
                      avatar: Icon(Icons.assignment_ind_outlined, size: 16),
                      label: Text('Individual activity'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (task.isPersonal)
                    const Chip(
                      avatar: Icon(Icons.lock_person_outlined, size: 16),
                      label: Text('Personal'),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(
                    label: Text(
                      task.isIndividualActivity && task.activityStatus != null
                          ? task.activityStatus!
                                .split('-')
                                .map(
                                  (part) =>
                                      '${part[0].toUpperCase()}${part.substring(1)}',
                                )
                                .join(' ')
                          : task.isIndividualActivity
                          ? 'Activity overview'
                          : task.status.label,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (task.reminderAt != null)
                    Chip(
                      avatar: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                      ),
                      label: Text(
                        '${task.reminderAt!.month}/${task.reminderAt!.day}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if ((task.recurrence['frequency'] ?? 'none') != 'none')
                    Chip(
                      avatar: const Icon(Icons.repeat, size: 16),
                      label: Text(task.recurrence['frequency'].toString()),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(
                    avatar: Icon(Icons.flag, size: 16, color: priorityColor),
                    label: Text(task.priority.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    avatar: Icon(
                      task.isOverdue ? Icons.warning_amber : Icons.event,
                      size: 16,
                    ),
                    label: Text(
                      '${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    task.isIndividualActivity
                        ? Icons.groups_outlined
                        : Icons.person_outline,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    task.isIndividualActivity
                        ? 'Individual submission'
                        : task.assignee,
                  ),
                ],
              ),
              if (task.subtasks.isNotEmpty) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value:
                      task.subtasks
                          .where((item) => item['completed'] == true)
                          .length /
                      task.subtasks.length,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
