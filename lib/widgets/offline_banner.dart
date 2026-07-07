import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/utils/connectivity.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().online;
    return Column(
      children: [
        if (!online)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            color: Colors.orange.shade700,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('You are offline',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
