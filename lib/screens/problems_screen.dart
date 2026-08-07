import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/problem.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/utils/error_handler.dart';
import 'package:task_tracker/widgets/photo_viewer.dart';

class ProblemsScreen extends StatefulWidget {
  const ProblemsScreen({super.key});

  @override
  State<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends State<ProblemsScreen> {
  String _filter = 'all';

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
                       DropdownMenuItem(value: 'all', child: Text(t('filter_all'))),
                       DropdownMenuItem(value: 'open', child: Text(t('filter_open'))),
                       DropdownMenuItem(value: 'uploading', child: const Text('Uploading')),
                       DropdownMenuItem(value: 'assigned', child: Text(t('filter_assigned'))),
                    ],
                     onChanged: (v) => setState(() => _filter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<TaskProvider>().listenToProblems(
                  isManager:
                      context.read<SettingsService>().currentRole == 'manager',
                );
              },
              child: problems.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(Icons.check_circle_outline,
                                    size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 12),
                              Text(t('no_problems'),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: problems.length,
                      itemBuilder: (_, i) {
                        return _ProblemCard(problem: problems[i]);
                      },
                    ),
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

    final cs = Theme.of(context).colorScheme;
    Color statusBg, statusFg;
    String statusLabel;
    if (problem.isUploading && !problem.uploadsComplete) {
      statusBg = Colors.blue.withAlpha(25);
      statusFg = Colors.blue.shade700;
      final pct = problem.uploadProgress == null
          ? ''
          : ' · ${(problem.uploadProgress! * 100).round()}%';
      statusLabel = 'Uploading ${problem.uploadCompleted}/${problem.uploadTotal}$pct';
    } else if (problem.isUploading) {
      // uploadsComplete but never 'open' -> the send failed or was cut short.
      statusBg = Colors.orange.withAlpha(25);
      statusFg = Colors.orange.shade800;
      statusLabel = 'Interrupted';
    } else if (problem.isOpen) {
      statusBg = Brand.problem.withAlpha(25);
      statusFg = Brand.problem;
      statusLabel = t('open');
    } else if (problem.isAssigned) {
      statusBg = Brand.doing.withAlpha(25);
      statusFg = Brand.doing;
      statusLabel = t('filter_assigned');
    } else {
      statusBg = Brand.done.withAlpha(25);
      statusFg = Brand.done;
      statusLabel = t('resolved');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(problem.createdAt),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (problem.isUploading && !problem.uploadsComplete) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: problem.uploadProgress,
                  minHeight: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(problem.reporterName,
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 6),
            Text(problem.description,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            if (problem.carOrThing != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.directions_car,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(problem.carOrThing!,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
            if (problem.assignedToName != null) ...[
              const SizedBox(height: 6),
              Text('${t('assigned_to')}: ${problem.assignedToName}',
                  style: TextStyle(color: Brand.doing, fontWeight: FontWeight.w600)),
            ],
            if (problem.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: problem.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final photo = problem.photoUrls[i];
                    return GestureDetector(
                      onTap: () => PhotoViewer.show(context,
                          photos: problem.photoUrls, initialIndex: i),
                      child: Stack(children: [
                        RemotePhoto(url: photo, width: 90, height: 90),
                        PositionedDirectional(top: 3, start: 3, child: CircleAvatar(radius: 11, child: Text('${i + 1}'))),
                      ]),
                    );
                  },
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
                      color: problem.isAssigned ? Brand.doing : Brand.done,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
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

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedEmail;
        String? selectedName;
        var converting = false;
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
                    value: selectedEmail,
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
                onPressed: converting
                    ? null
                    : () async {
                        if (selectedEmail == null || converting) return;
                        setDState(() => converting = true);
                        final newTaskId = await provider.convertProblemToTask(
                          problem: problem,
                          employeeName: selectedName ?? selectedEmail!,
                          employeeEmail: selectedEmail!,
                        );
                        if (!ctx.mounted) return;
                        if (newTaskId == null) {
                          setDState(() => converting = false);
                          toast(ctx, provider.error ?? 'Failed to create task',
                              error: true);
                          return;
                        }
                        Navigator.pop(ctx);
                      },
                child: converting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.read<SettingsService>().t('create')),
              ),
            ],
          ),
        );
      },
    );
  }
}
