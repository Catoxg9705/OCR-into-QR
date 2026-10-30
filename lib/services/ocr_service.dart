import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/ocr_result.dart' as app;
import '../models/template_zone.dart';
import 'debug_log_service.dart';

/// Tesseract OCR (Vietnamese) runs on the root isolate; only pure Dart image
/// work (crop) uses compute.
class OcrService {
  static const _uuid = Uuid();

  /// Decode a page once off the UI isolate, then recognize its crops in order.
  /// All result bounds are translated back into original page coordinates.
  /// Text is trimmed and leading punctuation (: - whitespace) is removed.
  ///
  /// If [editedTexts] is provided and non-null for a zone, the method will
  /// attempt to locate that edited text within the recognized string and
  /// shrink the bounding box to match it proportionally.
  Future<List<app.ZoneOcrResult>> recognizeZones(
    String imagePath,
    List<ui.Rect> regions, {
    List<String?>? editedTexts,
  }) async {
    if (regions.isEmpty) return [];

    // Validate and auto-expand regions to meet the OCR minimum (32x32px).
    const minSize = 32.0;
    final validatedRegions = <ui.Rect>[];

    for (var i = 0; i < regions.length; i++) {
      var rect = regions[i];

      if (rect == ui.Rect.zero ||
          rect.width <= 0 ||
          rect.height <= 0 ||
          !rect.isFinite) {
        DebugLogService.instance.logError(
          'Invalid region at index $i: $rect - skipping OCR',
        );
        return [];
      }

      if (rect.width < minSize || rect.height < minSize) {
        final center = rect.center;
        rect = ui.Rect.fromCenter(
          center: center,
          width: rect.width < minSize ? minSize : rect.width,
          height: rect.height < minSize ? minSize : rect.height,
        );
        DebugLogService.instance.logInfo(
          'Auto-expanded zone $i from ${regions[i].width.toInt()}x${regions[i].height.toInt()} to ${rect.width.toInt()}x${rect.height.toInt()}px (OCR minimum)',
        );
      }

      validatedRegions.add(rect);
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final crops = await compute(_prepareCrops, <String, Object>{
      'imagePath': imagePath,
      'directory': temporaryDirectory.path,
      'token': _uuid.v4(),
      'regions': [
        for (final rect in validatedRegions)
          [rect.left, rect.top, rect.right, rect.bottom],
      ],
    });
    try {
      final results = <app.ZoneOcrResult>[];
      for (var i = 0; i < crops.length; i++) {
        final crop = crops[i];
        final cropPath = crop['path'] as String;

        final editedText = (editedTexts != null && i < editedTexts.length)
            ? editedTexts[i]
            : null;
        final cropBounds = ui.Rect.fromLTWH(
          (crop['left'] as num).toDouble(),
          (crop['top'] as num).toDouble(),
          (crop['width'] as num).toDouble(),
          (crop['height'] as num).toDouble(),
        );

        // One HOCR pass yields words with both text and bounding boxes.
        List<Map<String, Object>> words = const [];
        try {
          final hocr = await FlutterTesseractOcr.extractHocr(
            cropPath,
            language: 'vie',
            args: {'preserve_interword_spaces': '1'},
          );
          words = _parseHocrWords(hocr);
        } catch (_) {
          words = const [];
        }

        String cleanedText;
        ui.Rect? bounds;
        if (editedText != null && editedText.isNotEmpty) {
          cleanedText = editedText.trim();
          final cropRect = _findEditedTextBoundsInWords(words, cleanedText);
          if (cropRect != null && !cropRect.isEmpty) {
            bounds = cropRect.shift(cropBounds.topLeft);
          } else {
            final fullText = await FlutterTesseractOcr.extractText(
              cropPath,
              language: 'vie',
              args: {'preserve_interword_spaces': '1'},
            );
            bounds = _findEditedTextBoundsInText(
              fullText,
              cleanedText,
              cropBounds,
            );
          }
          DebugLogService.instance.logInfo(
            'OCR zone $i edited="$cleanedText" '
            'crop=${cropBounds.width.toInt()}x${cropBounds.height.toInt()} '
            'bounds=${bounds!.width.toInt()}x${bounds.height.toInt()}',
          );
        } else {
          if (words.isNotEmpty) {
            final fullText = words.map((w) => w['text'] as String).join(' ');
            cleanedText = _cleanText(fullText);
            final tight = _unionOfWordBounds(words);
            bounds = tight != null ? tight.shift(cropBounds.topLeft) : cropBounds;
          } else {
            final fullText = await FlutterTesseractOcr.extractText(
              cropPath,
              language: 'vie',
              args: {'preserve_interword_spaces': '1'},
            );
            cleanedText = _cleanText(fullText);
            bounds = cropBounds;
          }
        }

        results.add(app.ZoneOcrResult(text: cleanedText, bounds: bounds));
      }
      return results;
    } finally {
      for (final crop in crops) {
        try {
          final file = File(crop['path'] as String);
          if (await file.exists()) await file.delete();
        } catch (error, stack) {
          DebugLogService.instance.logError(
            'Crop cleanup failed',
            error,
            stack,
          );
        }
      }
    }
  }

  /// Locate the edited text inside the recognized full text and map its
  /// character range proportionally onto [cropBounds] (single-line, LTR).
  ui.Rect _findEditedTextBoundsInText(
    String fullText,
    String targetText,
    ui.Rect cropBounds,
  ) {
    final normTarget = _normalizeLoose(targetText);
    final normFull = _normalizeLoose(fullText);
    if (normTarget.isEmpty || normFull.isEmpty) return cropBounds;
    final idx = normFull.indexOf(normTarget);
    if (idx >= 0) {
      final start = idx / normFull.length;
      final end = (idx + normTarget.length) / normFull.length;
      return ui.Rect.fromLTRB(
        cropBounds.left + cropBounds.width * start,
        cropBounds.top,
        cropBounds.left + cropBounds.width * end,
        cropBounds.bottom,
      );
    }
    return cropBounds;
  }

  ui.Rect? _unionOfWordBounds(List<Map<String, Object>> words) {
    ui.Rect? bounds;
    for (final w in words) {
      final b = w['bbox'] as ui.Rect;
      bounds = bounds == null ? b : bounds.expandToInclude(b);
    }
    return bounds;
  }

  ui.Rect? _findEditedTextBoundsInWords(
    List<Map<String, Object>> words,
    String targetText,
  ) {
    final normTarget = _normalizeLoose(targetText);
    if (normTarget.isEmpty) return null;

    final normWords = words
        .map((w) => _normalizeLoose(w['text'] as String))
        .toList();
    final full = normWords.join('');
    final idx = full.indexOf(normTarget);
    if (idx < 0) return null;
    final endIdx = idx + normTarget.length;

    ui.Rect? bounds;
    var cursor = 0;
    for (var i = 0; i < normWords.length; i++) {
      final start = cursor;
      final end = cursor + normWords[i].length;
      cursor = end;
      if (end > idx && start < endIdx) {
        final b = words[i]['bbox'] as ui.Rect;
        bounds = bounds == null ? b : bounds.expandToInclude(b);
      }
    }
    return bounds;
  }

  List<Map<String, Object>> _parseHocrWords(String hocr) {
    final words = <Map<String, Object>>[];
    final regex = RegExp(
      r"class='ocrx_word'[^>]*title='[^']*bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)[^']*'[^>]*>(.*?)</span>",
      dotAll: true,
    );
    for (final m in regex.allMatches(hocr)) {
      final x1 = double.parse(m.group(1)!);
      final y1 = double.parse(m.group(2)!);
      final x2 = double.parse(m.group(3)!);
      final y2 = double.parse(m.group(4)!);
      final text = _decodeHocrText(m.group(5)!);
      if (text.isEmpty) continue;
      words.add({
        'text': text,
        'bbox': ui.Rect.fromLTRB(x1, y1, x2, y2),
      });
    }
    return words;
  }

  String _decodeHocrText(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }

  String _cleanText(String raw) {
    var text = raw.trim();
    final leadingPunct = RegExp(r'^[\s:;\-–—]+').firstMatch(text);
    if (leadingPunct != null) {
      text = text.substring(leadingPunct.group(0)!.length).trim();
    }
    return text;
  }

  static String _normalizeLoose(String s) {
    final buffer = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      buffer.write(_diacriticMap[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static const Map<String, String> _diacriticMap = {
    'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'đ': 'd',
    'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
  };

  /// Header-only size lookup: no full-size texture is decoded just for metadata.
  Future<ui.Size> getImageSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Legacy pure-data heuristic retained for tests; not part of template-first UI.
  static List<TemplateZone> extractKeyValueZones(app.OcrResult result) {
    final zones = <TemplateZone>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final colon = line.text.indexOf(':');
        if (colon <= 0) continue;
        final label = line.text.substring(0, colon).trim();
        final value = line.text.substring(colon + 1).trim();
        if (label.isEmpty || label.length > 50 || value.isEmpty) continue;
        final elementIndex = line.elements.indexWhere(
          (e) => e.text.contains(':'),
        );
        if (elementIndex < 0) continue;
        final rects = <ui.Rect>[];
        final element = line.elements[elementIndex];
        final innerColon = element.text.indexOf(':');
        if (element.text.substring(innerColon + 1).trim().isNotEmpty) {
          rects.add(
            ui.Rect.fromLTRB(
              element.boundingBox.left +
                  element.boundingBox.width *
                      (innerColon + 1) /
                      element.text.length,
              element.boundingBox.top,
              element.boundingBox.right,
              element.boundingBox.bottom,
            ),
          );
        }
        rects.addAll(
          line.elements.skip(elementIndex + 1).map((e) => e.boundingBox),
        );
        if (rects.isEmpty) continue;
        zones.add(
          TemplateZone(
            id: _uuid.v4(),
            rect: rects.reduce((a, b) => a.expandToInclude(b)),
            label: label,
            extractedText: value,
          ),
        );
      }
    }
    return zones;
  }

  Future<void> dispose() async {
    // Tesseract has no persistent recognizer to close.
  }
}

/// Serializable paths/numbers only. One decoded page, sequential crops, no plugin.
Future<List<Map<String, Object>>> _prepareCrops(
  Map<String, Object> args,
) async {
  final regions = args['regions'] as List<List<double>>;

  // Validate regions before decoding image
  for (var i = 0; i < regions.length; i++) {
    final rect = regions[i];
    if (rect.length != 4) {
      throw FormatException('Invalid region at index $i: expected 4 values');
    }
    final left = rect[0];
    final top = rect[1];
    final right = rect[2];
    final bottom = rect[3];

    if (right <= left || bottom <= top) {
      throw FormatException(
        'Invalid region at index $i: width=${right - left}, height=${bottom - top}',
      );
    }

    if (!left.isFinite || !top.isFinite || !right.isFinite || !bottom.isFinite) {
      throw FormatException('Invalid region at index $i: non-finite values');
    }
  }

  final page = img.decodeImage(
    await File(args['imagePath'] as String).readAsBytes(),
  );
  if (page == null) throw const FormatException('Cannot decode page image');
  final oriented = img.bakeOrientation(page);
  final files = <Map<String, Object>>[];
  try {
    for (var index = 0; index < regions.length; index++) {
      final rect = regions[index];
      final left = rect[0].floor().clamp(0, oriented.width);
      final top = rect[1].floor().clamp(0, oriented.height);
      final right = rect[2].ceil().clamp(0, oriented.width);
      final bottom = rect[3].ceil().clamp(0, oriented.height);
      if (right <= left || bottom <= top) {
        throw const FormatException('Crop region is outside the page');
      }
      final path = '${args['directory']}/crop_${args['token']}_$index.png';
      files.add({
        'path': path,
        'left': left,
        'top': top,
        'width': right - left,
        'height': bottom - top,
      });
      final crop = img.copyCrop(
        oriented,
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      );

      if (crop.width <= 0 || crop.height <= 0) {
        throw FormatException(
          'Crop failed at index $index: resulted in invalid dimensions',
        );
      }

      final encoded = img.encodePng(crop);
      if (encoded.isEmpty) {
        throw FormatException('PNG encoding failed at index $index');
      }

      await File(path).writeAsBytes(encoded, flush: true);
    }
    return files;
  } catch (_) {
    for (final crop in files) {
      final file = File(crop['path'] as String);
      if (await file.exists()) await file.delete();
    }
    rethrow;
  }
}
