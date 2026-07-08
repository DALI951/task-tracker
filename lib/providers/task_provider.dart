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
import 'package:task_tracker/services/storage_service.dart';
import 'package:task_tracker/utils/error_handler.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();

  List<AppTask> _tasks = [];
  List<AppTask> _pendingReview = [];
  List<PresetTask> _presets = [];
  List<Problem> _problems = [];
  List<Map<String, dynamic>> _employees = [];
  List<PresetItem> _presetItems = [];
  bool _loading = true;
  bool _connected = false;
  String? _error;
  StreamSubscription? _taskSub;
  StreamSubscription? _reviewSub;
  StreamSubscription? _presetSub;
  StreamSubscription? _problemSub;
  StreamSubscription? _employeeSub;
  StreamSubscription? _itemSub;

  List<AppTask> get tasks => _tasks;
  List<AppTask> get pendingReview => _pendingReview;
  List<PresetTask> get presets => _presets;
  List<Problem> get problems => _problems;
  List<Map<String, dynamic>> get employees => _employees;
  List<PresetItem> get presetItems => _presetItems;
  bool get loading => _loading;
  bool get connected => _connected;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
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
        if (a.isDoing) return -1;
        if (b.isDoing) return 1;
        if (a.isPendingReview) return -1;
        if (b.isPendingReview) return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  void stopListening() {
    _taskSub?.cancel();
    _taskSub = null;
    _reviewSub?.cancel();
    _reviewSub = null;
    _presetSub?.cancel();
    _presetSub = null;
    _problemSub?.cancel();
    _problemSub = null;
    _employeeSub?.cancel();
    _employeeSub = null;
    _itemSub?.cancel();
    _itemSub = null;
    _tasks = [];
    _pendingReview = [];
    _loading = true;
    notifyListeners();
  }

  void listenToAllTasks() {
    _taskSub?.cancel();
    _loading = true;
    _connected = false;
    _tasks = [];
    _error = null;
    notifyListeners();
    _taskSub = _firestore.allTasksStream.listen(
      (snapshot) {
        _tasks = _sortTasks(snapshot.docs.map((doc) {
          return AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList());
        _loading = false;
        _connected = true;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _connected = false;
        _error = friendlyError(e);
        notifyListeners();
      },
    );
    _listenPresets();
    _listenEmployees();
    _listenPresetItems();
  }

  void listenToEmployeeTasks(String email) {
    _taskSub?.cancel();
    _loading = email.isNotEmpty;
    _connected = false;
    _tasks = [];
    _error = null;
    notifyListeners();
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
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _connected = false;
        _error = friendlyError(e);
        notifyListeners();
      },
    );
  }

  void listenToPendingReview() {
    _reviewSub?.cancel();
    _reviewSub = _firestore.pendingReviewStream.listen(
      (snapshot) {
        _pendingReview = snapshot.docs.map((doc) {
          return AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        notifyListeners();
      },
      onError: (e) {
        _error = friendlyError(e);
        notifyListeners();
      },
    );
  }

  void listenToProblems() {
    _problemSub?.cancel();
    _problemSub = _firestore.problemsStream.listen(
      (snapshot) {
        _problems = snapshot.docs.map((doc) {
          return Problem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        notifyListeners();
      },
      onError: (e) {
        _error = friendlyError(e);
        notifyListeners();
      },
    );
  }

  void _listenPresets() {
    _presetSub?.cancel();
    _presetSub = _firestore.presetsStream.listen((snapshot) {
      _presets = snapshot.docs.map((doc) {
        return PresetTask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      notifyListeners();
    },
    onError: (e) {
      _error = friendlyError(e);
      notifyListeners();
    });
  }

  void _listenEmployees() {
    _employeeSub?.cancel();
    _employeeSub = _firestore.employeesStream.listen((snapshot) {
      _employees = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      notifyListeners();
    },
    onError: (e) {
      _error = friendlyError(e);
      notifyListeners();
    });
  }

  void _listenPresetItems() {
    _itemSub?.cancel();
    _itemSub = _firestore.presetItemsStream.listen((snapshot) {
      _presetItems = snapshot.docs.map((doc) {
        return PresetItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      notifyListeners();
    },
    onError: (e) {
      _error = friendlyError(e);
      notifyListeners();
    });
  }

  Future<bool> addTask({
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
      if (user == null) { _error = 'Not signed in'; notifyListeners(); return false; }

      final task = AppTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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

      await _firestore.addTask(task);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskField(String taskId, Map<String, dynamic> fields) async {
    try {
      await _firestore.updateTask(taskId, fields);
      return true;
    } catch (e) {
      _error = friendlyError(e);
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
      final photoBase64 = _storage.encodeImage(imageBytes);
      await _firestore.updateTask(taskId, {
        'status': 'completed',
        'photoUrl': photoBase64,
        'completedAt': DateTime.now(),
        'approvedBy': user.email,
      });
      _addHistory(taskId, 'approved', user.displayName ?? user.email ?? '');
      return true;
    } catch (e) {
      _error = friendlyError(e);
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
      });
      _addHistory(taskId, 'started', userName);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTaskWithProof({
    required String taskId,
    required Uint8List imageBytes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _error = 'Not signed in'; notifyListeners(); return false; }
      final photoBase64 = _storage.encodeImage(imageBytes);
      await _firestore.updateTask(taskId, {
        'status': 'pending_review',
        'photoUrl': photoBase64,
        'completedAt': DateTime.now(),
      });
      _addHistory(taskId, 'submitted_proof', user.displayName ?? user.email ?? '');
      return true;
    } catch (e) {
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
      });
      _addHistory(taskId, 'approved', approvedBy);
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
        'completedAt': null,
        'rejectionReason': reason,
      });
      _addHistory(taskId, 'rejected', reason ?? 'No reason given');
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
      });
      _addHistory(taskId, 'reassigned', 'to $newEmployee');
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
      });
      _addHistory(taskId, 'reset', '');
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final updates = <String, dynamic>{'status': newStatus};
      if (newStatus == 'completed') updates['completedAt'] = DateTime.now();
      await _firestore.updateTask(taskId, updates);
      _addHistory(taskId, 'status_change', newStatus);
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
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> addEmployee(String email, String name, String createdBy, {String? password}) async {
    try {
      await _firestore.addEmployee(email, name, createdBy, password: password);
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

  Future<bool> updateEmployeeField(String email, Map<String, dynamic> data) async {
    try {
      await _firestore.updateEmployee(email, data);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEmployee(String email) async {
    try {
      await _firestore.deleteEmployee(email);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getEmployee(String email) async {
    return await _firestore.getEmployee(email);
  }

  Future<bool> addPresetItem(String name) async {
    try {
      await _firestore.addPresetItem(name);
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
    String? photoUrl,
    String? carOrThing,
  }) async {
    try {
      await _firestore.addProblem({
        'reportedBy': reportedBy,
        'reporterName': reporterName,
        'description': description,
        'photoUrl': photoUrl,
        'carOrThing': carOrThing,
        'createdAt': DateTime.now(),
        'status': 'open',
        'convertedToTaskId': null,
      });
      return true;
    } catch (e) {
      _error = friendlyError(e);
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
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignProblem(String problemId, String taskId) async {
    try {
      await _firestore.updateProblem(problemId, {
        'status': 'assigned',
        'convertedToTaskId': taskId,
      });
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> exportToClipboard() async {
    final buffer = StringBuffer();
    buffer.writeln('Title,Description,AssignedTo,Status,Created,Completed');
    for (final task in _tasks) {
      buffer.writeln(
        '"${task.title}","${task.description ?? ''}","${task.assignedTo}","${task.status}","${task.createdAt.toIso8601String()}","${task.completedAt?.toIso8601String() ?? ''}"',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  void _addHistory(String taskId, String action, String detail) {
    final user = FirebaseAuth.instance.currentUser;
    final task = _tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    final event = HistoryEvent(
      action: action,
      by: user?.displayName ?? user?.email ?? 'unknown',
      detail: detail,
      at: DateTime.now(),
    );
    final updatedHistory = [...task.history, event];
    _firestore.updateTask(taskId, {
      'history': updatedHistory.map((e) => e.toMap()).toList(),
    });
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _reviewSub?.cancel();
    _presetSub?.cancel();
    _problemSub?.cancel();
    _employeeSub?.cancel();
    _itemSub?.cancel();
    super.dispose();
  }
}
