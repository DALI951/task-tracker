import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker_admin/screens/create_account_screen.dart';
import 'package:task_tracker_admin/screens/users_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _managers = 0;
  int _employees = 0;
  int _tasks = 0;
  int _problems = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = FirebaseFirestore.instance;

    final usersSnap = await db.collection('users').get();
    int managers = 0;
    int employees = 0;
    for (final doc in usersSnap.docs) {
      final role = doc.data()['role'] as String? ?? '';
      if (role == 'manager') managers++;
      else if (role == 'employee') employees++;
    }

    final tasksSnap = await db.collection('tasks').get();
    final problemsSnap = await db.collection('problems').get();

    if (mounted) {
      setState(() {
        _managers = managers;
        _employees = employees;
        _tasks = tasksSnap.size;
        _problems = problemsSnap.size;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() { _loading = true; _loadStats(); }),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(title: 'Managers', value: '$_managers', icon: Icons.business_center, color: const Color(0xFF1565C0))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(title: 'Employees', value: '$_employees', icon: Icons.people, color: const Color(0xFF2E7D32))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(title: 'Tasks', value: '$_tasks', icon: Icons.task_alt, color: const Color(0xFFE65100))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(title: 'Problems', value: '$_problems', icon: Icons.report_problem, color: const Color(0xFFC62828))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _ActionCard(
                    title: 'Create Account',
                    subtitle: 'Add a new manager or employee',
                    icon: Icons.person_add,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CreateAccountScreen())),
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    title: 'View Users',
                    subtitle: 'See all managers and employees',
                    icon: Icons.people_outline,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const UsersListScreen())),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1565C0)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
