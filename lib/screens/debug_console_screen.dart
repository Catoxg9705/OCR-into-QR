import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/debug_log_service.dart';

/// Includes crash entries restored by main() from crash_history.log.
class DebugConsoleScreen extends StatelessWidget {
  const DebugConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = DebugLogService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy All'),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: logger.toClipboardText()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã copy toàn bộ log')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Xóa cả lịch sử đã lưu',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              await logger.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa lịch sử log')),
                );
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: logger.logs,
        builder: (context, entries, _) {
          final errors = entries
              .where((entry) => entry.contains('[ERROR]'))
              .toList();
          final lastCrash = errors.isEmpty ? null : errors.last;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: ExpansionTile(
                    key: ValueKey(lastCrash),
                    initiallyExpanded: lastCrash != null,
                    title: const Text('View Last Crash / Lỗi gần nhất'),
                    subtitle: Text(
                      lastCrash == null
                          ? 'Chưa có lỗi đã lưu.'
                          : 'Lịch sử được giữ trong crash_history.log',
                    ),
                    children: [
                      if (lastCrash != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            lastCrash,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              final entry = entries[entries.length - index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SelectableText(
                  entry,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: entry.contains('[ERROR]')
                        ? Colors.redAccent
                        : Colors.white70,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
