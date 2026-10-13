enum TaskStatus { todo, inProgress, forReview, completed, returned }

enum TaskPriority { low, medium, high, urgent }

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.project,
    required this.assignee,
    required this.priority,
    required this.status,
    required this.dueDate,
    this.projectId = '',
    this.assigneeId,
    this.reporterId,
    this.reporter = '',
    this.type = 'standard',
    this.scope = 'project',
    this.ownerId,
    this.startDate,
    this.reminderAt,
    this.completedAt,
    this.activitySettings = const {},
    this.activityStatus,
    this.collaborators = const [],
    this.watchers = const [],
    this.tags = const [],
    this.category = '',
    this.dependencies = const [],
    this.recurrence = const {},
    this.isArchived = false,
    this.isCancelled = false,
    this.subtasks = const [],
    this.attachments = const [],
  });
  final String id, project, assignee, projectId;
  String title, description;
  final String? assigneeId;
  final String? reporterId;
  final String reporter;
  final String type;
  final String scope;
  final String? ownerId;
  DateTime? startDate;
  DateTime? reminderAt, completedAt;
  Map<String, dynamic> activitySettings;
  final String? activityStatus;
  final List<Map<String, dynamic>> collaborators, watchers, dependencies;
  final List<String> tags;
  final String category;
  final Map<String, dynamic> recurrence;
  final bool isArchived, isCancelled;
  final TaskPriority priority;
  TaskStatus status;
  DateTime dueDate;
  final List<Map<String, dynamic>> subtasks;
  final List<Map<String, dynamic>> attachments;
  bool get isOverdue =>
      effectiveStatus != TaskStatus.completed &&
      dueDate.isBefore(DateTime.now());
  bool get isIndividualActivity => type == 'individual-activity';
  bool get isPersonal => scope == 'personal';
  TaskStatus get effectiveStatus =>
      isIndividualActivity && activityStatus != null
      ? statusFromApi(activityStatus)
      : status;

  factory TaskItem.fromJson(Map<String, dynamic> j) {
    final p = j['project'],
        a = j['assignee'],
        r = j['reporter'],
        o = j['owner'];
    return TaskItem(
      id: j['_id'] ?? '',
      title: j['title'] ?? '',
      description: j['description'] ?? '',
      projectId: p is Map ? p['_id'] ?? '' : p ?? '',
      project: j['scope'] == 'personal'
          ? 'Personal'
          : p is Map
          ? p['name'] ?? 'Project'
          : 'Project',
      assigneeId: a is Map ? a['_id'] : a,
      reporterId: r is Map ? r['_id']?.toString() : r?.toString(),
      reporter: r is Map
          ? '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'.trim()
          : '',
      type: j['type'] ?? 'standard',
      scope: j['scope'] ?? 'project',
      ownerId: o is Map ? o['_id']?.toString() : o?.toString(),
      startDate: DateTime.tryParse(j['startDate'] ?? ''),
      reminderAt: DateTime.tryParse(j['reminderAt'] ?? ''),
      completedAt: DateTime.tryParse(j['completedAt'] ?? ''),
      activitySettings: Map<String, dynamic>.from(
        j['activitySettings'] is Map ? j['activitySettings'] : const {},
      ),
      activityStatus: j['myAssignmentStatus']?.toString(),
      collaborators: (j['collaborators'] as List? ?? const [])
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : {'_id': e.toString()},
          )
          .toList(),
      watchers: (j['watchers'] as List? ?? const [])
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : {'_id': e.toString()},
          )
          .toList(),
      dependencies: (j['dependencies'] as List? ?? const [])
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : {'_id': e.toString()},
          )
          .toList(),
      tags: (j['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
      category: j['category'] ?? '',
      recurrence: Map<String, dynamic>.from(
        j['recurrence'] is Map ? j['recurrence'] : const {},
      ),
      isArchived: j['isArchived'] == true,
      isCancelled: j['isCancelled'] == true,
      assignee: a is Map
          ? '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim()
          : 'Unassigned',
      priority: TaskPriority.values.firstWhere(
        (v) => v.name == j['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: statusFromApi(j['status']),
      dueDate: DateTime.tryParse(j['deadline'] ?? '') ?? DateTime.now(),
      subtasks: (j['subtasks'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      attachments: (j['attachments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
  static TaskStatus statusFromApi(String? v) => switch (v) {
    'in-progress' => TaskStatus.inProgress,
    'for-review' => TaskStatus.forReview,
    'completed' => TaskStatus.completed,
    'returned' => TaskStatus.returned,
    _ => TaskStatus.todo,
  };
}

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
    TaskStatus.todo => 'To Do',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.forReview => 'For Review',
    TaskStatus.completed => 'Completed',
    TaskStatus.returned => 'Returned',
  };
  String get api => switch (this) {
    TaskStatus.inProgress => 'in-progress',
    TaskStatus.forReview => 'for-review',
    TaskStatus.completed => 'completed',
    TaskStatus.returned => 'returned',
    _ => 'todo',
  };
}

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
    TaskPriority.urgent => 'Urgent',
  };
}
