import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker_employee/main.dart';
import 'package:task_tracker_employee/screens/report_problem_screen.dart';
import 'package:task_tracker_employee/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      context.read<EmployeeState>().listenToTasks(user!.email!);
    }
  }

  void _startTask(String taskId) async {
    final ok = await context.read<EmployeeState>().startTask(taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Task started' : 'Failed to start task')),
      );
    }
  }

  Future<void> _completeTask(String taskId) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (file == null) return;

    final bytes = await File(file.path).readAsBytes();
    final base64 = base64Encode(bytes);

    final ok = await context.read<EmployeeState>().completeTask(taskId, base64);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Task submitted for review' : 'Failed to submit')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmployeeState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Report Problem',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportProblemScreen(
                  onReport: (reportedBy, reporterName, description, photoUrl, carOrThing) =>
                      context.read<EmployeeState>().reportProblem(
                        reportedBy: reportedBy,
                        reporterName: reporterName,
                        description: description,
                        photoUrl: photoUrl,
                        carOrThing: carOrThing,
                      ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user?.email != null) {
                  context.read<EmployeeState>().listenToTasks(user!.email!);
                }
              },
              child: state.tasks.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.task_alt,
                                  size: 64, color: cs.onSurfaceVariant.withAlpha(100)),
                              const SizedBox(height: 12),
                              Text('No tasks assigned',
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: state.tasks.length,
                      itemBuilder: (_, i) {
                        final task = state.tasks[i];
                        final status = task['status'] as String? ?? 'pending';
                        final title = task['title'] as String? ?? '';
                        final description = task['description'] as String? ?? '';
                        final assignedTo = task['assignedTo'] as String? ?? '';

                        Color statusColor;
                        String statusLabel;
                        switch (status) {
                          case 'doing':
                            statusColor = Colors.orange;
                            statusLabel = 'In Progress';
                          case 'pending_review':
                            statusColor = Colors.blue;
                            statusLabel = 'Pending Review';
                          case 'completed':
                            statusColor = Colors.green;
                            statusLabel = 'Completed';
                          default:
                            statusColor = Colors.grey;
                            statusLabel = 'Pending';
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(title,
                                          style:
                                              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(statusLabel,
                                          style: TextStyle(
                                              color: statusColor, fontSize: 12)),
                                    ),
                                  ],
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(description,
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 14)),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 16, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(assignedTo,
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13)),
                                  ],
                                ),
                                if (status == 'pending') ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _startTask(task['id'] as String),
                                      icon: const Icon(Icons.play_arrow, size: 18),
                                      label: const Text('Start Task'),
                                    ),
                                  ),
                                ],
                                if (status == 'doing') ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _completeTask(task['id'] as String),
                                      icon: const Icon(Icons.camera_alt, size: 18),
                                      label: const Text('Take Photo & Complete'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
