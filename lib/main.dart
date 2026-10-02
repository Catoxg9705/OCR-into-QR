import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/document_picker_screen.dart';
import 'services/debug_log_service.dart';
import 'services/document_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = DebugLogService.instance;
  
  // Request file permissions on startup
  await _requestPermissions();
  // Register catchers before startup I/O so initialization failures are kept.
  FlutterError.onError = (details) {
    logger.logError(
      'FlutterError',
      details.toString(),
      details.stack ?? StackTrace.current,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.logError('Uncaught async error', error, stack);
    return true;
  };

  await logger.initialize();
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFF171A23),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Lỗi giao diện. Vui lòng xem Debug Console.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade300, fontSize: 14),
        ),
      ),
    ),
  );

  // Persisted log is restored before the first frame.
  runApp(const DocQrScannerApp());
}

Future<void> _requestPermissions() async {
  // Request storage permissions
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
  
  // Request manage external storage for Android 11+
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }
  
  // Request photos permission for Android 13+
  if (await Permission.photos.isDenied) {
    await Permission.photos.request();
  }
  
  // Request videos permission for Android 13+
  if (await Permission.videos.isDenied) {
    await Permission.videos.request();
  }
}

class DocQrScannerApp extends StatelessWidget {
  const DocQrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => DocumentState())],
      child: MaterialApp(
        title: 'Quét Doc',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B8CFF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF171A23),
          useMaterial3: true,
        ),
        home: const DocumentPickerScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
