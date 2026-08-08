class HistoryEvent {
  final String action;
  final String by;
  final String? detail;
  final DateTime at;

  HistoryEvent({
    required this.action,
    required this.by,
    this.detail,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
    'action': action,
    'by': by,
    'detail': detail,
    'at': at,
  };

  static HistoryEvent fromMap(Map<String, dynamic> map) => HistoryEvent(
    action: map['action'] as String? ?? '',
    by: map['by'] as String? ?? '',
    detail: map['detail'] as String?,
    at: (map['at'] as dynamic)?.toDate() ?? DateTime.now(),
  );
}

class AppTask {
  final String id;
  final String title;
  final String? description;
  final String assignedTo;
  final String assignedToEmail;
  final String createdBy;
  final String status;
  final String? claimedBy;
  final String? claimedByName;
  final String? photoUrl;
  final List<String> photoUrls;
  final String? completionDescription;
  final bool uploadsComplete;
  final int uploadCompleted;
  final int uploadTotal;
  final int uploadBytesSent;
  final int uploadBytesTotal;
  final String? customer;
  final String? carOrThing;
  final String? presetId;
  final String? approvedBy;
  final String? rejectionReason;
  final List<HistoryEvent> history;
  final DateTime createdAt;
  final DateTime? completedAt;

  AppTask({
    required this.id,
    required this.title,
    this.description,
    required this.assignedTo,
    required this.assignedToEmail,
    required this.createdBy,
    this.status = 'pending',
    this.claimedBy,
    this.claimedByName,
    this.photoUrl,
    this.photoUrls = const [],
    this.completionDescription,
    this.uploadsComplete = true,
    this.uploadCompleted = 0,
    this.uploadTotal = 0,
    this.uploadBytesSent = 0,
    this.uploadBytesTotal = 0,
    this.customer,
    this.carOrThing,
    this.presetId,
    this.approvedBy,
    this.rejectionReason,
    this.history = const [],
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isDoing => status == 'doing';
  bool get isPending => status == 'pending';
  bool get isPendingReview => status == 'pending_review';
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

  factory AppTask.fromMap(Map<String, dynamic> map, String docId) {
    return AppTask(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      assignedTo: map['assignedTo'] as String? ?? '',
      assignedToEmail: map['assignedToEmail'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      claimedBy: map['claimedBy'] as String?,
      claimedByName: map['claimedByName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>() ??
          (map['photoUrl'] is String ? [map['photoUrl'] as String] : const []),
      completionDescription: map['completionDescription'] as String?,
      uploadsComplete: map['uploadsComplete'] as bool? ?? true,
      uploadCompleted: map['uploadCompleted'] as int? ?? 0,
      uploadTotal: map['uploadTotal'] as int? ?? 0,
      uploadBytesSent: map['uploadBytesSent'] as int? ?? 0,
      uploadBytesTotal: map['uploadBytesTotal'] as int? ?? 0,
      customer: map['customer'] as String?,
      carOrThing: map['carOrThing'] as String?,
      presetId: map['presetId'] as String?,
      approvedBy: map['approvedBy'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      history: (map['history'] as List<dynamic>?)
              ?.map((e) => HistoryEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedToEmail': assignedToEmail,
      'createdBy': createdBy,
      'status': status,
      'claimedBy': claimedBy,
      'claimedByName': claimedByName,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'completionDescription': completionDescription,
      'uploadsComplete': uploadsComplete,
      'uploadCompleted': uploadCompleted,
      'uploadTotal': uploadTotal,
      'uploadBytesSent': uploadBytesSent,
      'uploadBytesTotal': uploadBytesTotal,
      'customer': customer,
      'carOrThing': carOrThing,
      'presetId': presetId,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'history': history.map((e) => e.toMap()).toList(),
      'createdAt': createdAt,
      'completedAt': completedAt,
    };
  }

  AppTask copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? assignedToEmail,
    String? createdBy,
    String? status,
    String? claimedBy,
    String? claimedByName,
    String? photoUrl,
    String? customer,
    String? carOrThing,
    String? presetId,
    String? approvedBy,
    String? rejectionReason,
    List<HistoryEvent>? history,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return AppTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      claimedBy: claimedBy ?? this.claimedBy,
      claimedByName: claimedByName ?? this.claimedByName,
      photoUrl: photoUrl ?? this.photoUrl,
      customer: customer ?? this.customer,
      carOrThing: carOrThing ?? this.carOrThing,
      presetId: presetId ?? this.presetId,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      history: history ?? this.history,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
