import 'package:flutter/material.dart';
import 'package:task_tracker/config/brand.dart';

class UpdateModal extends StatefulWidget {
  final String currentVersion;
  final String latestVersion;
  final String changelog;
  final VoidCallback onInstallNow;
  final VoidCallback onLater;
  final VoidCallback onNever;

  const UpdateModal({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.changelog,
    required this.onInstallNow,
    required this.onLater,
    required this.onNever,
  });

  @override
  State<UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<UpdateModal> {
  double? _progress;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
  }

  void setProgress(double p) {
    if (mounted) setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
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
                    color: Brand.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.system_update,
                      color: Brand.primary, size: 28),
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
            if (_downloading && _progress != null) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: cs.surfaceContainerHighest,
                color: Brand.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress! * 100).toInt()}%',
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
                      onPressed: widget.onInstallNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Brand.primary,
                        foregroundColor: Colors.white,
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
