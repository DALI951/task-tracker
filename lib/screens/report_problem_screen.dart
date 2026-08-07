import 'dart:typed_data';
import 'package:flutter/material.dart';
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

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _descCtrl = TextEditingController();
  final List<Uint8List> _photos = [];
  String? _selectedCarOrThing;
  bool _sending = false;
  int _uploadCompleted = 0;
  int _uploadTotal = 0;
  String? _pendingReportDesc;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picked = await pickPhoto(context);
    if (picked == null || _photos.length >= 50) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photos.add(bytes));
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _uploadCompleted = 0;
      _uploadTotal = _photos.length;
      _pendingReportDesc = _descCtrl.text.trim();
    });
    try {
      final user = AuthService().currentUser;
      if (user == null) return;
      final name = await UserService().getDisplayName(user.email ?? '');
      final ok = await context.read<TaskProvider>().reportProblem(
            reportedBy: user.email ?? '',
            reporterName: name,
            description: _descCtrl.text.trim(),
            photos: _photos,
            carOrThing: _selectedCarOrThing,
            onProgress: (done, total) {
              if (mounted) setState(() {
                _uploadCompleted = done;
                _uploadTotal = total;
              });
            },
          );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _pendingReportDesc = null;
          _descCtrl.clear();
          _photos.clear();
          _selectedCarOrThing = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported'),
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
        setState(() => _pendingReportDesc = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pendingReportDesc = null);
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
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Stack(children: [
                    Image.memory(_photos[i], width: 100, height: 100, fit: BoxFit.cover, cacheWidth: 200),
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
            icon: const Icon(Icons.camera_alt),
            label: Text('${t('take_photo')} (${_photos.length}/50)'),
          ),
          const SizedBox(height: 24),
          if (_sending)
            Row(children: [
              Expanded(child: LinearProgressIndicator(
                value: _uploadTotal == 0
                    ? null
                    : _uploadCompleted / _uploadTotal,
              )),
              const SizedBox(width: 8),
              Text('$_uploadCompleted/$_uploadTotal'),
            ]),
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
          if (_pendingReportDesc != null) _inFlightReportCard(),
          if (reports.isEmpty && _pendingReportDesc == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No reports yet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...reports.map((p) => _ReportStatusCard(problem: p)),
        ],
      ),
    );
  }

  Widget _inFlightReportCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pendingReportDesc!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.cloud_upload, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadTotal == 0
                        ? null
                        : _uploadCompleted / _uploadTotal,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_uploadCompleted/$_uploadTotal',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ]),
          ],
        ),
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
    if (problem.isResolved) {
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
          ],
        ),
      ),
    );
  }
}
