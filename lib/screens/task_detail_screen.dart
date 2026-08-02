import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/storage_service.dart';
import 'package:task_tracker/services/user_service.dart';
import 'package:task_tracker/utils/error_handler.dart';

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

  Future<void> _pickAndSubmitProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: kIsWeb || defaultTargetPlatform != TargetPlatform.android
          ? ImageSource.gallery
          : ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      if (!mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final ok = await context.read<TaskProvider>().completeTaskWithProof(
            taskId: widget.task.id,
            imageBytes: bytes,
          );
      if (mounted) {
        toast(context, ok ? t('task_completed') : context.read<TaskProvider>().error ?? t('failed'),
            error: !ok);
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _completeAsManager() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: kIsWeb || defaultTargetPlatform != TargetPlatform.android
          ? ImageSource.gallery
          : ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      if (!mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final ok = await context.read<TaskProvider>().completeTaskDirectly(
            taskId: widget.task.id,
            imageBytes: bytes,
          );
      if (mounted) {
        toast(context, ok ? t('task_completed') : context.read<TaskProvider>().error ?? t('failed'),
            error: !ok);
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

  Future<void> _rejectWithReason() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('reject_reason')),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            hintText: t('reject_reason_hint'),
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

  void _showPhotoGallery() {
    if (widget.task.photoUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: StorageService.isRemotePhoto(widget.task.photoUrl!)
                    ? Image.network(
                        widget.task.photoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white54, size: 64)),
                      )
                    : Image.memory(
                        base64Decode(widget.task.photoUrl!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white54, size: 64)),
                      ),
              ),
            ),
            PositionedDirectional(
              top: 40,
              end: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReassignDialog() async {
    final employees = context.read<TaskProvider>().employees;
    if (employees.isEmpty) return;
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
    final task = widget.task;
    final dateFormat = DateFormat('MMM d, yyyy · HH:mm');
    final userEmail = AuthService().currentUser?.email ?? '';
    final cs = Theme.of(context).colorScheme;

    final canStart =
        task.isPending && !widget.isManager && task.assignedToEmail == userEmail;
    final canComplete =
        task.isDoing && task.claimedBy == userEmail;
    final canCompleteAsManager =
        widget.isManager && (task.isPending || task.isDoing);

    return Scaffold(
      appBar: AppBar(
        title: Text(task.isCompleted
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
        padding: const EdgeInsets.all(16),
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
            if (task.photoUrl != null) ...[
              const SizedBox(height: 20),
              Text(t('proof_photo'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showPhotoGallery,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Brand.radiusMd),
                  child: StorageService.isRemotePhoto(task.photoUrl!)
                      ? Image.network(
                          task.photoUrl!,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: cs.surfaceContainerHighest,
                            child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 48, color: cs.outline)),
                          ),
                        )
                      : Image.memory(
                          base64Decode(task.photoUrl!),
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: cs.surfaceContainerHighest,
                            child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 48, color: cs.outline)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(t('tap_to_zoom'),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
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
            if (canStart)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _claimTask,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(t('start_task')),
                ),
              ),
            if (canComplete)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickAndSubmitProof,
                  icon: _uploading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_uploading ? t('uploading') : t('complete_with_photo')),
                ),
              ),
            if (canCompleteAsManager && !task.isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _completeAsManager,
                  icon: _uploading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_uploading ? t('uploading') : t('complete_with_photo')),
                ),
              ),
            if (widget.isManager && task.isPendingReview) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _approveTask,
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
                        onPressed: _rejectWithReason,
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
            if (widget.isManager && !task.isCompleted && !task.isPendingReview)
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
            if (widget.isManager)
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
    if (task.isCompleted) {
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
