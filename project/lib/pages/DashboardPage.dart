import 'package:flutter/material.dart';

import '../models/task_item.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.tasks,
    required this.onViewTasks,
  });

  final List<TaskItem> tasks;
  final VoidCallback onViewTasks;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _filter = 'all';

  List<TaskItem> get tasks => widget.tasks.where((task) {
    if (task.isArchived ||
        task.isCancelled ||
        task.recurrence['template'] == true)
      return false;
    return switch (_filter) {
      'personal' => task.isPersonal,
      'project' => !task.isPersonal && !task.isIndividualActivity,
      'activity' => task.isIndividualActivity,
      _ => true,
    };
  }).toList();

  int _count(TaskStatus status) =>
      tasks.where((task) => task.effectiveStatus == status).length;

  @override
  Widget build(BuildContext context) {
    final overdue = tasks.where((task) => task.isOverdue).length;
    final upcoming = [
      ...tasks.where((task) => task.effectiveStatus != TaskStatus.completed),
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF071A3D),
                      Color(0xFF0A2E73),
                      Color(0xFF0755D9),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF277DFF).withValues(alpha: .65),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44176BFF),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
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
                      onPressed: widget.onViewTasks,
                      child: const Text('View my tasks'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  key: const Key('dashboard-work-filter'),
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All My Work')),
                    ButtonSegment(value: 'personal', label: Text('Personal')),
                    ButtonSegment(value: 'project', label: Text('Projects')),
                    ButtonSegment(value: 'activity', label: Text('Activities')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              const SizedBox(height: 12),
              _InteractiveDonut(
                values: [
                  _count(TaskStatus.todo),
                  _count(TaskStatus.inProgress),
                  _count(TaskStatus.forReview),
                  _count(TaskStatus.completed),
                ],
                overdue: overdue,
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
                    onTap: widget.onViewTasks,
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
                    onPressed: widget.onViewTasks,
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

class _InteractiveDonut extends StatefulWidget {
  const _InteractiveDonut({required this.values, required this.overdue});
  final List<int> values;
  final int overdue;

  @override
  State<_InteractiveDonut> createState() => _InteractiveDonutState();
}

class _InteractiveDonutState extends State<_InteractiveDonut>
    with SingleTickerProviderStateMixin {
  static const labels = ['To Do', 'In Progress', 'For Review', 'Completed'];
  static const colors = [
    Color(0xFF2F80FF),
    Color(0xFFFFA726),
    Color(0xFF9B6DFF),
    Color(0xFF27C779),
  ];
  late final AnimationController controller;
  Animation<double>? animation;
  double rotation = -.65;

  int get total => widget.values.fold(0, (sum, value) => sum + value);
  int get selected {
    if (total == 0) return 0;
    var pointer = (-1.57079632679 - rotation) % 6.28318530718;
    if (pointer < 0) pointer += 6.28318530718;
    var cursor = 0.0;
    for (var i = 0; i < widget.values.length; i++) {
      cursor += widget.values[i] / total * 6.28318530718;
      if (pointer <= cursor) return i;
    }
    return widget.values.length - 1;
  }

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addListener(
          () => setState(() => rotation = animation?.value ?? rotation),
        );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void spin(double velocity) {
    controller.stop();
    final distance = (velocity * .00055).clamp(-2.4, 2.4);
    animation = Tween(
      begin: rotation,
      end: rotation + distance,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final completion = total == 0
        ? 0
        : (widget.values[3] / total * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Swipe the chart to explore',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8EA1BC),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.threed_rotation, color: Color(0xFF55A3FF)),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => controller.stop(),
                onHorizontalDragUpdate: (details) =>
                    setState(() => rotation += details.delta.dx * .012),
                onHorizontalDragEnd: (details) =>
                    spin(details.velocity.pixelsPerSecond.dx),
                child: SizedBox(
                  width: double.infinity,
                  height: 285,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DonutPainter(
                            values: widget.values,
                            colors: colors,
                            rotation: rotation,
                            selected: selected,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.values[selected]}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              labels[selected].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: Color(0xFF8EA1BC),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 14,
              runSpacing: 10,
              children: List.generate(
                4,
                (index) => _LegendItem(
                  label: labels[index],
                  value: widget.values[index],
                  color: colors[index],
                  active: index == selected,
                ),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    icon: Icons.task_alt,
                    label: 'Completion',
                    value: '$completion%',
                    color: colors[3],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryValue(
                    icon: Icons.schedule,
                    label: 'Overdue',
                    value: '${widget.overdue}',
                    color: const Color(0xFFFF5C68),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.rotation,
    required this.selected,
  });
  final List<int> values;
  final List<Color> colors;
  final double rotation;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2 - 10);
    final chartWidth = (size.width * .82).clamp(235.0, 310.0);
    final rect = Rect.fromCenter(
      center: center,
      width: chartWidth,
      height: chartWidth * .76,
    );
    const gap = .035;
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        6.28318530718,
        false,
        Paint()
          ..color = const Color(0xFF142A49)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 46,
      );
      return;
    }
    for (var depth = 13; depth >= 1; depth--) {
      var start = rotation;
      for (var i = 0; i < values.length; i++) {
        final sweep = values[i] / total * 6.28318530718;
        canvas.drawArc(
          rect.shift(Offset(0, depth * .8)),
          start + gap,
          sweep - gap * 2,
          false,
          Paint()
            ..color = Color.lerp(colors[i], Colors.black, .58)!
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == selected ? 53 : 46
            ..strokeCap = StrokeCap.butt,
        );
        start += sweep;
      }
    }
    var start = rotation;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 6.28318530718;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors[i], Colors.white, .26)!,
            colors[i],
            Color.lerp(colors[i], Colors.black, .22)!,
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == selected ? 53 : 46
        ..strokeCap = StrokeCap.butt;
      if (i == selected)
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawArc(rect, start + gap, sweep - gap * 2, false, paint);
      start += sweep;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -10),
        width: chartWidth * .53,
        height: chartWidth * .32,
      ),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x22176BFF), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.selected != selected ||
      oldDelegate.values != values;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.value,
    required this.color,
    required this.active,
  });
  final String label;
  final int value;
  final Color color;
  final bool active;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: active ? color.withValues(alpha: .14) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: active ? color.withValues(alpha: .55) : Colors.transparent,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .45), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  $value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: color.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    ),
  );
}
