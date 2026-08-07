import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/storage_service.dart';
import 'package:task_tracker/widgets/photo_viewer.dart';

class TaskCard extends StatelessWidget {
  final AppTask task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.read<SettingsService>().t;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        child: Padding(
          padding: Brand.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? cs.outline
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(task, t),
                      ],
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (task.isUploading) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: task.uploadProgress,
                                minHeight: 5,
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.uploadCompleted}/${task.uploadTotal}'
                            '${task.uploadProgress == null ? '' : ' · ${(task.uploadProgress! * 100).round()}%'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: cs.outline),
                        const SizedBox(width: 4),
                        Text(
                          task.assignedTo,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (task.claimedByName != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.person_pin,
                              size: 14, color: Brand.doing),
                          const SizedBox(width: 2),
                          Text(
                            task.claimedByName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Brand.doing,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (task.customer != null) ...[
                          const Spacer(),
                          Icon(Icons.business,
                              size: 14, color: cs.outline),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              task.customer!,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (task.photoUrl != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: StorageService.isRemotePhoto(task.photoUrl!)
                      ? RemotePhoto(url: task.photoUrl!, width: 48, height: 48)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(Brand.radiusSm),
                          child: Image.memory(
                            base64Decode(task.photoUrl!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.broken_image,
                                  size: 24, color: cs.outline),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(AppTask task, String Function(String) t) {
    Color bg, fg;
    String label;
    if (task.isUploading) {
      bg = Brand.pendingReview.withAlpha(30);
      fg = Colors.blue.shade700;
      final pct = task.uploadProgress == null
          ? ''
          : ' · ${(task.uploadProgress! * 100).round()}%';
      label = '${t('uploading')} ${task.uploadCompleted}/${task.uploadTotal}$pct';
    } else if (task.isCompleted) {
      bg = Brand.done.withAlpha(25);
      fg = Brand.done;
      label = t('done');
    } else if (task.isPendingReview) {
      bg = Brand.pendingReview.withAlpha(25);
      fg = Brand.pendingReview;
      label = t('pending_review');
    } else if (task.isDoing) {
      bg = Brand.doing.withAlpha(25);
      fg = Brand.doing;
      label = t('doing');
    } else {
      bg = Brand.pending.withAlpha(25);
      fg = Brand.pending;
      label = t('pending');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
