import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';
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
    final ok = await context.read<TaskProvider>().claimTask(
          widget.task.id,
          user.email ?? '',
          user.displayName ?? user.email ?? '',
        );
    if (mounted) toast(context, ok ? t('task_started') : context.read<TaskProvider>().error ?? 'Failed');
  }

  Future<void> _pickAndSubmitProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
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
      source: ImageSource.camera,
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
                  initialValue: selectedEmail,
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
                child: Image.memory(
                  base64Decode(widget.task.photoUrl!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
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
            initialValue: null,
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
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                  ),
                ),
                _statusChip(task),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('${t('assigned_to')}: ${task.assignedTo}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('${t('created')}: ${dateFormat.format(task.createdAt)}'),
              ],
            ),
            if (task.completedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade500),
                  const SizedBox(width: 4),
                  Text('${t('completed')}: ${dateFormat.format(task.completedAt!)}',
                      style: TextStyle(color: Colors.green.shade700)),
                ],
              ),
            ],
            if (task.claimedByName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_pin, size: 16, color: Colors.orange.shade500),
                  const SizedBox(width: 4),
                  Text('${t('claimed_by')}: ${task.claimedByName}'),
                ],
              ),
            ],
            if (task.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${t('rejection_reason')}: ${task.rejectionReason}',
                          style: TextStyle(color: Colors.red.shade800)),
                    ),
                  ],
                ),
              ),
            ],
            if (task.carOrThing != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${t('car_thing')}: ${task.carOrThing}'),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (task.description != null) ...[
              Text(t('description'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(task.description!, style: const TextStyle(fontSize: 15)),
            ] else ...[
              Text(t('no_description'),
                  style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            ],
            if (task.photoUrl != null) ...[
              const SizedBox(height: 20),
              Text(t('proof_photo'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showPhotoGallery,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(task.photoUrl!),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.broken_image, size: 48)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(t('tap_to_zoom'),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
            if (task.history.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(t('history'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...task.history.reversed.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_historyLabel(e.action)} ${t('by')} ${e.by}${e.detail != null && e.detail!.isNotEmpty ? ' — ${e.detail}' : ''}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _claimTask,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(t('start_task')),
                ),
              ),
            if (canComplete)
              SizedBox(
                width: double.infinity,
                height: 48,
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
                height: 48,
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _approveTask,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: Text(t('approve'), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _rejectWithReason,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.close),
                        label: Text(t('reject')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.isManager && !task.isCompleted && !task.isPendingReview)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showReassignDialog,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(t('reassign')),
                ),
              ),
            if (widget.isManager)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: task.status,
                    decoration: InputDecoration(
                      labelText: t('status'),
                      border: const OutlineInputBorder(),
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
              Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
                    const SizedBox(height: 8),
                    Text(t('task_completed'), style: TextStyle(color: Colors.green.shade700)),
                  ],
                ),
              ),
          ],
        ),
      ),
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
    if (task.isCompleted) {
      return Chip(
        label: Text(t('done')),
        backgroundColor: Colors.green.shade100,
        avatar: const Icon(Icons.check_circle, size: 18, color: Colors.green),
      );
    }
    if (task.isPendingReview) {
      return Chip(
        label: Text(t('pending_review')),
        backgroundColor: Colors.purple.shade100,
        avatar: Icon(Icons.rate_review, size: 18, color: Colors.purple.shade700),
      );
    }
    if (task.isDoing) {
      return Chip(
        label: Text(t('doing')),
        backgroundColor: Colors.blue.shade100,
        avatar: Icon(Icons.hourglass_top, size: 18, color: Colors.blue.shade700),
      );
    }
    return Chip(
      label: Text(t('pending')),
      backgroundColor: Colors.orange.shade100,
      avatar: Icon(Icons.hourglass_empty, size: 18, color: Colors.orange.shade700),
    );
  }
}
