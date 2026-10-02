import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FileManagerService {
  static const platform =
      MethodChannel('com.example.doc_qr_scanner/file_manager');

  /// Open file manager at the folder containing the file
  static Future<bool> openFolder(String filePath) async {
    try {
      final result = await platform.invokeMethod('openFolder', {
        'filePath': filePath,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Failed to open folder: ${e.message}');
      return false;
    }
  }
}
