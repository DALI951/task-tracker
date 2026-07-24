import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:task_tracker/config/brand.dart';

class UpdateModal extends StatefulWidget {
  final String currentVersion;
  final String latestVersion;
  final String changelog;
  final String downloadUrl;
  final VoidCallback onLater;
  final VoidCallback onNever;

  const UpdateModal({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.onLater,
    required this.onNever,
  });

  @override
  State<UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<UpdateModal> {
  double? _progress;
  bool _downloading = false;
  String? _error;

  Future<void> _startDownload() async {
    final hasPermission = await Permission.requestInstallPackages.request();
    if (!hasPermission.isGranted) {
      if (mounted) {
        setState(() => _error = 'Install permission denied');
      }
      return;
    }

    setState(() {
      _downloading = true;
      _error = null;
    });

    final dio = Dio();
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/Task-Tracker-v${widget.latestVersion}.apk';

    try {
      await dio.download(
        widget.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (mounted) {
        Navigator.pop(context);
        await OpenFile.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
          _error = 'Download failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_downloading,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.system_update,
                      color: cs.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Available',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.currentVersion} → v${widget.latestVersion}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.changelog.isNotEmpty) ...[
              Text(
                "What's new",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(Brand.radiusSm),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.changelog,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            if (_downloading) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
              const SizedBox(height: 8),
              Text(
                _progress != null ? '${(_progress! * 100).toInt()}%' : 'Starting download...',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ],
            if (!_downloading)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onNever,
                      child: const Text('Never'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onLater,
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                      child: const Text('Install'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
