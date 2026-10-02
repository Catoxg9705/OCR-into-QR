import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/batch_result.dart';
import 'debug_log_service.dart';
import 'export_directory_service.dart';

/// Exports processed documents as PDFs with QR codes stamped at specified positions.
class PdfExportService {
  final ExportDirectoryService _exportDirService = ExportDirectoryService();

  /// Exports a batch result to a new PDF with QR codes containing per-page data.
  /// 
  /// This method processes each page sequentially:
  /// 1. Retrieves finalized user-edited field data from BatchResult (NO OCR)
  /// 2. Generates QR code PNG bytes from plain text payload (field1: value1\nfield2: value2...)
  /// 3. Stamps QR at (qrRelativeX, qrRelativeY, qrRelativeSize) onto the PDF page
  /// 4. Yields UI thread every 20ms to prevent ANR and allow progress dialog updates
  /// 5. Immediately closes page resources to prevent Android native OOM
  /// 
  /// Returns the path to the generated PDF file, or null if export fails.
  Future<String?> exportWithQrCodes({
    required String sourcePdfPath,
    required BatchResult result,
    required Function(int current, int total) onProgress,
    String? outputFileName,
  }) async {
    try {
      final pdf = pw.Document();
      final sourceDoc = await pdfx.PdfDocument.openFile(sourcePdfPath);

      for (var pageNum = 1; pageNum <= result.totalPages; pageNum++) {
        // Update progress immediately
        onProgress(pageNum, result.totalPages);

        // Render source page as image
        final page = await sourceDoc.getPage(pageNum);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImage == null) {
          DebugLogService.instance.logError(
            'Failed to render page $pageNum',
            Exception('Null page image'),
            StackTrace.current,
          );
          continue;
        }

        // Convert to pw.MemoryImage
        final pageMemoryImage = pw.MemoryImage(pageImage.bytes);

        // Find page data (finalized, user-edited fields - NEVER run OCR here)
        final pageData = result.pages.firstWhere(
          (p) => p.pageNumber == pageNum,
          orElse: () => PageData(pageNumber: pageNum, fields: []),
        );

        // Generate QR code directly from finalized field data
        Uint8List? qrImageBytes;
        if (pageData.fields.isNotEmpty) {
          qrImageBytes = await _generateQrCodeImage(pageData);
        }

        // Add page with background image and optional QR overlay
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              page.width,
              page.height,
              marginAll: 0,
            ),
            build: (context) {
              return pw.Stack(
                children: [
                  // Background: original page
                  pw.Positioned.fill(
                    child: pw.Image(pageMemoryImage, fit: pw.BoxFit.fill),
                  ),
                  // Foreground: QR code at relative position
                  if (qrImageBytes != null &&
                      result.qrRelativeX != null &&
                      result.qrRelativeY != null &&
                      result.qrRelativeSize != null)
                    pw.Positioned(
                      left: result.qrRelativeX! * page.width,
                      top: result.qrRelativeY! * page.height,
                      child: pw.Container(
                        width: result.qrRelativeSize! * page.width,
                        height: result.qrRelativeSize! * page.width,
                        child: pw.Image(pw.MemoryImage(qrImageBytes)),
                      ),
                    ),
                ],
              );
            },
          ),
        );

        // Yield UI thread to allow progress dialog animation and prevent ANR
        await Future.delayed(const Duration(milliseconds: 20));
      }

      await sourceDoc.close();

      // Save to user-selected or default export directory
      final outputDir = await _exportDirService.getExportDirectory();
      final fileName = outputFileName ?? '${result.documentName}_QR_${DateTime.now().millisecondsSinceEpoch}';
      final outputPath = '${outputDir.path}/$fileName.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      // Trigger Android media scan so file appears immediately in Files app
      if (Platform.isAndroid) {
        await _triggerMediaScan(outputPath);
      }

      DebugLogService.instance.logInfo('PDF exported to: $outputPath');
      return outputPath;
    } catch (error, stack) {
      DebugLogService.instance.logError('PDF export failed', error, stack);
      rethrow; // Propagate error to UI for user-friendly error handling
    }
  }

  /// Triggers Android media scanner to index the exported file.
  Future<void> _triggerMediaScan(String filePath) async {
    try {
      // Use am broadcast to trigger media scanner
      final result = await Process.run(
        'am',
        [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$filePath',
        ],
      );
      
      if (result.exitCode == 0) {
        DebugLogService.instance.logInfo('Media scan triggered for: $filePath');
      } else {
        DebugLogService.instance.logWarning(
          'Media scan failed: ${result.stderr}',
        );
      }
    } catch (error, stack) {
      DebugLogService.instance.logError(
        'Error triggering media scan',
        error,
        stack,
      );
    }
  }

  Future<Uint8List> _generateQrCodeImage(PageData pageData) async {
    // Build newline-separated key-value plaintext payload
    final qrPayload = pageData.fields
        .map((field) => '${field.label}: ${field.value}')
        .join('\n');

    // Generate QR code as image with transparent background
    // Use fixed logical size of 512px for consistent quality
    final qrPainter = QrPainter(
      data: qrPayload,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: ui.Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: ui.Color(0xFF000000),
      ),
    );

    final qrImage = await qrPainter.toImage(512);
    final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
}
