class Problem {
  final String id;
  final String reportedBy;
  final String reporterName;
  final String description;
  final String? photoUrl;
  final List<String> photoUrls;
  final String? assignedToName;
  final String? carOrThing;
  final DateTime createdAt;
  final String status;
  final String? convertedToTaskId;

  Problem({
    required this.id,
    required this.reportedBy,
    required this.reporterName,
    required this.description,
    this.photoUrl,
    this.photoUrls = const [],
    this.assignedToName,
    this.carOrThing,
    required this.createdAt,
    this.status = 'open',
    this.convertedToTaskId,
  });

  bool get isOpen => status == 'open';
  bool get isAssigned => status == 'assigned';
  bool get isResolved => status == 'resolved';

  factory Problem.fromMap(Map<String, dynamic> map, String docId) {
    return Problem(
      id: docId,
      reportedBy: map['reportedBy'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>() ??
          (map['photoUrl'] is String ? [map['photoUrl'] as String] : const []),
      assignedToName: map['assignedToName'] as String?,
      carOrThing: map['carOrThing'] as String?,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      status: map['status'] as String? ?? 'open',
      convertedToTaskId: map['convertedToTaskId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportedBy': reportedBy,
      'reporterName': reporterName,
      'description': description,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'assignedToName': assignedToName,
      'carOrThing': carOrThing,
      'createdAt': createdAt,
      'status': status,
      'convertedToTaskId': convertedToTaskId,
    };
  }
}
