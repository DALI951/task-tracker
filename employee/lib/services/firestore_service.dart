import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> tasksForEmployee(String email) {
    return _db
        .collection('tasks')
        .where('assignedToEmail', isEqualTo: email)
        .snapshots();
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await _db.collection('tasks').doc(taskId).update(data);
  }

  Future<void> addProblem(Map<String, dynamic> data) async {
    await _db.collection('problems').add(data);
  }
}
