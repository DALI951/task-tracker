import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:task_tracker/models/preset_item.dart';
import 'package:task_tracker/models/preset_task.dart';
import 'package:task_tracker/models/problem.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/services/firestore_service.dart';
import 'package:task_tracker/services/notification_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/storage_service.dart';
import 'package:task_tracker/services/user_service.dart';
import 'package:task_tracker/utils/error_handler.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final NotificationService _notif = NotificationService();
  final UserService _userService = UserService();

  SettingsService? _settings;
  void attachSettings(SettingsService settings) => _settings = settings;

  List<AppTask> _tasks = [];
  List<AppTask> _pendingReview = [];
  List<PresetTask> _presets = [];
  List<Problem> _problems = [];
  List<Problem> _myProblems = [];
  List<Map<String, dynamic>> _employees = [];
  List<PresetItem> _presetItems = [];
  bool _loading = true;
  bool _connected = false;
  String? _error;
  String? _employeeTasksError;
  String? _problemsError;
  String? _presetsError;
  String? _reportError;
  StreamSubscription? _taskSub;
  StreamSubscription? _reviewSub;
  StreamSubscription? _presetSub;
  StreamSubscription? _problemSub;
  StreamSubscription? _employeeSub;
  StreamSubscription? _itemSub;
  StreamSubscription? _myProblemSub;
  final Map<String, Timer> _restartTimers = {};
  final Map<String, int> _restartAttempts = {};
  static const int _maxRestartAttempts = 20;

  static const _kTasks = 'tasks';
  static const _kReview = 'review';
  static const _kProblems = 'problems';
  static const _kMyProblems = 'myProblems';
  static const _kPresets = 'presets';
  static const _kEmployees = 'employees';
  static const _kPresetItems = 'presetItems';

  String? _cancelTaskId;
  bool _uploadCancelled = false;
  bool get lastUploadCancelled => _uploadCancelled;

  String _t(String key) => _settings?.t(key) ?? key;

  List<AppTask> get tasks => _tasks;
  List<AppTask> get pendingReview => _pendingReview;
  List<PresetTask> get presets => _presets;
  List<Problem> get problems => _problems;
  List<Problem> get myProblems => _myProblems;
  List<Map<String, dynamic>> get employees => _employees;
  List<PresetItem> get presetItems => _presetItems;
  bool get loading => _loading;
  bool get connected => _connected;
  String? get error => _error;
  String? get employeeTasksError => _employeeTasksError;
  String? get problemsError => _problemsError;
  String? get presetsError => _presetsError;
  String? get reportError => _reportError;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearEmployeeTasksError() { _employeeTasksError = null; notifyListeners(); }
  void clearProblemsError() { _problemsError = null; notifyListeners(); }
  void clearPresetsError() { _presetsError = null; notifyListeners(); }
  void clearReportError() { _reportError = null; notifyListeners(); }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  // If a real-time stream dies (network blip, missing index, transient
  // rules error), re-subscribe after a short delay so the dashboard
  // recovers by itself instead of showing stale data until refresh.
  // Each stream has its own attempt budget so one failing stream cannot
  // exhaust the retries of every other stream.
  void _scheduleRestart(String key, void Function() resubscribe) {
    final attempts = (_restartAttempts[key] ?? 0) + 1;
    _restartAttempts[key] = attempts;
    if (attempts > _maxRestartAttempts) return;
    final seconds = attempts > 5 ? 15 : 3 * attempts;
    _restartTimers[key]?.cancel();
    _restartTimers[key] = Timer(Duration(seconds: seconds), () {
      if (FirebaseAuth.instance.currentUser == null) return;
      resubscribe();
    });
  }

  // Resets the retry budget of a single stream after it recovers. When no
  // key is given, clears every stream's budget and pending timers (used on
  // logout/dispose only) so one healthy stream can never cancel another
  // stream's pending restart.
  void _resetRestartBudget([String? key]) {
    if (key == null) {
      _restartAttempts.clear();
      for (final t in _restartTimers.values) {
        t.cancel();
      }
      _restartTimers.clear();
      return;
    }
    _restartAttempts.remove(key);
    _restartTimers.remove(key)?.cancel();
  }

  List<AppTask> searchTasks(String query) {
    if (query.isEmpty) return _tasks;
    final q = query.toLowerCase();
    return _tasks.where((t) =>
      t.title.toLowerCase().contains(q) ||
      t.assignedTo.toLowerCase().contains(q) ||
      (t.carOrThing?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  List<AppTask> _sortTasks(List<AppTask> tasks) {
    final sorted = List<AppTask>.from(tasks);
    sorted.sort((a, b) {
      if (a.status != b.status) {
        if (a.isCompleted) return 1;
        if (b.isCompleted) return -1;
        if (a.isDoing || a.isUploading) return -1;
        if (b.isDoing || b.isUploading) return 1;
        if (a.isPendingReview) return -1;
        if (b.isPendingReview) return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  void stopListening() {
    _resetRestartBudget();
    _taskSub?.cancel();
    _taskSub = null;
    _reviewSub?.cancel();
    _reviewSub = null;
    _presetSub?.cancel();
    _presetSub = null;
    _problemSub?.cancel();
    _problemSub = null;
    _myProblemSub?.cancel();
    _myProblemSub = null;
    _employeeSub?.cancel();
    _employeeSub = null;
    _itemSub?.cancel();
    _itemSub = null;
    _tasks = [];
    _pendingReview = [];
    _myProblems = [];
    _loading = true;
    notifyListeners();
  }

  void listenToAllTasks({bool silent = false}) {
    _taskSub?.cancel();
    if (!silent) {
      _loading = true;
      _connected = false;
      _tasks = [];
      _error = null;
      notifyListeners();
    }
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      _loading = false;
      _error = 'Not signed in';
      notifyListeners();
      return;
    }
    _taskSub = _firestore.allTasksStream(email).listen(
      (snapshot) {
        _tasks = _sortTasks(snapshot.docs.map((doc) {
          return AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList());
        _loading = false;
        _connected = true;
        _resetRestartBudget(_kTasks);
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _connected = false;
        _error = friendlyError(e);
        notifyListeners();
        _scheduleRestart(_kTasks, () => listenToAllTasks(silent: true));
      },
    );
    _listenPresets(email);
    _listenEmployees(email);
    _listenPresetItems(email);
  }

  void listenToEmployeeTasks(String email, {bool silent = false}) {
    _taskSub?.cancel();
    if (!silent) {
      _loading = email.isNotEmpty;
      _connected = false;
      _tasks = [];
      _error = null;
      notifyListeners();
    }
    if (email.isEmpty) {
      _loading = false;
      _error = 'No user email found';
      notifyListeners();
      return;
    }
    _taskSub = _firestore.tasksForEmployee(email).listen(
      (snapshot) {
        _tasks = _sortTasks(snapshot.docs.map((doc) {
          return AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList());
        _loading = false;
        _connected = true;
        _resetRestartBudget(_kTasks);
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _connected = false;
        _error = friendlyError(e);
        _employeeTasksError = friendlyError(e);
        notifyListeners();
        _scheduleRestart(_kTasks, () => listenToEmployeeTasks(email, silent: true));
      },
    );
  }

  void listenToPendingReview() {
    _reviewSub?.cancel();
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    _reviewSub = _firestore.pendingReviewStream(email).listen(
      (snapshot) {
        _pendingReview = snapshot.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'pending_review')
            .map((doc) {
              return AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            })
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _resetRestartBudget(_kReview);
        notifyListeners();
      },
      onError: (e) {
        _error = friendlyError(e);
        notifyListeners();
        _scheduleRestart(_kReview, listenToPendingReview);
      },
    );
  }

  void listenToProblems({bool isManager = true}) {
    _problemSub?.cancel();
    // Employees only send problems — they never read them.
    if (!isManager) return;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _problemSub = _firestore.problemsStream(email).listen(
      (snapshot) {
        _problems = snapshot.docs.map((doc) {
          return Problem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        _resetRestartBudget(_kProblems);
        notifyListeners();
      },
      onError: (e) {
        _error = friendlyError(e);
        _problemsError = friendlyError(e);
        notifyListeners();
        _scheduleRestart(_kProblems, () => listenToProblems(isManager: isManager));
      },
    );
  }

  /// Problems reported by this user (employees read their own reports so the
  /// Report screen can show per-report upload progress and final status).
  void listenToMyProblems(String email) {
    _myProblemSub?.cancel();
    if (email.isEmpty) return;
    _myProblemSub = _firestore.problemsReportedBy(email).listen(
      (snapshot) {
        _myProblems = snapshot.docs
            .map((doc) =>
                Problem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _resetRestartBudget(_kMyProblems);
        notifyListeners();
      },
      onError: (e) {
        _scheduleRestart(_kMyProblems, () => listenToMyProblems(email));
      },
    );
  }

  void _listenPresets(String createdBy) {
    _presetSub?.cancel();
    _presetSub = _firestore.presetsStream(createdBy).listen((snapshot) {
      _presetsError = null;
      _presets = snapshot.docs.map((doc) {
        return PresetTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _resetRestartBudget(_kPresets);
      notifyListeners();
    },
    onError: (e) {
      _error = friendlyError(e);
      _presetsError = friendlyError(e);
      notifyListeners();
      _scheduleRestart(_kPresets, () => _listenPresets(createdBy));
    });
  }

  void _listenEmployees(String createdBy) {
    _employeeSub?.cancel();
    _employeeSub = _firestore.employeesStream(createdBy).listen((snapshot) {
      _employees = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      _resetRestartBudget(_kEmployees);
      notifyListeners();
    },
    onError: (e) {
      _error = friendlyError(e);
      notifyListeners();
      _scheduleRestart(_kEmployees, () => _listenEmployees(createdBy));
    });
  }

  void _listenPresetItems(String createdBy) {
    _itemSub?.cancel();
    _itemSub = _firestore.presetItemsStream(createdBy).listen((snapshot) {
      _presetItems = snapshot.docs.map((doc) {
        return PresetItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _resetRestartBudget(_kPresetItems);
      notifyListeners();
    },
    onError: (e) {
      _error = friendlyError(e);
      notifyListeners();
      _scheduleRestart(_kPresetItems, () => _listenPresetItems(createdBy));
    });
  }

  Future<String?> addTask({
    required String title,
    String? description,
    required String assignedTo,
    required String assignedToEmail,
    String? customer,
    String? carOrThing,
    String? presetId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _error = 'Not signed in'; notifyListeners(); return null; }

      final task = AppTask(
        id: '',
        title: title,
        description: description,
        assignedTo: assignedTo,
        assignedToEmail: assignedToEmail,
        createdBy: user.email ?? 'unknown',
        createdAt: DateTime.now(),
        customer: customer,
        carOrThing: carOrThing,
        presetId: presetId,
        history: [HistoryEvent(action: 'created', by: user.email ?? 'unknown', at: DateTime.now())],
      );

      final taskId = await _firestore.addTask(task);
      final senderName = await _userService.getDisplayName(user.email ?? '');
      _notif.send(
        recipientEmail: assignedToEmail,
        type: 'task_assigned',
        title: _t('notify_task_assigned'),
        message: '"$title" ${_t('notif_task_assigned_msg')}',
        relatedId: taskId,
        senderName: senderName,
      );
      return taskId;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTaskField(String taskId, Map<String, dynamic> fields) async {
    try {
      await _firestore.updateTask(taskId, fields);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      _presetsError = _error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTaskDirectly({
    required String taskId,
    required Uint8List imageBytes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _error = 'Not signed in'; notifyListeners(); return false; }
      final photoUrl = await _storage.uploadImage(
        imageBytes,
        'task_photos/$taskId/proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await _firestore.updateTask(taskId, {
        'status': 'completed',
        'photoUrl': photoUrl,
        'completedAt': DateTime.now(),
        'approvedBy': user.email,
        'rejectionReason': null,
      });
      _addHistory(taskId, 'approved', user.displayName ?? user.email ?? '');
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        _notif.send(
          recipientEmail: task.assignedToEmail,
          type: 'task_approved',
          title: _t('notify_task_approved'),
          message: '"${task.title}" ${_t('notif_task_approved_msg')}',
          relatedId: taskId,
          senderName: await _userService.getDisplayName(user.email ?? ''),
        );
      }
      return true;
    } catch (e) {
      _error = friendlyError(e);
      _presetsError = _error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> claimTask(String taskId, String userEmail, String userName) async {
    try {
      await _firestore.updateTask(taskId, {
        'status': 'doing',
        'claimedBy': userEmail,
        'claimedByName': userName,
        'rejectionReason': null,
      });
      _addHistory(taskId, 'started', userName);
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        _notif.send(
          recipientEmail: task.createdBy,
          type: 'task_started',
          title: _t('notify_task_started'),
          message: '${_t('notif_task_started_msg')} "${task.title}"'.replaceAll('{name}', userName),
          relatedId: taskId,
          senderName: userName,
        );
      }
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTaskWithProof({
    required String taskId,
    required List<Uint8List> images,
    String? completionDescription,
    void Function(int completed, int total)? onProgress,
  }) async {
    final photoUrls = <String>[];
    _uploadCancelled = false;
    _cancelTaskId = null;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _error = 'Not signed in'; notifyListeners(); return false; }
      if (images.isNotEmpty) {
        await _firestore.updateTask(taskId, {
          'status': 'uploading',
          'photoUrl': null,
          'photoUrls': <String>[],
          'completionDescription': completionDescription,
          'uploadsComplete': false,
          'uploadCompleted': 0,
          'uploadTotal': images.length,
          'completedAt': null,
          'rejectionReason': null,
        });
        for (var i = 0; i < images.length; i++) {
          if (_uploadCancelled && _cancelTaskId == taskId) {
            // Employee pressed Stop: keep the photos uploaded so far, return
            // the task to 'doing' so its buttons come back.
            try {
              await _firestore.updateTask(taskId, {
                'status': 'doing',
                'uploadsComplete': true,
                'uploadCompleted': photoUrls.length,
                'uploadTotal': images.length,
              });
            } catch (_) {}
            return false;
          }
          final url = await _storage.uploadImage(
            images[i],
            'task_photos/$taskId/photo_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          photoUrls.add(url);
          onProgress?.call(i + 1, images.length);
          await _firestore.updateTask(taskId, {
            'photoUrls': photoUrls,
            'uploadCompleted': i + 1,
            'uploadTotal': images.length,
          });
        }
      }
      await _firestore.updateTask(taskId, {
        'status': 'pending_review',
        'photoUrl': photoUrls.isEmpty ? null : photoUrls.first,
        'photoUrls': photoUrls,
        'completionDescription': completionDescription,
        'uploadsComplete': true,
        'uploadCompleted': photoUrls.length,
        'uploadTotal': images.length,
        'completedAt': DateTime.now(),
        'rejectionReason': null,
      });
      _addHistory(taskId, 'submitted_proof', user.displayName ?? user.email ?? '');
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
      _notif.send(
        recipientEmail: task.createdBy,
        type: 'task_submitted',
        title: _t('notify_task_submitted'),
        message: '${_t('notif_task_submitted_msg')} "${task.title}"'.replaceAll('{name}', await _userService.getDisplayName(user.email ?? '')),
        relatedId: taskId,
        senderName: await _userService.getDisplayName(user.email ?? ''),
      );
      }
      return true;
    } catch (e) {
      // Roll the task back to 'doing' so the employee keeps their buttons and
      // the photos uploaded so far (the task is not left stuck in 'uploading').
      try {
        await _firestore.updateTask(taskId, {
          'status': 'doing',
          'uploadsComplete': true,
          'uploadCompleted': photoUrls.length,
          'uploadTotal': images.length,
        });
      } catch (_) {}
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveTask(String taskId, String approvedBy) async {
    try {
      await _firestore.updateTask(taskId, {
        'status': 'completed',
        'approvedBy': approvedBy,
        'rejectionReason': null,
      });
      _addHistory(taskId, 'approved', approvedBy);
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        _notif.send(
          recipientEmail: task.assignedToEmail,
          type: 'task_approved',
          title: _t('notify_task_approved'),
          message: '"${task.title}" ${_t('notif_task_approved_msg')}',
          relatedId: taskId,
          senderName: await _userService.getDisplayName(approvedBy),
        );
      }
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectTask(String taskId, {String? reason}) async {
    try {
      await _firestore.updateTask(taskId, {
        'status': 'doing',
        'photoUrl': null,
        'photoUrls': [],
        'uploadsComplete': true,
        'completedAt': null,
        'rejectionReason': reason,
      });
      _addHistory(taskId, 'rejected', reason ?? 'No reason given');
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        _notif.send(
          recipientEmail: task.assignedToEmail,
          type: 'task_rejected',
          title: _t('notify_task_rejected'),
          message: '"${task.title}" ${_t('notif_task_rejected_msg')}',
          relatedId: taskId,
          senderName: '',
        );
      }
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Employee pressed Stop during a photo upload: flags the running
  /// `completeTaskWithProof` loop to halt and immediately returns the task
  /// to 'doing' (photos uploaded so far are kept on the document).
  void cancelUpload(String taskId) {
    _cancelTaskId = taskId;
    _uploadCancelled = true;
    try {
      _firestore.updateTask(taskId, {
        'status': 'doing',
        'uploadsComplete': true,
      });
    } catch (_) {}
  }

  Future<bool> withdrawTaskSubmission(String taskId) async {
    try {
      await _firestore.updateTask(taskId, {
        'status': 'doing',
        'photoUrl': null,
        'photoUrls': [],
        'completionDescription': null,
        'completedAt': null,
        'uploadsComplete': true,
      });
      _addHistory(taskId, 'withdrawn', '');
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> reassignTask(String taskId, String newEmployee, String newEmail) async {
    try {
      await _firestore.updateTask(taskId, {
        'assignedTo': newEmployee,
        'assignedToEmail': newEmail,
        'claimedBy': null,
        'claimedByName': null,
        'status': 'pending',
        'photoUrl': null,
        'completedAt': null,
        'rejectionReason': null,
      });
      _addHistory(taskId, 'reassigned', 'to $newEmployee');
      _notif.send(
        recipientEmail: newEmail,
        type: 'task_assigned',
        title: _t('notify_task_reassigned'),
        message: _t('notif_task_reassigned_msg'),
        relatedId: taskId,
        senderName: '',
      );
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetTask(String taskId) async {
    try {
      await _firestore.updateTask(taskId, {
        'status': 'pending',
        'claimedBy': null,
        'claimedByName': null,
        'photoUrl': null,
        'completedAt': null,
        'rejectionReason': null,
      });
      _addHistory(taskId, 'reset', '');
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        _notif.send(
          recipientEmail: task.assignedToEmail,
          type: 'task_status_changed',
          title: _t('notify_task_status_changed'),
          message: '"${task.title}" ${_t('notif_task_status_changed_msg')}',
          relatedId: taskId,
          senderName: '',
        );
      }
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final updates = <String, dynamic>{'status': newStatus, 'rejectionReason': null};
      if (newStatus == 'completed') updates['completedAt'] = DateTime.now();
      await _firestore.updateTask(taskId, updates);
      _addHistory(taskId, 'status_change', newStatus);
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        _notif.send(
          recipientEmail: task.assignedToEmail,
          type: 'task_status_changed',
          title: _t('notify_task_status_changed'),
          message: '"${task.title}" → $newStatus',
          relatedId: taskId,
          senderName: '',
        );
      }
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> addPreset(PresetTask preset) async {
    try {
      await _firestore.addPreset(preset);
      _presetsError = null;
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePreset(String id) async {
    try {
      await _firestore.deletePreset(id);
      _presetsError = null;
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEmployeeName(String email, String newName) async {
    try {
      await _firestore.updateEmployee(email, {'name': newName});
      await _firestore.updateTasksByEmployee(email, {'assignedTo': newName});
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> addPresetItem(String name, String createdBy) async {
    try {
      await _firestore.addPresetItem(name, createdBy);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePresetItem(String id) async {
    try {
      await _firestore.deletePresetItem(id);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportProblem({
    required String reportedBy,
    required String reporterName,
    required String description,
    List<Uint8List> photos = const [],
    String? carOrThing,
    void Function(int completed, int total)? onProgress,
  }) async {
    try {
      final role = await _userService
          .getRole(FirebaseAuth.instance.currentUser?.uid ?? '');
      String? managerEmail;
      if (role == 'manager') {
        managerEmail = FirebaseAuth.instance.currentUser?.email;
      } else {
        managerEmail = await _firestore.managerEmailForEmployee(reportedBy);
      }
      if (managerEmail == null || managerEmail.isEmpty) {
        _error = 'Could not determine your manager. Ensure your account is set up with a manager.';
        _reportError = _error;
        notifyListeners();
        return false;
      }

      final photoUrls = await _storage.uploadImages(
        photos,
        'problem_photos/${reportedBy}_${DateTime.now().millisecondsSinceEpoch}',
        onProgress: onProgress,
      );
      await _firestore.addProblem({
        'reportedBy': reportedBy,
        'reporterName': reporterName,
        'description': description,
        'photoUrl': photoUrls.isEmpty ? null : photoUrls.first,
        'photoUrls': photoUrls,
        'carOrThing': carOrThing,
        'managerEmail': managerEmail,
        'createdAt': DateTime.now(),
        'status': 'open',
        'convertedToTaskId': null,
      });
      _notif.send(
        recipientEmail: managerEmail,
        type: 'problem_reported',
        title: _t('notify_problem_reported'),
        message: _t('notif_problem_reported_msg').replaceAll('{name}', reporterName),
        senderName: reporterName,
      );
      return true;
    } catch (e) {
      _error = friendlyError(e);
      _reportError = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> resolveProblem(String problemId, String taskId) async {
    try {
      await _firestore.updateProblem(problemId, {
        'status': 'resolved',
        'convertedToTaskId': taskId,
      });
    } catch (e) {
      _error = friendlyError(e);
      _presetsError = friendlyError(e);
      notifyListeners();
      return false;
    }
    final problem = _problems.where((p) => p.id == problemId).firstOrNull;
    if (problem != null && problem.reportedBy.isNotEmpty) {
      try {
        await _notif.send(
          recipientEmail: problem.reportedBy,
          type: 'problem_converted',
          title: _t('notify_problem_resolved'),
          message: _t('notif_problem_resolved_msg'),
          relatedId: taskId,
          senderName: '',
        );
      } catch (_) {}
    }
    return true;
  }

  Future<bool> assignProblem(String problemId, String taskId, String employeeName) async {
    try {
      await _firestore.updateProblem(problemId, {
        'status': 'assigned',
        'convertedToTaskId': taskId,
        'assignedToName': employeeName,
      });
    } catch (e) {
      _error = friendlyError(e);
      _presetsError = friendlyError(e);
      notifyListeners();
      return false;
    }
    final problem = _problems.where((p) => p.id == problemId).firstOrNull;
    if (problem != null && problem.reportedBy.isNotEmpty) {
      try {
        await _notif.send(
          recipientEmail: problem.reportedBy,
          type: 'problem_converted',
          title: _t('notify_problem_converted'),
          message: _t('notif_problem_converted_msg'),
          relatedId: taskId,
          senderName: '',
        );
      } catch (_) {}
    }
    return true;
  }

  /// Creates the task and changes the problem together from the UI's point of
  /// view. If the second write fails, remove the new task so the problem does
  /// not appear assigned without its converted task.
  Future<String?> convertProblemToTask({
    required Problem problem,
    required String employeeName,
    required String employeeEmail,
  }) async {
    final taskId = await addTask(
      title: problem.description.split('\n').first,
      description: problem.description,
      assignedTo: employeeName,
      assignedToEmail: employeeEmail,
      carOrThing: problem.carOrThing,
    );
    if (taskId == null) return null;
    if (await assignProblem(problem.id, taskId, employeeName)) return taskId;
    try {
      await _firestore.deleteTask(taskId);
    } catch (_) {}
    return null;
  }

  Future<void> exportToClipboard() async {
    String csvField(String value) => '"${value.replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    buffer.writeln('Title,Description,AssignedTo,Status,Created,Completed');
    for (final task in _tasks) {
      buffer.writeln([
        csvField(task.title),
        csvField(task.description ?? ''),
        csvField(task.assignedTo),
        csvField(task.status),
        csvField(task.createdAt.toIso8601String()),
        csvField(task.completedAt?.toIso8601String() ?? ''),
      ].join(','));
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  void _addHistory(String taskId, String action, String detail) {
    final user = FirebaseAuth.instance.currentUser;
    final event = HistoryEvent(
      action: action,
      by: user?.displayName ?? user?.email ?? 'unknown',
      detail: detail,
      at: DateTime.now(),
    );
    _firestore.appendHistory(taskId, event.toMap());
  }

  @override
  void dispose() {
    _resetRestartBudget();
    _taskSub?.cancel();
    _reviewSub?.cancel();
    _presetSub?.cancel();
    _problemSub?.cancel();
    _myProblemSub?.cancel();
    _employeeSub?.cancel();
    _itemSub?.cancel();
    super.dispose();
  }
}
