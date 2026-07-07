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

  Future<void> addTask(AppTask task) async {
    await _tasksRef.doc(task.id).set(task.toMap());
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await _tasksRef.doc(taskId).update(data);
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  Future<List<AppTask>> getAllTasksOnce() async {
    final snap = await _tasksRef.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) => AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<List<AppTask>> getTasksForEmployeeOnce(String email) async {
    final snap = await _tasksRef
        .where('assignedToEmail', isEqualTo: email)
        .get();
    return snap.docs.map((doc) => AppTask.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Stream<QuerySnapshot> get allTasksStream {
    return _tasksRef.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> tasksForEmployee(String email) {
    return _tasksRef
        .where('assignedToEmail', isEqualTo: email)
        .snapshots();
  }

  Stream<QuerySnapshot> get pendingReviewStream {
    return _tasksRef
        .where('status', isEqualTo: 'pending_review')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addPreset(PresetTask preset) async {
    await _presetsRef.doc(preset.id).set(preset.toMap());
  }

  Future<void> deletePreset(String id) async {
    await _presetsRef.doc(id).delete();
  }

  Stream<QuerySnapshot> get presetsStream {
    return _presetsRef.orderBy('name').snapshots();
  }

  Future<void> addEmployee(String email, String name, String createdBy) async {
    await _employeesRef.doc(email).set({
      'email': email,
      'name': name,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  Future<void> deleteEmployee(String email) async {
    await _employeesRef.doc(email).delete();
  }

  Stream<QuerySnapshot> get employeesStream {
    return _employeesRef.orderBy('name').snapshots();
  }

  Future<Map<String, dynamic>?> getEmployee(String email) async {
    final doc = await _employeesRef.doc(email).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>?;
  }

  Future<void> addPresetItem(String name) async {
    await _presetItemsRef.add({'name': name});
  }

  Future<void> deletePresetItem(String id) async {
    await _presetItemsRef.doc(id).delete();
  }

  Stream<QuerySnapshot> get presetItemsStream {
    return _presetItemsRef.orderBy('name').snapshots();
  }

  Future<void> addProblem(Map<String, dynamic> data) async {
    await _problemsRef.add(data);
  }

  Future<void> updateProblem(String id, Map<String, dynamic> data) async {
    await _problemsRef.doc(id).update(data);
  }

  Stream<QuerySnapshot> get problemsStream {
    return _problemsRef.orderBy('createdAt', descending: true).snapshots();
  }
}
