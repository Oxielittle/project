class ActivityAssignment {
  const ActivityAssignment({
    required this.id,
    required this.status,
    required this.recipient,
    required this.recipientId,
    required this.textResponse,
    required this.attachments,
    required this.history,
    required this.submissionCount,
    required this.isLate,
    required this.feedback,
    required this.maximumScore,
    this.score,
    this.latestSubmittedAt,
  });

  final String id, status, recipient, recipientId, textResponse, feedback;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> history;
  final int submissionCount, maximumScore;
  final num? score;
  final bool isLate;
  final DateTime? latestSubmittedAt;

  factory ActivityAssignment.fromJson(Map<String, dynamic> json) {
    final recipient = json['recipient'];
    return ActivityAssignment(
      id: json['_id']?.toString() ?? '',
      status: json['status'] ?? 'assigned',
      recipientId: recipient is Map
          ? recipient['_id']?.toString() ?? ''
          : recipient?.toString() ?? '',
      recipient: recipient is Map
          ? '${recipient['firstName'] ?? ''} ${recipient['lastName'] ?? ''}'
                .trim()
          : 'Recipient',
      textResponse: json['textResponse'] ?? '',
      attachments: (json['attachments'] as List? ?? const [])
          .map((value) => Map<String, dynamic>.from(value))
          .toList(),
      history: (json['submissionHistory'] as List? ?? const [])
          .map((value) => Map<String, dynamic>.from(value))
          .toList(),
      submissionCount: (json['submissionCount'] as num?)?.toInt() ?? 0,
      isLate: json['isLate'] == true,
      feedback: json['feedback'] ?? '',
      score: json['score'] as num?,
      maximumScore: (json['maximumScore'] as num?)?.toInt() ?? 100,
      latestSubmittedAt: DateTime.tryParse(json['latestSubmittedAt'] ?? ''),
    );
  }
}
