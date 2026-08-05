import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/providers/task_provider.dart';

import 'package:task_tracker/screens/report_problem_screen.dart';
import 'package:task_tracker/screens/settings_screen.dart';
import 'package:task_tracker/screens/task_detail_screen.dart';
import 'package:task_tracker/services/auth_service.dart';

import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/update_service.dart';

import 'package:task_tracker/widgets/task_card.dart';
import 'package:task_tracker/widgets/update_banner.dart';

class EmployeeTasksScreen extends StatefulWidget {
  const EmployeeTasksScreen({super.key});

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  String _taskFilter = 'active';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = AuthService().currentUser?.email ?? '';
      context.read<TaskProvider>().listenToEmployeeTasks(email);
      final us = UpdateService();
      us.isOnHomeScreen = true;
      us.setHomeContext(context);
      us.checkPendingRetry();
    });
  }

  @override
  void dispose() {
    final us = UpdateService();
    us.isOnHomeScreen = false;
    us.clearHomeContext();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppTask> _filterTasks(List<AppTask> tasks) {
    var filtered = tasks;
    if (_taskFilter == 'all') {}
    else if (_taskFilter == 'active') filtered = tasks.where((t) => !t.isCompleted).toList();
    else if (_taskFilter == 'pending') filtered = tasks.where((t) => t.isPending).toList();
    else if (_taskFilter == 'doing') filtered = tasks.where((t) => t.isDoing).toList();
    else if (_taskFilter == 'review') filtered = tasks.where((t) => t.isPendingReview).toList();
    else if (_taskFilter == 'completed') filtered = tasks.where((t) => t.isCompleted).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.assignedTo.toLowerCase().contains(q) ||
        (t.carOrThing?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final settings = context.watch<SettingsService>();
    final provider = context.watch<TaskProvider>();
    final t = settings.t;

    final allTasks = provider.tasks;
    final filtered = _filterTasks(allTasks);
    final incomplete = allTasks.where((t) => !t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('my_tasks')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                auth.currentUser?.email ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              context.read<TaskProvider>().stopListening();
              await auth.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          if (provider.loading && provider.error == null)
            const LinearProgressIndicator(),
          if (provider.employeeTasksError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Brand.problem.withAlpha(20),
                  borderRadius: BorderRadius.circular(Brand.radiusMd),
                  border: Border.all(color: Brand.problem.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(provider.employeeTasksError!,
                          style: TextStyle(color: Brand.problem)),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.clearEmployeeTasksError();
                        final email = AuthService().currentUser?.email ?? '';
                        provider.listenToEmployeeTasks(email);
                      },
                      child: const Text('Retry'),

                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty && allTasks.isEmpty
              ? provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.celebration_outlined,
                            size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Text(t('no_tasks_assigned'),
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (provider.employeeTasksError != null) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            provider.clearEmployeeTasksError();
                            final email =
                                AuthService().currentUser?.email ?? '';
                            provider.listenToEmployeeTasks(email);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: t('search'),
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _taskFilter,
                              isDense: true,
                              items: [
                                DropdownMenuItem(value: 'active', child: Text(t('filter_active'))),
                                DropdownMenuItem(value: 'all', child: Text(t('filter_all'))),
                                DropdownMenuItem(value: 'pending', child: Text(t('filter_pending'))),
                                DropdownMenuItem(value: 'doing', child: Text(t('filter_doing'))),
                                DropdownMenuItem(value: 'review', child: Text(t('filter_review'))),
                                DropdownMenuItem(value: 'completed', child: Text(t('filter_completed'))),
                              ],
                              onChanged: (v) => setState(() => _taskFilter = v ?? 'active'),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Brand.pending.withAlpha(15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${incomplete.length} ${t('tasks_pending')}',
                              style: TextStyle(
                                  color: Brand.pending,
                                  fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(t('no_tasks_assigned'),
                                  style: TextStyle(color: Colors.grey.shade600)),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                final email = AuthService().currentUser?.email ?? '';
                                context.read<TaskProvider>().listenToEmployeeTasks(email);
                              },
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final task = filtered[i];
                                  return TaskCard(
                                    task: task,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(
                                            task: task, isManager: false),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportProblemScreen()),
        ),
        child: const Icon(Icons.warning_amber),
      ),
    );
  }
}
