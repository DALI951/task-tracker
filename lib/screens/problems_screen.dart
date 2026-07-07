import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/models/problem.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/settings_service.dart';

class ProblemsScreen extends StatefulWidget {
  const ProblemsScreen({super.key});

  @override
  State<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends State<ProblemsScreen> {
  String _filter = 'open';

  List<Problem> _filtered(List<Problem> all) {
    if (_filter == 'all') return all;
    return all.where((p) => p.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsService>().t;
    final problems = _filtered(context.watch<TaskProvider>().problems);

    return Scaffold(
      appBar: AppBar(title: Text(t('problems'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filter,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: 'open', child: Text(t('filter_open'))),
                      DropdownMenuItem(value: 'all', child: Text(t('filter_all'))),
                      DropdownMenuItem(value: 'assigned', child: Text(t('filter_assigned'))),
                      DropdownMenuItem(value: 'resolved', child: Text(t('filter_resolved'))),
                    ],
                    onChanged: (v) => setState(() => _filter = v ?? 'open'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: problems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(t('no_problems'),
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: problems.length,
                    itemBuilder: (_, i) {
                      return _ProblemCard(problem: problems[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final Problem problem;
  const _ProblemCard({required this.problem});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsService>().t;
    final dateFormat = DateFormat('MMM d, yyyy · HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: problem.isOpen
                        ? Colors.red.shade100
                        : problem.isAssigned
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    problem.isOpen
                        ? t('open')
                        : problem.isAssigned
                            ? t('filter_assigned')
                            : t('resolved'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: problem.isOpen
                          ? Colors.red.shade800
                          : problem.isAssigned
                              ? Colors.blue.shade800
                              : Colors.green.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(problem.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(problem.reporterName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Text(problem.description, style: const TextStyle(fontSize: 14)),
            if (problem.carOrThing != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(problem.carOrThing!,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
            if (problem.photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(problem.photoUrl!),
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ],
            if (problem.isOpen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _convertToTask(context),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: Text(t('convert_to_task')),
                  ),
                ),
              ),
            if (problem.convertedToTaskId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  problem.isAssigned
                      ? '${t('filter_assigned')} →'
                      : '${t('resolved')} ✓',
                  style: TextStyle(
                      color: problem.isAssigned
                          ? Colors.blue.shade600
                          : Colors.green.shade600,
                      fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _convertToTask(BuildContext context) {
    final provider = context.read<TaskProvider>();
    final employees = provider.employees;
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedEmail;
        String? selectedName;
        return StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            title: Text(context.read<SettingsService>().t('convert_to_task')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${context.read<SettingsService>().t('description')}: ${problem.description}'),
                const SizedBox(height: 12),
                if (employees.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedEmail,
                    decoration: InputDecoration(
                      labelText: context.read<SettingsService>().t('employee_name'),
                      border: const OutlineInputBorder(),
                    ),
                    items: employees.map((e) => DropdownMenuItem(
                      value: e['email'] as String? ?? '',
                      child: Text(e['name'] as String? ?? ''),
                    )).toList(),
                    onChanged: (v) {
                      setDState(() {
                        selectedEmail = v;
                        selectedName = employees.firstWhere(
                          (e) => e['email'] == v,
                          orElse: () => {},
                        )['name'] as String?;
                      });
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.read<SettingsService>().t('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedEmail == null) return;
                  await provider.addTask(
                    title: problem.description.split('\n').first,
                    description: problem.description,
                    assignedTo: selectedName ?? selectedEmail!,
                    assignedToEmail: selectedEmail!,
                    customer: null,
                    carOrThing: problem.carOrThing,
                  );
                  await provider.resolveProblem(problem.id, taskId);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(context.read<SettingsService>().t('create')),
              ),
            ],
          ),
        );
      },
    );
  }
}
