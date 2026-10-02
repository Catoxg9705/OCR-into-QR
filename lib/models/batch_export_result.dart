import 'dart:io';

class BatchExportResult {
  final Directory batchDir;
  final Map<String, String> results; // zoneId -> pdfPath
  final Map<String, String> errors; // zoneId -> error message
  final int timestamp;

  BatchExportResult({
    required this.batchDir,
    required this.results,
    required this.errors,
    required this.timestamp,
  });

  int get totalZones => results.length + errors.length;
  int get successCount => results.length;
  int get errorCount => errors.length;
  bool get hasErrors => errors.isNotEmpty;
  bool get allSucceeded => errors.isEmpty && results.isNotEmpty;
}
