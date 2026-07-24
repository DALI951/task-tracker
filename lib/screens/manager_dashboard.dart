import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/screens/manage_employees_screen.dart';
import 'package:task_tracker/screens/preset_items_screen.dart';
import 'package:task_tracker/screens/problems_screen.dart';
import 'package:task_tracker/screens/settings_screen.dart';
import 'package:task_tracker/screens/task_detail_screen.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/update_service.dart';

import 'package:task_tracker/utils/error_handler.dart';
import 'package:task_tracker/widgets/task_card.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  String? _selectedPresetId;
  String? _selectedEmployeeEmail;
  String? _selectedCarOrThing;
  String _taskFilter = 'active';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().listenToAllTasks();
      context.read<TaskProvider>().listenToProblems();
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
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCreateTaskDialog() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _selectedPresetId = null;
    _selectedEmployeeEmail = null;
    _selectedCarOrThing = null;

    UpdateService().suppressUpdates = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final presets = context.read<TaskProvider>().presets;
          final employees = context.read<TaskProvider>().employees;
          final items = context.read<TaskProvider>().presetItems;
          final t = context.read<SettingsService>().t;
          return AlertDialog(
            title: Text(t('new_task')),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (presets.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPresetId,
                        decoration: InputDecoration(
                          labelText: t('preset_task'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(t('custom_task')),
                          ),
                          ...presets.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              )),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            _selectedPresetId = v;
                            if (v != null) {
                              final preset =
                                  presets.firstWhere((p) => p.id == v);
                              _titleCtrl.text = preset.name;
                              _descCtrl.text = preset.defaultDescription ?? '';
                            } else {
                              _titleCtrl.text = '';
                              _descCtrl.text = '';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: '${t('title')} *',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        labelText: t('description'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    if (employees.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedEmployeeEmail,
                          decoration: InputDecoration(
                            labelText: t('employee_name'),
                            border: const OutlineInputBorder(),
                          ),
                          items: employees.map((e) => DropdownMenuItem(
                            value: e['email'] as String? ?? '',
                            child: Text(e['name'] as String? ?? ''),
                          )).toList(),
                          onChanged: (v) {
                            setDialogState(() => _selectedEmployeeEmail = v);
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                    if (employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(t('no_employees'),
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    if (_selectedPresetId == null ||
                        presets.firstWhere((p) => p.id == _selectedPresetId).requireCarOrThing)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCarOrThing,
                        decoration: InputDecoration(
                          labelText: t('car_thing'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text(t('none'))),
                          ...items.map((i) => DropdownMenuItem(
                                value: i.name,
                                child: Text(i.name),
                              )),
                        ],
                        onChanged: (v) {
                          setDialogState(() => _selectedCarOrThing = v);
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  UpdateService().suppressUpdates = false;
                  Navigator.pop(ctx);
                },
                child: Text(t('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final emp = employees.firstWhere(
                    (e) => e['email'] == _selectedEmployeeEmail,
                    orElse: () => {},
                  );
                  final ok = await context.read<TaskProvider>().addTask(
                        title: _titleCtrl.text.trim(),
                        description: _descCtrl.text.trim().isEmpty
                            ? null
                            : _descCtrl.text.trim(),
                        assignedTo: emp['name'] as String? ?? '',
                        assignedToEmail: emp['email'] as String? ?? '',
                        carOrThing: _selectedCarOrThing,
                        presetId: _selectedPresetId,
                      );
                  if (ctx.mounted) {
                    UpdateService().suppressUpdates = false;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      toast(context, context.read<TaskProvider>().error ?? t('failed'), error: true);
                    }
                  }
                },
                child: Text(t('create')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final settings = context.watch<SettingsService>();
    final provider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('manager_dashboard')),
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
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'employees') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManageEmployeesScreen()));
              } else if (v == 'items') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PresetItemsScreen()));
              } else if (v == 'settings') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'employees',
                child: Row(children: [
                  const Icon(Icons.people_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(settings.t('manage_employees')),
                ]),
              ),
              PopupMenuItem(
                value: 'items',
                child: Row(children: [
                  const Icon(Icons.list_alt, size: 20),
                  const SizedBox(width: 8),
                  Text(settings.t('manage_items')),
                ]),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  const Icon(Icons.settings, size: 20),
                  const SizedBox(width: 8),
                  Text(settings.t('settings')),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              provider.stopListening();
              await auth.signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: settings.t('tasks_tab')),
            Tab(text: settings.t('problems_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(settings, provider),
          const ProblemsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTasksTab(SettingsService settings, TaskProvider provider) {
    final t = settings.t;
    final allTasks = provider.tasks;
    final filtered = _filterTasks(allTasks);

    final total = allTasks.length;
    final pending = allTasks.where((x) => x.isPending).length;
    final doing = allTasks.where((x) => x.isDoing).length;
    final review = allTasks.where((x) => x.isPendingReview).length;
    final completed = allTasks.where((x) => x.isCompleted).length;
    final problemCount = provider.problems.where((p) => p.status == 'open' || p.status == 'assigned').length;

    if (filtered.isEmpty && allTasks.isEmpty) {
      if (provider.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.inbox, size: 36, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(t('no_tasks'),
                style: TextStyle(
                    fontSize: 16, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _showCreateTaskDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(t('create_first_task')),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (!provider.connected && !provider.loading)
          const LinearProgressIndicator(),
        if (provider.loading)
          const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _statCard(t('total_tasks'), total.toString(), Colors.blue),
                _statCard(t('pending'), pending.toString(), Colors.orange),
                _statCard(t('doing'), doing.toString(), Colors.blue.shade300),
                _statCard(t('pending_review'), review.toString(), Colors.purple),
                _statCard(t('done'), completed.toString(), Colors.green),
                _statCard(t('open_problems'), problemCount.toString(), Colors.red),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  '${allTasks.where((t) => !t.isCompleted).length} ${t('tasks_pending')}',
                  style: TextStyle(color: Brand.pending, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(t('no_tasks'),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                provider.listenToAllTasks();
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
                        builder: (_) =>
                            TaskDetailScreen(task: task, isManager: true),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      width: 100,
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
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
}
