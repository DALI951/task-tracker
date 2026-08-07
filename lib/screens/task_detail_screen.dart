import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/screens/manage_employees_screen.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/user_service.dart';
import 'package:task_tracker/utils/error_handler.dart';
import 'package:task_tracker/utils/device_utils.dart';
import 'package:task_tracker/widgets/photo_viewer.dart';

class TaskDetailScreen extends StatefulWidget {
  final AppTask task;
  final bool isManager;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.isManager,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _uploading = false;
  int _uploadCompleted = 0;
  int _uploadTotal = 0;
  int _bytesSent = 0;
  int _totalBytes = 0;
  final List<XFile> _proofPhotos = [];
  late final TextEditingController _completionDescCtrl;

  @override
  void initState() {
    super.initState();
    _completionDescCtrl = TextEditingController(text: widget.task.completionDescription ?? '');
  }

  @override
  void dispose() {
    _completionDescCtrl.dispose();
    super.dispose();
  }

  String t(String key) => context.read<SettingsService>().t(key);

  Future<void> _claimTask() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final name = await UserService().getDisplayName(user.email ?? '');
    final ok = await context.read<TaskProvider>().claimTask(
          widget.task.id,
          user.email ?? '',
          name,
        );
    if (mounted) toast(context, ok ? t('task_started') : context.read<TaskProvider>().error ?? 'Failed');
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _pickProofPhoto() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty) return;
    final room = 50 - _proofPhotos.length;
    if (room <= 0) return;
    setState(() => _proofPhotos.addAll(picked.take(room)));
  }

  Future<void> _submitProof() async {
    if (_proofPhotos.isEmpty && _completionDescCtrl.text.trim().isEmpty) {
      toast(context, t('add_photo_or_description'), error: true);
      return;
    }
    final images = <Uint8List>[];
    for (final file in _proofPhotos) {
      images.add(await file.readAsBytes());
    }
    setState(() {
      _uploading = true;
      _uploadCompleted = 0;
      _uploadTotal = _proofPhotos.length;
      _bytesSent = 0;
      _totalBytes = images.fold<int>(0, (sum, b) => sum + b.length);
    });
    try {
      final ok = await context.read<TaskProvider>().completeTaskWithProof(
        taskId: widget.task.id,
        images: images,
        completionDescription: _completionDescCtrl.text.trim().isEmpty ? null : _completionDescCtrl.text.trim(),
        // Managers complete the task outright (no review step).
        approveDirectly: widget.isManager,
        onProgress: (done, total) {
          if (mounted) setState(() {
            _uploadCompleted = done;
            _uploadTotal = total;
          });
        },
        onByteProgress: (sent, total) {
          if (mounted) setState(() {
            _bytesSent = sent;
            _totalBytes = total;
          });
        },
      );
      if (!mounted) return;
      final provider = context.read<TaskProvider>();
      if (ok) {
        toast(context, t('task_completed'));
        Navigator.pop(context);
      } else if (provider.lastUploadCancelled) {
        toast(context, t('upload_stopped'));
      } else {
        toast(context, provider.error ?? t('failed'), error: true);
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _approveTask() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final ok = await context.read<TaskProvider>().approveTask(widget.task.id, user.email ?? '');
    if (mounted) toast(context, ok ? t('approved') : context.read<TaskProvider>().error ?? t('failed'),
        error: !ok);
  }

  Future<void> _withdrawSubmission() async {
    final ok = await context.read<TaskProvider>().withdrawTaskSubmission(widget.task.id);
    if (mounted) toast(context, ok ? t('saved') : context.read<TaskProvider>().error ?? t('failed'), error: !ok);
  }

  void _stopUpload() {
    context.read<TaskProvider>().cancelUpload(widget.task.id);
    if (mounted) toast(context, t('upload_stopped'));
  }

  Future<void> _rejectWithReason() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('reject_reason')),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
             hintText: 'Explain what needs fixing. You can reference photo numbers, for example: photos 2 and 4.',
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: Text(t('reject')),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    final ok = await context.read<TaskProvider>().rejectTask(widget.task.id, reason: reason);
    if (mounted) toast(context, ok ? t('rejected') : context.read<TaskProvider>().error ?? t('failed'),
        error: !ok);
  }

  Future<void> _showEditDialog() async {
    final titleCtrl = TextEditingController(text: widget.task.title);
    final descCtrl = TextEditingController(text: widget.task.description ?? '');
    final employees = context.read<TaskProvider>().employees;
    String? selectedEmail = widget.task.assignedToEmail;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(t('edit_task')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: t('title'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: t('description'), border: const OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedEmail,
                  decoration: InputDecoration(labelText: t('employee_name'), border: const OutlineInputBorder()),
                  items: employees.map((e) => DropdownMenuItem(
                    value: e['email'] as String? ?? '',
                    child: Text(e['name'] as String? ?? ''),
                  )).toList(),
                  onChanged: (v) => setDState(() => selectedEmail = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('save'))),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
    if (result != true || !mounted) return;

    final updates = <String, dynamic>{};
    if (titleCtrl.text.trim().isNotEmpty && titleCtrl.text.trim() != widget.task.title) {
      updates['title'] = titleCtrl.text.trim();
    }
    if (descCtrl.text.trim() != (widget.task.description ?? '')) {
      updates['description'] = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
    }
    if (selectedEmail != null && selectedEmail != widget.task.assignedToEmail) {
      final emp = employees.firstWhere((e) => e['email'] == selectedEmail, orElse: () => {});
      updates['assignedTo'] = emp['name'] as String? ?? '';
      updates['assignedToEmail'] = selectedEmail;
      updates['claimedBy'] = null;
      updates['claimedByName'] = null;
      if (widget.task.isDoing) updates['status'] = 'pending';
    }
    if (updates.isNotEmpty) {
      final ok = await context.read<TaskProvider>().updateTaskField(widget.task.id, updates);
      if (mounted) toast(context, ok ? t('saved') : context.read<TaskProvider>().error ?? t('failed'),
          error: !ok);
    }
  }

  Future<void> _showReassignDialog() async {
    final employees = context.read<TaskProvider>().employees;
    if (employees.isEmpty) {
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('no_employees')),
          content: Text(t('create_employee_first')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('create_employee')),
            ),
          ],
        ),
      );
      if (create == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageEmployeesScreen()),
        );
      }
      return;
    }
    String? selectedEmail;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(t('reassign')),
          content: DropdownButtonFormField<String>(
            value: null,
            decoration: InputDecoration(
              labelText: t('employee_name'),
              border: const OutlineInputBorder(),
            ),
            items: employees.map((e) => DropdownMenuItem(
              value: e['email'] as String? ?? '',
              child: Text(e['name'] as String? ?? ''),
            )).toList(),
            onChanged: (v) => setDState(() => selectedEmail = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, selectedEmail), child: Text(t('reassign'))),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final emp = employees.firstWhere((e) => e['email'] == result, orElse: () => {});
      final ok = await context.read<TaskProvider>().reassignTask(
            widget.task.id,
            emp['name'] as String? ?? '',
            result,
          );
      if (mounted) toast(context, ok ? t('reassigned') : context.read<TaskProvider>().error ?? t('failed'),
          error: !ok);
    }
  }

  Future<void> _resetTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('reset_task')),
        content: Text(t('reset_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('reset_task'))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await context.read<TaskProvider>().resetTask(widget.task.id);
      if (mounted) toast(context, ok ? t('task_reset') : context.read<TaskProvider>().error ?? t('failed'),
          error: !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so upload progress (photo X/Y) updates live on this
    // screen while the task document is being written per photo.
    final task = context.watch<TaskProvider>().tasks
            .where((t) => t.id == widget.task.id)
            .firstOrNull ??
        widget.task;
    final dateFormat = DateFormat('MMM d, yyyy · HH:mm');
    final userEmail = AuthService().currentUser?.email ?? '';
    final cs = Theme.of(context).colorScheme;

    final canStart =
        task.isPending && !widget.isManager && task.assignedToEmail == userEmail;
    final canComplete = task.isDoing && task.claimedBy == userEmail;
    final canCompleteAsManager =
        widget.isManager && (task.isPending || task.isDoing);
    final canUseCompletionPanel = canComplete || canCompleteAsManager;

    // If the background upload stopped (no internet, timeout, server error),
    // surface the reason + Retry. Retry re-uses the same session, so photos
    // already uploaded are not re-uploaded.
    final uploadStoppedReason =
        context.watch<TaskProvider>().sessionErrors[task.id];

    // Smooth local byte progress while this screen is submitting; the
    // document's per-photo counters otherwise (task card, other device).
    final localFraction = _totalBytes == 0
        ? null
        : (_bytesSent / _totalBytes).clamp(0.0, 1.0);
    final displayFraction = _uploading ? localFraction : task.uploadProgress;
    String pctLabel(double? fraction) =>
        fraction == null ? '' : ' · ${(fraction * 100).round()}%';

    return Scaffold(
      appBar: AppBar(
        title: Text(task.isUploading
            ? '${t('uploading')} (${task.uploadCompleted}/${task.uploadTotal})'
            : task.isCompleted
                ? t('completed')
                : task.isPendingReview
                    ? t('pending_review')
                    : task.isDoing
                        ? t('doing')
                        : t('pending')),
        actions: [
          if (widget.isManager && !task.isCompleted)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: t('edit_task'),
              onPressed: _showEditDialog,
            ),
          if (widget.isManager && task.isCompleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: t('reset_task'),
              onPressed: _resetTask,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.paddingOf(context).bottom + 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? cs.outline : cs.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                _statusChip(task),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(context, Icons.person_outline, '${t('assigned_to')}: ${task.assignedTo}'),
            const SizedBox(height: 6),
            _infoRow(context, Icons.calendar_today, '${t('created')}: ${dateFormat.format(task.createdAt)}'),
            if (task.completedAt != null) ...[
              const SizedBox(height: 6),
              _infoRow(context, Icons.check_circle_outline, '${t('completed')}: ${dateFormat.format(task.completedAt!)}',
                  color: Brand.done),
            ],
            if (task.claimedByName != null) ...[
              const SizedBox(height: 6),
              _infoRow(context, Icons.person_pin, '${t('claimed_by')}: ${task.claimedByName}',
                  color: Brand.doing),
            ],
            if (task.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Brand.problem.withAlpha(20),
                  borderRadius: BorderRadius.circular(Brand.radiusSm),
                  border: Border.all(color: Brand.problem.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Brand.problem, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${t('rejection_reason')}: ${task.rejectionReason}',
                          style: TextStyle(color: Brand.problem)),
                    ),
                  ],
                ),
              ),
            ],
            if (task.carOrThing != null) ...[
              const SizedBox(height: 6),
              _infoRow(context, Icons.directions_car, '${t('car_thing')}: ${task.carOrThing}'),
            ],
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(Brand.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('description'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  task.description != null
                      ? Text(task.description!, style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant))
                      : Text(t('no_description'),
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            if (task.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(t('proof_photo'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                   children: task.photoUrls.asMap().entries.map((entry) => GestureDetector(
                   onTap: () => PhotoViewer.show(context,
                       photos: task.photoUrls, initialIndex: entry.key),
                   child: Stack(
                   children: [
                     RemotePhoto(
                       url: entry.value,
                       width: 150,
                       height: 150,
                       borderRadius: const BorderRadius.all(Radius.circular(Brand.radiusMd)),
                     ),
                     PositionedDirectional(top: 4, start: 4, child: CircleAvatar(radius: 12, child: Text('${entry.key + 1}'))),
                   ],
                 ))).toList(),
               ),
            ],
            if (task.completionDescription != null) ...[
              const SizedBox(height: 20),
              Text(t('description'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(60),
                  borderRadius: BorderRadius.circular(Brand.radiusMd),
                ),
                child: Text(task.completionDescription!,
                    style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
              ),
            ],
            if (task.history.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(t('history'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              ...task.history.reversed.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: cs.outlineVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_historyLabel(e.action)} ${t('by')} ${e.by}${e.detail != null && e.detail!.isNotEmpty ? ' — ${e.detail}' : ''}',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 24),
            if (task.isUploading && uploadStoppedReason != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Brand.problem.withAlpha(15),
                  borderRadius: BorderRadius.circular(Brand.radiusMd),
                  border: Border.all(color: Brand.problem.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.error_outline, size: 20, color: Brand.problem),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${t('upload_stopped_title')}: $uploadStoppedReason',
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.read<TaskProvider>().retryUpload(task.id, isProblem: false),
                        icon: const Icon(Icons.refresh),
                        label: Text(t('retry')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _stopUpload,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(t('stop_upload')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (task.isUploading) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(15),
                  borderRadius: BorderRadius.circular(Brand.radiusMd),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_upload,
                            size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: displayFraction ?? task.uploadProgress,
                              minHeight: 6,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${task.uploadCompleted}/${task.uploadTotal}'
                          '${pctLabel(displayFraction ?? task.uploadProgress)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t('uploading')} ${t('proof_photo')}…',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _stopUpload,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(t('stop_upload')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (canStart)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _claimTask,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(t('start_task')),
                ),
              ),
            if (canUseCompletionPanel)
              _completionPanel(task, pctLabel),
            if (widget.isManager && task.isPendingReview) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                         onPressed: task.uploadsComplete ? _approveTask : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Brand.done,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
                        label: Text(t('approve')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                         onPressed: task.uploadsComplete ? _rejectWithReason : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Brand.problem,
                          side: BorderSide(color: Brand.problem.withAlpha(100)),
                        ),
                        icon: const Icon(Icons.close),
                        label: Text(t('reject')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!widget.isManager && task.isPendingReview)
              OutlinedButton.icon(
                onPressed: _uploading ? null : _withdrawSubmission,
                icon: const Icon(Icons.undo),
                label: Text(t('withdraw_submission')),
              ),
            if (widget.isManager && !task.isCompleted && !task.isPendingReview && !task.isUploading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showReassignDialog,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(t('reassign')),
                  ),
                ),
              ),
            if (widget.isManager && !task.isUploading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: task.status,
                    decoration: InputDecoration(
                      labelText: t('status'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'doing', child: Text('In Progress')),
                      DropdownMenuItem(value: 'pending_review', child: Text('Pending Review')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (v) async {
                      if (v == null || v == task.status) return;
                      final ok = await context.read<TaskProvider>().updateTaskStatus(task.id, v);
                      if (mounted) toast(context, ok ? t('saved') : (context.read<TaskProvider>().error ?? t('failed')));
                    },
                  ),
                ),
              ),
            if (task.isCompleted && !widget.isManager)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 48, color: Brand.done),
                      const SizedBox(height: 8),
                      Text(t('task_completed'), style: TextStyle(color: Brand.done)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: color ?? cs.onSurfaceVariant)),
      ],
    );
  }

  /// Completion form shared by employees (submits for review) and managers
  /// (completes the task directly): description + multiple photos with a
  /// smooth byte-level progress bar while sending.
  Widget _completionPanel(AppTask task, String Function(double?) pctLabel) {
    final cs = Theme.of(context).colorScheme;
    final localFraction = _totalBytes == 0
        ? null
        : (_bytesSent / _totalBytes).clamp(0.0, 1.0);
    return Column(children: [
      if (_uploading)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: LinearProgressIndicator(value: localFraction)),
            const SizedBox(width: 8),
            Text(
              'Photo $_uploadCompleted/$_uploadTotal${pctLabel(localFraction)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      TextField(controller: _completionDescCtrl, maxLines: 2,
        decoration: InputDecoration(labelText: '${t('description')} (optional with photos)', border: const OutlineInputBorder())),
      const SizedBox(height: 8),
      if (_proofPhotos.isNotEmpty) ...[
        _proofPhotoEditor(),
        const SizedBox(height: 8),
      ],
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _uploading || _proofPhotos.length >= 50 ? null : _pickProofPhoto,
          icon: const Icon(Icons.add_photo_alternate), label: Text('Photos (${_proofPhotos.length}/50)'))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(onPressed: _uploading ? null : _submitProof,
        icon: _uploading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_circle_outline),
        label: Text(_uploading ? t('uploading') : (widget.isManager ? t('complete') : t('send'))))),
      ]),
    ]);
  }

  Widget _proofPhotoEditor() => SizedBox(
    height: 84,
    child: ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _proofPhotos.length,
      onReorder: (oldIndex, newIndex) => setState(() {
        if (newIndex > oldIndex) newIndex--;
        final photo = _proofPhotos.removeAt(oldIndex);
        _proofPhotos.insert(newIndex, photo);
      }),
      itemBuilder: (_, i) => Padding(
        key: ValueKey(_proofPhotos[i].path),
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Stack(children: [
          LazyPhotoThumb(file: _proofPhotos[i], size: 84),
          PositionedDirectional(top: 0, end: 0, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _proofPhotos.removeAt(i)))),
          PositionedDirectional(bottom: 2, start: 2, child: CircleAvatar(radius: 10, child: Text('${i + 1}', style: const TextStyle(fontSize: 11)))),
        ]),
      ),
    ),
  );

  String _historyLabel(String action) {
    switch (action) {
      case 'created': return t('created');
      case 'started': return t('started');
      case 'submitted_proof': return t('submitted_proof');
      case 'approved': return t('approved');
      case 'status_change': return t('status_change');
      case 'rejected': return t('rejected');
      case 'reassigned': return t('reassigned');
      case 'reset': return t('reset_task');
      default: return action;
    }
  }

  Widget _statusChip(AppTask task) {
    Color bg, fg;
    IconData icon;
    String label;
    if (task.isUploading) {
      bg = Colors.blue.withAlpha(25);
      fg = Colors.blue.shade700;
      icon = Icons.cloud_upload;
      final pct = task.uploadProgress == null
          ? ''
          : ' · ${(task.uploadProgress! * 100).round()}%';
      label = '${t('uploading')} ${task.uploadCompleted}/${task.uploadTotal}$pct';
    } else if (task.isCompleted) {
      bg = Brand.done.withAlpha(25);
      fg = Brand.done;
      icon = Icons.check_circle;
      label = t('done');
    } else if (task.isPendingReview) {
      bg = Brand.pendingReview.withAlpha(25);
      fg = Brand.pendingReview;
      icon = Icons.rate_review;
      label = t('pending_review');
    } else if (task.isDoing) {
      bg = Brand.doing.withAlpha(25);
      fg = Brand.doing;
      icon = Icons.hourglass_top;
      label = t('doing');
    } else {
      bg = Brand.pending.withAlpha(25);
      fg = Brand.pending;
      icon = Icons.hourglass_empty;
      label = t('pending');
    }
    return Chip(
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      side: BorderSide.none,
      avatar: Icon(icon, size: 18, color: fg),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
