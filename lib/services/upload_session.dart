import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// A photo queued for background upload. [file] is the name inside the
/// session directory, [url] is filled by the worker once uploaded.
class SessionPhoto {
  String file;
  int bytes;
  String url;
  bool done;

  SessionPhoto({
    required this.file,
    required this.bytes,
    this.url = '',
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'file': file,
        'bytes': bytes,
        'url': url,
        'done': done,
      };

  static SessionPhoto fromJson(Map<String, dynamic> map) => SessionPhoto(
        file: map['file'] as String? ?? '',
        bytes: map['bytes'] as int? ?? 0,
        url: map['url'] as String? ?? '',
        done: map['done'] as bool? ?? false,
      );
}

/// One background upload job: the picked photos were copied into
/// `<appDocs>/bg_uploads/<sessionId>/` before the worker was registered, so
/// uploads survive the app being backgrounded or killed. The worker reads
/// [state.json] to know which photos still need uploading, then applies the
/// final document flip + push once everything is on the server.
class UploadSession {
  final String sessionId;
  final String type; // 'task_completion' | 'problem_report'
  final String docId;
  final List<SessionPhoto> photos;
  final int totalBytes;

  // task_completion
  final String? previousStatus;
  final bool approveDirectly;
  final String? completionDescription;
  final String? taskTitle;
  final String? createdBy;
  final String? assignedToEmail;

  // problem_report
  final String? reportedBy;
  final String? reporterName;
  final String? description;
  final String? carOrThing;

  // final flip + push (localized in the app before persisting)
  final String actorEmail;
  final String senderName;
  final String pushType;
  final String pushRecipientEmail;
  final String pushTitle;
  final String pushMessage;
  final String pushSenderName;
  final String historyAction;
  final String historyBy;

  String status; // uploading | paused | done | cancelled | failed
  String error; // human-readable reason when status == 'paused'/'failed' (localized)
  int retryCount; // consecutive auto-retries Workmanager performed (capped)
  int lastActivity; // ms epoch of the worker's last write; stale = worker died
  bool finalApplied;
  bool pendingApply;
  int bytesSent;
  final int notificationId;
  final DateTime createdAt;

  UploadSession({
    required this.sessionId,
    required this.type,
    required this.docId,
    required this.photos,
    required this.totalBytes,
    this.previousStatus,
    this.approveDirectly = false,
    this.completionDescription,
    this.taskTitle,
    this.createdBy,
    this.assignedToEmail,
    this.reportedBy,
    this.reporterName,
    this.description,
    this.carOrThing,
    this.actorEmail = '',
    this.senderName = '',
    this.pushType = '',
    this.pushRecipientEmail = '',
    this.pushTitle = '',
    this.pushMessage = '',
    this.pushSenderName = '',
    this.historyAction = '',
    this.historyBy = '',
    this.status = 'uploading',
    this.error = '',
    this.retryCount = 0,
    this.lastActivity = 0,
    this.finalApplied = false,
    this.pendingApply = false,
    this.bytesSent = 0,
    required this.notificationId,
    required this.createdAt,
  });

  String get uniqueName => 'bg-upload-$sessionId';

