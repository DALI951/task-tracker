import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/services/update_download_manager.dart';

/// Shows the background update download progress on the home screens.
/// Visible only while a download is in progress, failed, or ready to install.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<UpdateDownloadManager>();
    final cs = Theme.of(context).colorScheme;

    if (manager.isIdle) return const SizedBox.shrink();

    if (manager.isDownloading) {
      return Material(
        color: cs.surfaceContainerHighest.withAlpha(120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      manager.progress != null
                          ? 'Downloading update… ${(manager.progress! * 100).toInt()}%'
                          : 'Downloading update…',
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: manager.progress,
                  minHeight: 4,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (manager.hasFailed) {
      return Material(
        color: cs.errorContainer.withAlpha(180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  manager.error ?? 'Download failed',
                  style: TextStyle(fontSize: 13, color: cs.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: manager.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: cs.primaryContainer.withAlpha(180),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 20, color: cs.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update ready — tap Install to finish',
                style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer),
              ),
            ),
            FilledButton(
              onPressed: manager.install,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Install'),
            ),
          ],
        ),
      ),
    );
  }
}
