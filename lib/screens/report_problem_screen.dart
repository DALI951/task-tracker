import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/problem.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/user_service.dart';
import 'package:task_tracker/utils/device_utils.dart';
import 'package:task_tracker/utils/error_handler.dart';
import 'package:task_tracker/widgets/photo_viewer.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _descCtrl = TextEditingController();
  final List<XFile> _photos = [];
  String? _selectedCarOrThing;
  bool _sending = false;
  bool _preparing = false;
  int _uploadCompleted = 0;
  int _uploadTotal = 0;
  int _bytesSent = 0;
  int _totalBytes = 0;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty) return;
    final room = 50 - _photos.length;
    if (room <= 0) return;
    setState(() => _photos.addAll(picked.take(room)));
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty) return;
    // Show feedback immediately: reading/decoding the picked photos into
    // memory can take a moment with many photos, then upload progress runs.
    setState(() {
      _sending = true;
      _preparing = true;
      _uploadCompleted = 0;
      _uploadTotal = _photos.length;
      _bytesSent = 0;
      _totalBytes = 0;
    });
    final images = <Uint8List>[];
    for (final file in _photos) {
      images.add(await file.readAsBytes());
    }
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _uploadTotal = images.length;
      _totalBytes = images.fold<int>(0, (sum, b) => sum + b.length);
    });
    try {
      final user = AuthService().currentUser;
      if (user == null) return;
      final name = await UserService().getDisplayName(user.email ?? '');
      final ok = await context.read<TaskProvider>().reportProblem(
            reportedBy: user.email ?? '',
            reporterName: name,
            description: _descCtrl.text.trim(),
            photos: images,
            carOrThing: _selectedCarOrThing,
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
      if (ok) {
        setState(() {
          _descCtrl.clear();
          _photos.clear();
          _selectedCarOrThing = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<SettingsService>().t('problem_reported')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final provider = context.read<TaskProvider>();
        final err = provider.reportError ?? friendlyError(Exception('report_failed'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsService>().t;
    final items = context.watch<TaskProvider>().presetItems;
    final reports = context.watch<TaskProvider>().myProblems;

    return Scaffold(
      appBar: AppBar(title: Text(t('report_problem'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: t('description'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          if (items.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedCarOrThing,
            decoration: InputDecoration(
              labelText: t('car_thing'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(t('none'))),
              ...items.map(
                  (i) => DropdownMenuItem(value: i.name, child: Text(i.name))),
            ],
            onChanged: (v) => setState(() => _selectedCarOrThing = v),
          ),
          const SizedBox(height: 16),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                itemBuilder: (_, i) => Padding(
                  key: ValueKey(_photos[i].path),
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Stack(children: [
                    LazyPhotoThumb(file: _photos[i], size: 100),
                    PositionedDirectional(top: 0, end: 0, child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _photos.removeAt(i)),
                    )),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _sending || _photos.length >= 50 ? null : _takePhoto,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text('Photos (${_photos.length}/50)'),
          ),
          const SizedBox(height: 24),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: LinearProgressIndicator(
                  value: _preparing || _totalBytes == 0
                      ? null
                      : (_bytesSent / _totalBytes).clamp(0.0, 1.0),
                )),
                const SizedBox(width: 8),
                Text(
                  _preparing
                      ? t('preparing_photos')
                      : '${t('notif_photo')} $_uploadCompleted/$_uploadTotal'
                          '${_totalBytes == 0 ? '' : ' · ${((_bytesSent / _totalBytes) * 100).round()}%'}',
                ),
              ]),
            ),
          if (_sending)
            const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('send')),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('my_reports'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (reports.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                t('no_reports_yet'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...reports.map((p) => _ReportStatusCard(problem: p)),
        ],
      ),
    );
  }
}

class _ReportStatusCard extends StatelessWidget {
  final Problem problem;
  const _ReportStatusCard({required this.problem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, HH:mm');

    Color fg;
    IconData icon;
    String label;
    final uploading = problem.isUploading && !problem.uploadsComplete;
    if (uploading) {
      fg = Colors.blue.shade700;
      icon = Icons.cloud_upload;
      final pct = problem.uploadProgress == null
          ? ''
          : ' · ${(problem.uploadProgress! * 100).round()}%';
      label = '${context.read<SettingsService>().t('uploading')} ${problem.uploadCompleted}/${problem.uploadTotal}$pct';
    } else if (problem.isUploading) {
      // uploadsComplete == true but never flipped to 'open' -> it failed or
      // the app was closed mid-send; the report never reached the manager.
      fg = Colors.orange.shade800;
      icon = Icons.error_outline;
      label = context.read<SettingsService>().t('interrupted');
    } else if (problem.isResolved) {
      fg = Brand.done;
      icon = Icons.check_circle;
      label = context.read<SettingsService>().t('complete');
    } else if (problem.isAssigned) {
      fg = Brand.doing;
      icon = Icons.person_pin;
      label = context.read<SettingsService>().t('filter_assigned');
    } else {
      fg = Brand.done;
      icon = Icons.check_circle_outline;
      label = context.read<SettingsService>().t('complete');
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      problem.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 12, color: fg, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(problem.createdAt),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              if (uploading) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: problem.uploadProgress,
                    minHeight: 5,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ],
              if (problem.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: problem.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final photo = problem.photoUrls[i];
                      return GestureDetector(
                        onTap: () => PhotoViewer.show(context,
                            photos: problem.photoUrls, initialIndex: i),
                        child: RemotePhoto(url: photo, width: 60, height: 60),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy · HH:mm');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      problem.description,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(problem.createdAt),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (problem.carOrThing != null) ...[
                const SizedBox(height: 8),
                Text('${context.read<SettingsService>().t('car_thing')}: ${problem.carOrThing}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
              if (problem.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: problem.photoUrls.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => PhotoViewer.show(context,
                          photos: problem.photoUrls, initialIndex: entry.key),
                      child: RemotePhoto(
                        url: entry.value,
                        width: 120,
                        height: 120,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(Brand.radiusSm)),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
