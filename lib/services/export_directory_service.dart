import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_log_service.dart';

/// Manages persistent export directory preference with safe fallback to Downloads.
class ExportDirectoryService {
  static const String _prefKey = 'export_directory_path';

  /// Gets the current export directory.
  /// Returns saved preference if valid, otherwise Downloads, otherwise app documents.
  Future<Directory> getExportDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefKey);

      if (savedPath != null && savedPath.isNotEmpty) {
        final savedDir = Directory(savedPath);
        if (await savedDir.exists()) {
          DebugLogService.instance.logInfo('Using saved export directory: $savedPath');
          return savedDir;
        } else {
          DebugLogService.instance.logWarning('Saved directory no longer exists: $savedPath');
          await prefs.remove(_prefKey);
        }
      }
    } catch (error, stack) {
      DebugLogService.instance.logError('Error reading saved export directory', error, stack);
    }

    // Fallback to Downloads
    return await _getDefaultExportDirectory();
  }

  /// Gets the default export directory (Downloads or app documents).
  Future<Directory> _getDefaultExportDirectory() async {
    if (Platform.isAndroid) {
      // Use public Downloads folder: /storage/emulated/0/Download
      final downloadPath = '/storage/emulated/0/Download';
      final downloadDir = Directory(downloadPath);
      
      // Create directory if it doesn't exist
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      DebugLogService.instance.logInfo('Using Android Downloads directory: $downloadPath');
      return downloadDir;
    } else if (Platform.isIOS) {
      // On iOS, use app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      DebugLogService.instance.logInfo('Using app documents directory: ${appDir.path}');
      return appDir;
    } else {
      // On desktop, try Downloads first
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        DebugLogService.instance.logInfo('Using downloads directory: ${downloadsDir.path}');
        return downloadsDir;
      }
      
      // Fallback to app documents if Downloads not available
      final appDir = await getApplicationDocumentsDirectory();
      DebugLogService.instance.logInfo('Using app documents directory: ${appDir.path}');
      return appDir;
    }
  }

  /// Prompts user to select a custom export directory.
  /// Returns the selected directory or null if cancelled.
  Future<Directory?> selectCustomDirectory() async {
    try {
      String? directoryPath;
      
      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, use FilePicker to select directory
        directoryPath = await FilePicker.getDirectoryPath(
          dialogTitle: 'Chọn thư mục xuất file',
        );
      } else {
        // On desktop, use file_selector's getDirectoryPath
        directoryPath = await getDirectoryPath(
          confirmButtonText: 'Chọn thư mục',
        );
      }

      if (directoryPath == null) {
        DebugLogService.instance.logInfo('Directory selection cancelled');
        return null;
      }

      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        DebugLogService.instance.logWarning('Selected directory does not exist: $directoryPath');
        return null;
      }

      // Save the preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, directoryPath);
      DebugLogService.instance.logInfo('Export directory saved: $directoryPath');

      return directory;
    } catch (error, stack) {
      DebugLogService.instance.logError('Error selecting custom directory', error, stack);
      return null;
    }
  }

  /// Resets the export directory preference to default.
  Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      DebugLogService.instance.logInfo('Export directory preference reset to default');
    } catch (error, stack) {
      DebugLogService.instance.logError('Error resetting export directory', error, stack);
    }
  }

  /// Gets the currently saved custom directory path, or null if using default.
  Future<String?> getSavedCustomPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefKey);
      
      if (savedPath != null && savedPath.isNotEmpty) {
        final savedDir = Directory(savedPath);
        if (await savedDir.exists()) {
          return savedPath;
        } else {
          // Clean up invalid path
          await prefs.remove(_prefKey);
        }
      }
    } catch (error, stack) {
      DebugLogService.instance.logError('Error getting saved custom path', error, stack);
    }
    return null;
  }
}
