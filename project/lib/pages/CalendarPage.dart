import 'package:flutter/material.dart';

import '../models/task_item.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.tasks});
  final List<TaskItem> tasks;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final first = DateTime(selected.year, selected.month, 1);
    final days = DateUtils.getDaysInMonth(selected.year, selected.month);
    final offset = first.weekday % 7;
    final selectedTasks = widget.tasks
        .where((task) => DateUtils.isSameDay(task.dueDate, selected))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Deadline calendar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(
                  () =>
                      selected = DateTime(selected.year, selected.month - 1, 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_months[selected.month - 1]} ${selected.year}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => setState(
                  () =>
                      selected = DateTime(selected.year, selected.month + 1, 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (_, index) {
              if (index < offset) return const SizedBox.shrink();
              final date = DateTime(
                selected.year,
                selected.month,
                index - offset + 1,
              );
              final count = widget.tasks
                  .where((task) => DateUtils.isSameDay(task.dueDate, date))
                  .length;
              return InkWell(
                onTap: () => setState(() => selected = date),
                child: Card(
                  color: DateUtils.isSameDay(date, selected)
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}'),
                      if (count > 0) Badge(label: Text('$count')),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Deadlines on ${selected.month}/${selected.day}/${selected.year}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (selectedTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No deadlines on this date.')),
            ),
          ...selectedTasks.map(
            (task) => Card(
              child: ListTile(
                title: Text(task.title),
                subtitle: Text('${task.project} • ${task.status.label}'),
                leading: const Icon(Icons.event_available),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}
