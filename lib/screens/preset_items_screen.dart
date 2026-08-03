import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/utils/error_handler.dart';

class PresetItemsScreen extends StatefulWidget {
  const PresetItemsScreen({super.key});

  @override
  State<PresetItemsScreen> createState() => _PresetItemsScreenState();
}

class _PresetItemsScreenState extends State<PresetItemsScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(context.read<SettingsService>().t('new_preset_item')),
        content: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText:
                context.read<SettingsService>().t('item_name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.read<SettingsService>().t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_ctrl.text.trim().isEmpty) return;
              final email = FirebaseAuth.instance.currentUser?.email ?? '';
              final ok = await context
                  .read<TaskProvider>()
                  .addPresetItem(_ctrl.text.trim(), email);
              if (!ctx.mounted) return;
              if (!ok) {
                toast(ctx, 'Failed to add item', error: true);
                return;
              }
              toast(ctx, 'Item added');
              _ctrl.clear();
              Navigator.pop(ctx);
            },
            child: Text(context.read<SettingsService>().t('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsService>().t;
    final items = context.watch<TaskProvider>().presetItems;

    return Scaffold(
      appBar: AppBar(title: Text(t('manage_items'))),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('no_items'),
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(t('add_item')),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  title: Text(item.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final ok = await context
                          .read<TaskProvider>()
                          .deletePresetItem(item.id);
                      if (!mounted) return;
                      toast(context,
                          ok ? 'Item deleted' : 'Failed to delete item',
                          error: !ok);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
