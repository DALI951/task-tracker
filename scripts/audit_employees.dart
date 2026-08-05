import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:task_tracker/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = FirebaseFirestore.instance;
  final snapshot = await db.collection('employees').get();

  print('=== EMPLOYEE AUDIT ===');
  print('Total employees: ${snapshot.docs.length}\n');

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final email = doc.id;
    final createdBy = data['createdBy'] as String?;
    final name = data['name'] as String? ?? 'N/A';
    final authUid = data['authUid'] as String? ?? 'N/A';

    print('Email: $email');
    print('  Name: $name');
    print('  createdBy: ${createdBy ?? 'MISSING ❌'}');
    print('  authUid: $authUid');
    print('');
  }

  final missingCreatedBy = snapshot.docs.where((d) => d.data()['createdBy'] == null).toList();
  if (missingCreatedBy.isNotEmpty) {
    print('⚠️  EMPLOYEES MISSING createdBy:');
    for (final doc in missingCreatedBy) {
      print('  - ${doc.id}');
    }
  } else {
    print('✅ All employees have createdBy field');
  }
}