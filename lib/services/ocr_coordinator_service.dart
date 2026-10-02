import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/ocr_result.dart';
import '../models/selected_document.dart';
import 'ocr_service.dart';
import 'pdf_to_image_service.dart';

/// Owns generated page rasters and a single lazily created Latin recognizer.
class OcrCoordinatorService {
  OcrCoordinatorService({OcrService? ocrService, PdfToImageService? pdfService})
    : _ocr = ocrService ?? OcrService(),
      _pdf = pdfService ?? PdfToImageService();

  final OcrService _ocr;
  final PdfToImageService _pdf;

  Future<DocumentCanvas> prepareDocument(SelectedDocument document) async {
    if (document.format == DocumentFormat.pdf) {
      final count = await _pdf.getPdfPageCount(document.filePath);
      final page = await preparePage(document.filePath, 1);
      return DocumentCanvas(
        imagePath: page.imagePath,
        imageSize: page.imageSize,
        pageCount: count,
        ownsImage: true,
      );
    }
    // Bake EXIF orientation in an owned cache image to keep display/crop axes equal.
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/canvas_${const Uuid().v4()}.png';
    await compute(_normalizeImage, [document.filePath, path]);
    try {
      return DocumentCanvas(
        imagePath: path,
        imageSize: await _ocr.getImageSize(path),
        pageCount: 1,
        ownsImage: true,
      );
    } catch (_) {
      await _pdf.cleanupTempImage(path);
      rethrow;
    }
  }

  Future<DocumentCanvas> preparePage(String pdfPath, int pageNumber) async {
    final path = await _pdf.renderPageToImage(pdfPath, pageNumber);
    try {
      return DocumentCanvas(
        imagePath: path,
        imageSize: await _ocr.getImageSize(path),
        pageCount: 1,
        ownsImage: true,
      );
    } catch (_) {
      await _pdf.cleanupTempImage(path);
      rethrow;
    }
  }

  Future<List<ZoneOcrResult>> scanZones(
    DocumentCanvas page,
    List<Rect> rects, {
    List<String?>? editedTexts,
  }) => _ocr.recognizeZones(
        page.imagePath,
        rects,
        editedTexts: editedTexts,
      );

  Future<void> releaseCanvas(DocumentCanvas? canvas) async {
    if (canvas != null && canvas.ownsImage) {
      await _pdf.cleanupTempImage(canvas.imagePath);
    }
  }

  Future<void> dispose() => _ocr.dispose();
}

Future<void> _normalizeImage(List<String> paths) async {
  final decoded = img.decodeImage(await File(paths[0]).readAsBytes());
  if (decoded == null) {
    throw const FormatException('Cannot decode selected image');
  }
  var oriented = img.bakeOrientation(decoded);
  if (math.max(oriented.width, oriented.height) > 4096) {
    oriented = oriented.width >= oriented.height
        ? img.copyResize(oriented, width: 4096)
        : img.copyResize(oriented, height: 4096);
  }
  final file = File(paths[1]);
  try {
    await file.writeAsBytes(img.encodePng(oriented), flush: true);
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
}
