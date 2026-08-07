import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/update_service.dart';

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  String? _body;
  String? _version;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await UpdateService().cachedLatestRelease();
    if (cached != null) {
      setState(() {
        _body = cached.body;
        _version = cached.version;
        _loading = false;
      });
    }

    final latest = await UpdateService().fetchLatestRelease();
    if (mounted) {
      if (latest != null) {
        setState(() {
          _body = latest.body;
          _version = latest.version;
          _loading = false;
        });
      } else if (cached == null) {
        setState(() {
          _loading = false;
          _error = 'Could not load the changelog. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("What's New"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: cs.outline),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _load();
                          },
                          child: Text(context.read<SettingsService>().t('retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withAlpha(120),
                        borderRadius:
                            BorderRadius.circular(Brand.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _version != null ? 'Task Tracker v$_version' : 'Task Tracker',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Latest release notes',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onPrimaryContainer.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_body != null && _body!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withAlpha(80),
                          borderRadius:
                              BorderRadius.circular(Brand.radiusMd),
                        ),
                        child: SelectableText(
                          _body!,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No release notes available yet.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
    );
  }
}
