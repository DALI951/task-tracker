import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> setRole(String uid, String role) async {
    await _db.collection('users').doc(uid).set({
      'role': role,
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
    });
  }

  Future<String?> getRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role'] as String?;
  }

  Future<void> ensureManager(String uid, String email) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(uid).set({
        'role': 'manager',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> ensureEmployee(String uid, String email) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(uid).set({
        'role': 'employee',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> getDisplayName(String email) async {
    try {
      final snap = await _db.collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final name = snap.docs.first.data()['displayName'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    return email.split('@').first;
  }
}
