import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

/// File-backed logs. Error persistence completes before an error handler returns.
class DebugLogService {
  DebugLogService._();
  static final DebugLogService instance = DebugLogService._();

  static const int _maxEntries = 100;
  static const String fileName = 'crash_history.log';
  final ValueNotifier<List<String>> logs = ValueNotifier(<String>[]);
  List<String> _entries = [];
  final List<String> _beforeInit = [];
  File? _file;
  Future<void> _pending = Future<void>.value();
  bool _notificationScheduled = false;

  /// Restores complete multiline entries; ignores a partial trailing disk record.
  /// File injection lets tests simulate a restart without platform plugins.
  Future<void> initialize({File? file}) async {
    await flush();
    try {
      _file =
          file ??
          File('${(await getApplicationDocumentsDirectory()).path}/$fileName');
      final restored = <String>[];
      if (await _file!.exists()) {
        for (final line in await _file!.readAsLines()) {
          try {
            final entry = jsonDecode(line);
            if (entry is String) restored.add(entry);
          } catch (_) {
            // A terminated process can leave one incomplete JSON record.
          }
        }
      }
      _entries = [...restored, ..._beforeInit].takeLast(_maxEntries);
      // Compact on startup only; appending an error never races a queued rewrite.
        _file!.writeAsStringSync(_encode(_entries), flush: true);
      _beforeInit.clear();
      _publish();
    } catch (error, stack) {
      _file = null;
      debugPrint('Cannot restore crash history: $error\n$stack');
    }
  }

  static String _encode(List<String> entries) =>
      entries.isEmpty ? '' : '${entries.map(jsonEncode).join('\n')}\n';

  void _append(String entry, {bool crash = false}) {
    _entries = [..._entries, entry].takeLast(_maxEntries);
    final file = _file;
    if (file == null) {
      _beforeInit.add(entry);
      if (_beforeInit.length > _maxEntries) _beforeInit.removeAt(0);
    } else if (crash) {
      // Small synchronous write is intentional for crashes: durable before return.
      // Native SIGKILL/OOM cannot be caught, but previously flushed errors survive.
      try {
        file.writeAsStringSync(
          _encode([entry]),
          mode: FileMode.append,
          flush: true,
        );
      } catch (error) {
        debugPrint('Cannot persist crash history: $error');
      }
    } else {
      _pending = _pending.then((_) {
        try {
          // A synchronous append in a deferred microtask cannot interleave with
          // a crash-handler append to the same file on this isolate.
          file.writeAsStringSync(
            _encode([entry]),
            mode: FileMode.append,
            flush: false,
          );
        } catch (error) {
          debugPrint('Cannot persist debug log: $error');
        }
      });
    }
    _publish();
  }

  void _publish() {
    // FlutterError may arrive during build; never notify a console listener then.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        logs.value = List.unmodifiable(_entries);
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } else {
      logs.value = List.unmodifiable(_entries);
    }
  }

  void logInfo(String message) =>
      _append('[${DateTime.now().toIso8601String()}] [INFO] - $message');
  void logWarning(String message) =>
      _append('[${DateTime.now().toIso8601String()}] [WARNING] - $message');

  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(
      '[${DateTime.now().toIso8601String()}] [ERROR] - $message',
    );
    if (error != null) buffer.write('\n  Error: $error');
    if (stackTrace != null) buffer.write('\n  StackTrace:\n$stackTrace');
    _append(buffer.toString(), crash: true);
  }

  Future<void> clear() async {
    await flush();
    try {
      _file?.writeAsStringSync('', flush: true);
      _entries = [];
      _beforeInit.clear();
      _publish();
    } catch (error) {
      debugPrint('Cannot clear crash history: $error');
    }
  }

  Future<void> flush() => _pending;
  String toClipboardText() => _entries.join('\n\n');
}

extension _LastEntries on List<String> {
  List<String> takeLast(int count) =>
      skip(length > count ? length - count : 0).toList();
}
