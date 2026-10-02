import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/template_zone.dart';
import '../models/batch_export_result.dart';

class BatchExportService {
  /// Export multiple zones from the same image into separate text files
  Future<BatchExportResult> exportBatch({
    required File imageFile,
    required List<TemplateZone> zones,
    required ValueChanged<double> onProgress,
  }) async {
    if (zones.isEmpty) {
      throw ArgumentError('No zones to export');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = await getTemporaryDirectory();
    final batchDir = Directory('${tempDir.path}/batch_$timestamp');
    await batchDir.create(recursive: true);

    final results = <String, String>{};
    final errors = <String, String>{};
    var completed = 0;

    for (final zone in zones) {
      try {
        // Use the already extracted text from the zone
        final ocrText = zone.extractedText;

        // Use PdfExportService.exportWithQrCodes() instead
        // This service is mainly for demonstration - actual batch export 
        // goes through the main PDF export workflow
        results[zone.id] = ocrText;
      } catch (e) {
        errors[zone.id] = e.toString();
      }

      completed++;
      onProgress(completed / zones.length);
    }

    return BatchExportResult(
      batchDir: batchDir,
      results: results,
      errors: errors,
      timestamp: timestamp,
    );
  }

  /// Clean up temporary batch export files
  Future<void> cleanupBatch(BatchExportResult result) async {
    if (await result.batchDir.exists()) {
      await result.batchDir.delete(recursive: true);
    }
  }
}