  int get completedPhotos => photos.where((p) => p.done).length;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'type': type,
        'docId': docId,
        'photos': photos.map((p) => p.toJson()).toList(),
        'totalBytes': totalBytes,
        'previousStatus': previousStatus,
        'approveDirectly': approveDirectly,
        'completionDescription': completionDescription,
        'taskTitle': taskTitle,
        'createdBy': createdBy,
        'assignedToEmail': assignedToEmail,
        'reportedBy': reportedBy,
        'reporterName': reporterName,
        'description': description,
        'carOrThing': carOrThing,
        'actorEmail': actorEmail,
        'senderName': senderName,
        'pushType': pushType,
        'pushRecipientEmail': pushRecipientEmail,
        'pushTitle': pushTitle,
        'pushMessage': pushMessage,
        'pushSenderName': pushSenderName,
        'historyAction': historyAction,
        'historyBy': historyBy,
        'status': status,
        'error': error,
        'retryCount': retryCount,
        'lastActivity': lastActivity,
        'finalApplied': finalApplied,
        'pendingApply': pendingApply,
        'bytesSent': bytesSent,
        'notificationId': notificationId,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static UploadSession fromJson(Map<String, dynamic> map) => UploadSession(
        sessionId: map['sessionId'] as String? ?? '',
        type: map['type'] as String? ?? '',
        docId: map['docId'] as String? ?? '',
        photos: (map['photos'] as List<dynamic>? ?? [])
            .map((e) => SessionPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalBytes: map['totalBytes'] as int? ?? 0,
        previousStatus: map['previousStatus'] as String?,
        approveDirectly: map['approveDirectly'] as bool? ?? false,
        completionDescription: map['completionDescription'] as String?,
        taskTitle: map['taskTitle'] as String?,
        createdBy: map['createdBy'] as String?,
        assignedToEmail: map['assignedToEmail'] as String?,
        reportedBy: map['reportedBy'] as String?,
        reporterName: map['reporterName'] as String?,
        description: map['description'] as String?,
        carOrThing: map['carOrThing'] as String?,
        actorEmail: map['actorEmail'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        pushType: map['pushType'] as String? ?? '',
        pushRecipientEmail: map['pushRecipientEmail'] as String? ?? '',
        pushTitle: map['pushTitle'] as String? ?? '',
        pushMessage: map['pushMessage'] as String? ?? '',
        pushSenderName: map['pushSenderName'] as String? ?? '',
        historyAction: map['historyAction'] as String? ?? '',
        historyBy: map['historyBy'] as String? ?? '',
        status: map['status'] as String? ?? 'uploading',
        error: map['error'] as String? ?? '',
        retryCount: map['retryCount'] as int? ?? 0,
        lastActivity: map['lastActivity'] as int? ?? 0,
        finalApplied: map['finalApplied'] as bool? ?? false,
        pendingApply: map['pendingApply'] as bool? ?? false,
        bytesSent: map['bytesSent'] as int? ?? 0,
        notificationId: map['notificationId'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int? ?? 0),
      );

  UploadSession copyWith({
    String? status,
    String? error,
    int? retryCount,
    int? lastActivity,
    bool? finalApplied,
    bool? pendingApply,
    int? bytesSent,
    List<SessionPhoto>? photos,
  }) =>
      UploadSession(
        sessionId: sessionId,
        type: type,
        docId: docId,
        photos: photos ?? this.photos,
        totalBytes: totalBytes,
        previousStatus: previousStatus,
        approveDirectly: approveDirectly,
        completionDescription: completionDescription,
        taskTitle: taskTitle,
        createdBy: createdBy,
        assignedToEmail: assignedToEmail,
        reportedBy: reportedBy,
        reporterName: reporterName,
        description: description,
        carOrThing: carOrThing,
        actorEmail: actorEmail,
        senderName: senderName,
        pushType: pushType,
        pushRecipientEmail: pushRecipientEmail,
        pushTitle: pushTitle,
        pushMessage: pushMessage,
        pushSenderName: pushSenderName,
        historyAction: historyAction,
        historyBy: historyBy,
        status: status ?? this.status,
        error: error ?? this.error,
        retryCount: retryCount ?? this.retryCount,
        lastActivity: lastActivity ?? this.lastActivity,
        finalApplied: finalApplied ?? this.finalApplied,
        pendingApply: pendingApply ?? this.pendingApply,
        bytesSent: bytesSent ?? this.bytesSent,
        notificationId: notificationId,
        createdAt: createdAt,
      );
}

/// Persists upload sessions as files (survives app restarts) and copies the
/// picked photos into the session directory before the worker starts.
class UploadSessionService {
  static Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/bg_uploads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> dir(String sessionId) async {
    final root = await _root();
    final dir = Directory('${root.path}/$sessionId');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> _newSessionId() async {
    var id = '';
    do {
      id =
          '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).substring(2)}';
      await Future<void>.delayed(const Duration(milliseconds: 1));
    } while (await _exists(id));
    return id;
  }

  static Future<bool> _exists(String sessionId) async {
    final root = await _root();
    return Directory('${root.path}/$sessionId').existsSync();
  }

  /// Notification id space for upload sessions (10000..16383).
  static int notificationIdFor(String sessionId) =>
      10000 + (sessionId.hashCode & 0x3FFF);

  static Future<String> createTaskSession({
    required String taskId,
    required List<Uint8List> images,
    required String previousStatus,
    required bool approveDirectly,
    String? completionDescription,
    required String actorEmail,
    required String senderName,
    required String taskTitle,
    required String createdBy,
    required String assignedToEmail,
    required String pushType,
    required String pushRecipientEmail,
    required String pushTitle,
    required String pushMessage,
    required String pushSenderName,
    required String historyAction,
    required String historyBy,
  }) async {
    final sessionId = await _newSessionId();
    final sessionDir = await dir(sessionId);
    final photos = <SessionPhoto>[];
    var totalBytes = 0;
    for (var i = 0; i < images.length; i++) {
      final name = 'photo_${i + 1}.jpg';
      File('${sessionDir.path}/$name').writeAsBytesSync(images[i]);
      photos.add(SessionPhoto(file: name, bytes: images[i].length));
      totalBytes += images[i].length;
    }
    final session = UploadSession(
      sessionId: sessionId,
      type: 'task_completion',
      docId: taskId,
      photos: photos,
      totalBytes: totalBytes,
      previousStatus: previousStatus,
      approveDirectly: approveDirectly,
      completionDescription: completionDescription,
      taskTitle: taskTitle,
      createdBy: createdBy,
      assignedToEmail: assignedToEmail,
      actorEmail: actorEmail,
      senderName: senderName,
      pushType: pushType,
      pushRecipientEmail: pushRecipientEmail,
      pushTitle: pushTitle,
      pushMessage: pushMessage,
      pushSenderName: pushSenderName,
      historyAction: historyAction,
      historyBy: historyBy,
      notificationId: notificationIdFor(sessionId),
      createdAt: DateTime.now(),
    );
    await write(session);
    return sessionId;
  }

  static Future<String> createProblemSession({
    required String problemId,
    required List<Uint8List> images,
    required String reportedBy,
    required String reporterName,
    required String description,
    String? carOrThing,
    required String managerEmail,
    required String pushTitle,
    required String pushMessage,
  }) async {
    final sessionId = await _newSessionId();
    final sessionDir = await dir(sessionId);
    final photos = <SessionPhoto>[];
    var totalBytes = 0;
    for (var i = 0; i < images.length; i++) {
      final name = 'photo_${i + 1}.jpg';
      File('${sessionDir.path}/$name').writeAsBytesSync(images[i]);
      photos.add(SessionPhoto(file: name, bytes: images[i].length));
      totalBytes += images[i].length;
    }
    final session = UploadSession(
      sessionId: sessionId,
      type: 'problem_report',
      docId: problemId,
      photos: photos,
      totalBytes: totalBytes,
      reportedBy: reportedBy,
      reporterName: reporterName,
      description: description,
      carOrThing: carOrThing,
      actorEmail: '',
      senderName: reporterName,
      pushType: 'problem_reported',
      pushRecipientEmail: managerEmail,
      pushTitle: pushTitle,
      pushMessage: pushMessage,
      pushSenderName: reporterName,
      historyAction: '',
      historyBy: '',
      notificationId: notificationIdFor(sessionId),
      createdAt: DateTime.now(),
    );
    await write(session);
    return sessionId;
  }

  static Future<void> write(UploadSession session) async {
    final sessionDir = await dir(session.sessionId);
    File('${sessionDir.path}/state.json').writeAsStringSync(
      json.encode(session.toJson()),
    );
  }

  static Future<UploadSession?> read(String sessionId) async {
    final root = await _root();
    final dir = Directory('${root.path}/$sessionId');
    if (!dir.existsSync()) return null;
    final file = File('${dir.path}/state.json');
    if (!file.existsSync()) return null;
    try {
      return UploadSession.fromJson(
          json.decode(file.readAsStringSync()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<List<UploadSession>> readAll() async {
    final root = await _root();
    if (!root.existsSync()) return [];
    final sessions = <UploadSession>[];
    for (final entry in root.listSync()) {
      if (entry is! Directory) continue;
      final session = await read(entry.path.split(Platform.pathSeparator).last);
      if (session != null) sessions.add(session);
    }
    return sessions;
  }

  static Future<UploadSession?> findByTaskId(String taskId) async {
    for (final s in await readAll()) {
      if (s.type == 'task_completion' && s.docId == taskId) return s;
    }
    return null;
  }

  static Future<UploadSession?> findByProblemId(String problemId) async {
    for (final s in await readAll()) {
      if (s.type == 'problem_report' && s.docId == problemId) return s;
    }
    return null;
  }

  static Future<void> markCancelled(String sessionId) async {
    final session = await read(sessionId);
    if (session == null) return;
    await write(session.copyWith(status: 'cancelled'));
  }

  static Future<void> delete(String sessionId) async {
    final root = await _root();
    final dir = Directory('${root.path}/$sessionId');
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}
