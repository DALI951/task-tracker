import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          final docs = snapshot.data!.docs;
          final managers = <QueryDocumentSnapshot>[];
          final employees = <QueryDocumentSnapshot>[];
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final role = data['role'] as String? ?? '';
            if (role == 'manager') {
              managers.add(doc);
            } else {
              employees.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (managers.isNotEmpty) ...[
                _sectionHeader('Managers (${managers.length})'),
                const SizedBox(height: 8),
                ...managers.map((doc) => _UserTile(
                      doc: doc,
                      onTap: () => _showManagerDetail(context, doc),
                    )),
                const SizedBox(height: 16),
              ],
              if (employees.isNotEmpty) ...[
                _sectionHeader('Employees (${employees.length})'),
                const SizedBox(height: 8),
                ...employees.map((doc) => _UserTile(doc: doc)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }

  void _showManagerDetail(BuildContext context, QueryDocumentSnapshot managerDoc) {
    final data = managerDoc.data() as Map<String, dynamic>;
    final managerEmail = data['email'] as String? ?? '';
    final managerName = data['displayName'] as String? ?? managerEmail;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ManagerDetailScreen(
          managerId: managerDoc.id,
          managerName: managerName,
          managerEmail: managerEmail,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback? onTap;

  const _UserTile({required this.doc, this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final email = data['email'] as String? ?? '';
    final name = data['displayName'] as String? ?? email;
    final role = data['role'] as String? ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: role == 'manager'
              ? const Color(0xFF1565C0).withAlpha(20)
              : const Color(0xFF2E7D32).withAlpha(20),
          child: Icon(
            role == 'manager' ? Icons.business_center : Icons.person,
            color: role == 'manager'
                ? const Color(0xFF1565C0)
                : const Color(0xFF2E7D32),
            size: 20,
          ),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: role == 'manager'
                    ? const Color(0xFF1565C0).withAlpha(15)
                    : const Color(0xFF2E7D32).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: role == 'manager'
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManagerDetailScreen extends StatelessWidget {
  final String managerId;
  final String managerName;
  final String managerEmail;

  const _ManagerDetailScreen({
    required this.managerId,
    required this.managerName,
    required this.managerEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(managerName),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('employees')
            .where('managerId', isEqualTo: managerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No employees assigned',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text('Manager: $managerEmail',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manager Info',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text(managerName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(managerEmail,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Employees (${docs.length})',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final email = data['email'] as String? ?? '';
                final name = data['displayName'] as String? ?? email;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2E7D32).withAlpha(20),
                      child: const Icon(Icons.person,
                          color: Color(0xFF2E7D32), size: 20),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(email,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
