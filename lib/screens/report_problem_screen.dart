import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/user_service.dart';
import 'package:task_tracker/utils/error_handler.dart';
import 'package:task_tracker/utils/device_utils.dart';

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

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final maxDim = await pickerMaxDimension();
    final picked = await picker.pickImage(
      source: kIsWeb || defaultTargetPlatform != TargetPlatform.android
          ? ImageSource.gallery
          : ImageSource.camera,
      maxWidth: maxDim,
      maxHeight: maxDim,
    );
    if (picked == null || _photos.length >= 50) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photos.add(bytes));
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
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
          );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
                    Image.memory(_photos[i], width: 100, height: 100, fit: BoxFit.cover),
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
            onPressed: _photos.length >= 50 ? null : _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text('${t('take_photo')} (${_photos.length}/50)'),
          ),
          const SizedBox(height: 24),
          if (context.watch<TaskProvider>().uploadingPhotos)
            Row(children: [
              Expanded(child: LinearProgressIndicator(
                value: context.read<TaskProvider>().uploadTotal == 0
                    ? null
                    : context.read<TaskProvider>().uploadCompleted /
                        context.read<TaskProvider>().uploadTotal,
              )),
              const SizedBox(width: 8),
              Text('${context.read<TaskProvider>().uploadCompleted}/${context.read<TaskProvider>().uploadTotal}'),
            ]),
          if (context.watch<TaskProvider>().uploadingPhotos)
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
        ],
      ),
    );
  }
}
