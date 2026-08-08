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
  final bool uploadsComplete;
  final int uploadCompleted;
  final int uploadTotal;
  final int uploadBytesSent;
  final int uploadBytesTotal;

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
    this.uploadsComplete = true,
    this.uploadCompleted = 0,
    this.uploadTotal = 0,
    this.uploadBytesSent = 0,
    this.uploadBytesTotal = 0,
  });

  bool get isOpen => status == 'open';
  bool get isAssigned => status == 'assigned';
  bool get isResolved => status == 'resolved';
  bool get isUploading => status == 'uploading';

  /// 0..1 upload progress; null when no upload is in flight.
  /// Byte-based when the worker reported live byte counts (same numbers as
  /// the progress notification), photo-count as fallback.
  double? get uploadProgress {
    if (!isUploading || uploadTotal <= 0) return null;
    if (uploadBytesTotal > 0) {
      return (uploadBytesSent / uploadBytesTotal).clamp(0.0, 1.0);
    }
    return (uploadCompleted / uploadTotal).clamp(0.0, 1.0);
  }

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
      uploadsComplete: map['uploadsComplete'] as bool? ?? true,
      uploadCompleted: map['uploadCompleted'] as int? ?? 0,
      uploadTotal: map['uploadTotal'] as int? ?? 0,
      uploadBytesSent: map['uploadBytesSent'] as int? ?? 0,
      uploadBytesTotal: map['uploadBytesTotal'] as int? ?? 0,
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
      'uploadsComplete': uploadsComplete,
      'uploadCompleted': uploadCompleted,
      'uploadTotal': uploadTotal,
      'uploadBytesSent': uploadBytesSent,
      'uploadBytesTotal': uploadBytesTotal,
    };
  }
}
