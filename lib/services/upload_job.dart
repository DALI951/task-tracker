enum UploadJobType {
  taskSubmit('task_submit'),
  taskApprove('task_approve'),
  problemReport('problem_report');

  const UploadJobType(this.value);
  final String value;

  static UploadJobType fromValue(String? v) {
    for (final t in UploadJobType.values) {
      if (t.value == v) return t;
    }
    return UploadJobType.taskSubmit;
  }
}

/// A queued background photo upload. The foreground service reads the image
/// from [filePath], uploads it, then applies the Firestore update + notification
/// matching [type] — even if the app itself is closed.
class UploadJob {
  final String id;
  final UploadJobType type;
  final String filePath;
  final String uploadPath;

  // Notification payload, baked at enqueue time (the background isolate has no
  // SettingsService, so strings are pre-resolved in the app's current language).
  final String notifType;
  final String notifTitle;
  final String notifMessage;
  final String recipientEmail;
  final String senderName;

  // Task jobs
  final String? taskId;
  final String? taskTitle;
  final String? actorEmail;
  final String? actorName;
  final String? historyAction;
  final String? historyBy;

  // Problem jobs
  final String? reporterEmail;
  final String? reporterName;
  final String? description;
  final String? carOrThing;
  final String? managerEmail;

  final String status;

  const UploadJob({
    required this.id,
    required this.type,
    required this.filePath,
    required this.uploadPath,
    required this.notifType,
    required this.notifTitle,
    required this.notifMessage,
    required this.recipientEmail,
    this.senderName = '',
    this.taskId,
    this.taskTitle,
    this.actorEmail,
    this.actorName,
    this.historyAction,
    this.historyBy,
    this.reporterEmail,
    this.reporterName,
    this.description,
    this.carOrThing,
    this.managerEmail,
    this.status = 'queued',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'filePath': filePath,
        'uploadPath': uploadPath,
        'notifType': notifType,
        'notifTitle': notifTitle,
        'notifMessage': notifMessage,
        'recipientEmail': recipientEmail,
        'senderName': senderName,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'actorEmail': actorEmail,
        'actorName': actorName,
        'historyAction': historyAction,
        'historyBy': historyBy,
        'reporterEmail': reporterEmail,
        'reporterName': reporterName,
        'description': description,
        'carOrThing': carOrThing,
        'managerEmail': managerEmail,
        'status': status,
      };

  factory UploadJob.fromJson(Map<String, dynamic> json) => UploadJob(
        id: json['id'] as String? ?? '',
        type: UploadJobType.fromValue(json['type'] as String?),
        filePath: json['filePath'] as String? ?? '',
        uploadPath: json['uploadPath'] as String? ?? '',
        notifType: json['notifType'] as String? ?? '',
        notifTitle: json['notifTitle'] as String? ?? '',
        notifMessage: json['notifMessage'] as String? ?? '',
        recipientEmail: json['recipientEmail'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '',
        taskId: json['taskId'] as String?,
        taskTitle: json['taskTitle'] as String?,
        actorEmail: json['actorEmail'] as String?,
        actorName: json['actorName'] as String?,
        historyAction: json['historyAction'] as String?,
        historyBy: json['historyBy'] as String?,
        reporterEmail: json['reporterEmail'] as String?,
        reporterName: json['reporterName'] as String?,
        description: json['description'] as String?,
        carOrThing: json['carOrThing'] as String?,
        managerEmail: json['managerEmail'] as String?,
        status: json['status'] as String? ?? 'queued',
      );
}
