import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/models/preset_task.dart';
import 'package:task_tracker/models/task.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _tasksRef => _db.collection('tasks');
  CollectionReference get _presetsRef => _db.collection('preset_tasks');
  CollectionReference get _employeesRef => _db.collection('employees');
  CollectionReference get _presetItemsRef => _db.collection('preset_items');
  CollectionReference get _problemsRef => _db.collection('problems');

  Future<String> addTask(AppTask task) async {
    final ref = _tasksRef.doc();
    await ref.set(task.toMap());
    return ref.id;
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await _tasksRef.doc(taskId).update(data);
  }

  Future<void> appendHistory(String taskId, Map<String, dynamic> event, {int cap = 50}) async {
    final docRef = _tasksRef.doc(taskId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final data = snap.data() as Map<String, dynamic>?;
      final history = List<Map<String, dynamic>>.from((data?['history'] as List?) ?? []);
      history.add(event);
      if (history.length > cap) {
        history.removeRange(0, history.length - cap);
      }
      txn.update(docRef, {'history': history});
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  Future<List<AppTask>> getAllTasksOnce({String? createdBy}) async {
    Query q = _tasksRef;
    if (createdBy != null) {
      q = q.where('createdBy', isEqualTo: createdBy);
    }
    final snap = await q.get();
    return snap.docs.map((doc) => AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<List<AppTask>> getTasksForEmployeeOnce(String email) async {
    final snap = await _tasksRef
        .where('assignedToEmail', isEqualTo: email)
        .get();
    return snap.docs.map((doc) => AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Stream<QuerySnapshot> allTasksStream(String createdBy) {
    return _tasksRef
        .where('createdBy', isEqualTo: createdBy)
        .snapshots();
  }

  Stream<QuerySnapshot> tasksForEmployee(String email) {
    return _tasksRef
        .where('assignedToEmail', isEqualTo: email)
        .snapshots();
  }

  Stream<QuerySnapshot> pendingReviewStream(String createdBy) {
    return _tasksRef
        .where('createdBy', isEqualTo: createdBy)
        .where('status', isEqualTo: 'pending_review')
        .snapshots();
  }

  Future<void> addPreset(PresetTask preset) async {
    await _presetsRef.add(preset.toMap());
  }

  Future<void> deletePreset(String id) async {
    await _presetsRef.doc(id).delete();
  }

  Stream<QuerySnapshot> presetsStream(String createdBy) {
    return _presetsRef
        .where('createdBy', isEqualTo: createdBy)
        .orderBy('name')
        .snapshots();
  }

  Future<void> updateEmployee(String email, Map<String, dynamic> data) async {
    await _employeesRef.doc(email).update(data);
  }

  Future<void> updateTasksByEmployee(String email, Map<String, dynamic> data) async {
    final snap = await _tasksRef.where('assignedToEmail', isEqualTo: email).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, data);
    }
    await batch.commit();
  }

  Stream<QuerySnapshot> employeesStream(String createdBy) {
    return _employeesRef
        .where('createdBy', isEqualTo: createdBy)
        .snapshots();
  }

  Future<void> addPresetItem(String name, String createdBy) async {
    await _presetItemsRef.add({'name': name, 'createdBy': createdBy});
  }

  Future<void> deletePresetItem(String id) async {
    await _presetItemsRef.doc(id).delete();
  }

  Stream<QuerySnapshot> presetItemsStream(String createdBy) {
    return _presetItemsRef
        .where('createdBy', isEqualTo: createdBy)
        .orderBy('name')
        .snapshots();
  }

  Future<void> addProblem(Map<String, dynamic> data) async {
    await _problemsRef.add(data);
  }

  Future<void> updateProblem(String id, Map<String, dynamic> data) async {
    await _problemsRef.doc(id).update(data);
  }

  Stream<QuerySnapshot> problemsStream(String managerEmail) {
    return _problemsRef
        .where('managerEmail', isEqualTo: managerEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
