import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _descCtrl = TextEditingController();
  String? _photoBase64;
  String? _selectedCarOrThing;
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final user = AuthService().currentUser;
      if (user == null) return;
      await context.read<TaskProvider>().reportProblem(
            reportedBy: user.email ?? '',
            reporterName: user.displayName ?? user.email ?? '',
            description: _descCtrl.text.trim(),
            photoUrl: _photoBase64,
            carOrThing: _selectedCarOrThing,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
                    initialValue: _selectedCarOrThing,
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
          if (_photoBase64 != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(_photoBase64!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(_photoBase64 == null ? t('take_photo') : t('retake')),
          ),
          const SizedBox(height: 24),
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
