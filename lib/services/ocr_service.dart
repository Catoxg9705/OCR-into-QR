import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/ocr_result.dart' as app;
import '../models/template_zone.dart';
import 'debug_log_service.dart';

/// ML Kit stays on the root isolate; only pure Dart image work uses compute.
class OcrService {
  TextRecognizer? _recognizer;
  static const _uuid = Uuid();

  /// Decode a page once off the UI isolate, then recognize its crops in order.
  /// All result bounds are translated back into original page coordinates.
  /// Text is trimmed and leading punctuation (: - whitespace) is removed.
  /// Bounding boxes snap to the first valid alphanumeric character.
  /// 
  /// If [editedTexts] is provided and non-null for a zone, the method will
  /// attempt to find that edited text within the OCR elements and shrink
  /// the bounding box to match the edited text exactly.
  Future<List<app.ZoneOcrResult>> recognizeZones(
    String imagePath,
    List<ui.Rect> regions, {
    List<String?>? editedTexts,
  }) async {
    if (regions.isEmpty) return [];
    final temporaryDirectory = await getTemporaryDirectory();
    final crops = await compute(_prepareCrops, <String, Object>{
      'imagePath': imagePath,
      'directory': temporaryDirectory.path,
      'token': _uuid.v4(),
      'regions': [
        for (final rect in regions)
          [rect.left, rect.top, rect.right, rect.bottom],
      ],
    });
    try {
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final results = <app.ZoneOcrResult>[];
      for (var i = 0; i < crops.length; i++) {
        final crop = crops[i];
        // Native wrappers never cross the isolate boundary.
        final text = await recognizer.processImage(
          InputImage.fromFilePath(crop['path'] as String),
        );
        
        // Check if user edited this zone's text
        final editedText = (editedTexts != null && i < editedTexts.length) 
            ? editedTexts[i] 
            : null;
        
        String cleanedText;
        ui.Rect? detected;
        double leftAdjustment = 0.0;
        
        if (editedText != null && editedText.isNotEmpty) {
          // User has edited text - find it within ML Kit elements and shrink box
          cleanedText = editedText.trim();
          detected = _findEditedTextBounds(text, cleanedText);
        } else {
          // Original auto-trim logic: strip leading punctuation/whitespace
          cleanedText = text.text.trim();
          final leadingPunctMatch = RegExp(r'^[\s:;\-–—]+').firstMatch(cleanedText);
          final trimmedChars = leadingPunctMatch?.group(0)?.length ?? 0;
          if (trimmedChars > 0) {
            cleanedText = cleanedText.substring(trimmedChars).trim();
          }
          
          // Find the first valid text element and adjust bounding box
          outerLoop:
          for (final block in text.blocks) {
            for (final line in block.lines) {
              if (line.text.trim().isEmpty) continue;
              
              // Check if this line contains the cleaned text start
              if (trimmedChars > 0 && cleanedText.isNotEmpty) {
                // Find first element that contains alphanumeric after punctuation
                for (final element in line.elements) {
                  final elemText = element.text.trim();
                  if (elemText.isEmpty) continue;
                  
                  // Skip elements that are pure punctuation
                  if (RegExp(r'^[\s:;\-–—]+$').hasMatch(elemText)) {
                    continue;
                  }
                  
                  // This is the first valid element - snap to its left edge
                  if (detected == null) {
                    leftAdjustment = element.boundingBox.left;
                  }
                  detected = detected == null
                      ? element.boundingBox
                      : detected.expandToInclude(element.boundingBox);
                }
              } else {
                // No trimming needed, use original logic
                detected = detected == null
                    ? line.boundingBox
                    : detected.expandToInclude(line.boundingBox);
              }
              
              if (detected != null) break outerLoop;
            }
          }
        }
        
        final origin = ui.Offset(
          (crop['left'] as num).toDouble(),
          (crop['top'] as num).toDouble(),
        );
        final cropBounds = ui.Rect.fromLTWH(
          origin.dx,
          origin.dy,
          (crop['width'] as num).toDouble(),
          (crop['height'] as num).toDouble(),
        );
        
        // Translate detected bounds back to page coordinates
        var bounds = detected?.shift(origin).intersect(cropBounds);
        
        // Apply left adjustment only for auto-trimmed punctuation (not edited text)
        if (bounds != null && !bounds.isEmpty && leftAdjustment > 0 && editedText == null) {
          bounds = ui.Rect.fromLTRB(
            origin.dx + leftAdjustment,
            bounds.top,
            bounds.right,
            bounds.bottom,
          );
        }
        
        results.add(
          app.ZoneOcrResult(
            text: cleanedText,
            bounds: bounds == null || bounds.isEmpty ? null : bounds,
          ),
        );
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

  /// Find exact bounding box for edited text within ML Kit elements.
  /// Returns null if text cannot be matched.
  ui.Rect? _findEditedTextBounds(RecognizedText recognizedText, String targetText) {
    if (targetText.isEmpty) return null;
    
    // Normalize target for matching
    final normalizedTarget = targetText.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    
    ui.Rect? bounds;
    
    // Try to find exact match by iterating through elements
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        // Build accumulated text from elements
        final elements = line.elements;
        for (var i = 0; i < elements.length; i++) {
          var accumulated = '';
          ui.Rect? tempBounds;
          
          // Try starting from this element
          for (var j = i; j < elements.length; j++) {
            accumulated += elements[j].text;
            final normalizedAccum = accumulated.toLowerCase().replaceAll(RegExp(r'\s+'), '');
            
            // Update bounds
            tempBounds = tempBounds == null 
                ? elements[j].boundingBox 
                : tempBounds.expandToInclude(elements[j].boundingBox);
            
            // Check if we have a match
            if (normalizedAccum == normalizedTarget) {
              return tempBounds;
            }
            
            // If we've gone too far, break
            if (normalizedAccum.length > normalizedTarget.length) {
              break;
            }
          }
        }
        
        // Also try full line match
        final lineNormalized = line.text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        if (lineNormalized == normalizedTarget) {
          return line.boundingBox;
        }
      }
    }
    
    // Fallback: if no exact match, return the bounds of all text
    // (this preserves original behavior when edited text doesn't match)
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        bounds = bounds == null 
            ? line.boundingBox 
            : bounds.expandToInclude(line.boundingBox);
      }
    }
    
    return bounds;
  }

  /// Smart baseline expansion: find TextLine containing the template zone's start,
  /// then extract ALL elements on that baseline (same Y-axis) to capture full names.
  /// This handles variable-length text (e.g., "Trần Hùng" vs "Nguyễn Thị Bích Ngân").
  Future<List<String>> extractWithBaselineExpansion(
    String imagePath,
    List<TemplateZone> templateZones,
    ui.Size imageSize,
  ) async {
    if (templateZones.isEmpty) return [];
    
    final recognizer = _recognizer ??= TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    
    final text = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    
    final results = <String>[];
    
    for (final zone in templateZones) {
      // Convert zone's sampling rect (or rect) to absolute coordinates
      final searchRect = zone.samplingRect ?? zone.rect;
      
      String? extractedValue;
      
      // Find TextLine whose start point falls within the search rect
      for (final block in text.blocks) {
        for (final line in block.lines) {
          // Check if line's left edge is within the zone horizontally
          // and line's Y position overlaps the zone vertically
          if (line.boundingBox.left >= searchRect.left &&
              line.boundingBox.left <= searchRect.right &&
              line.boundingBox.top <= searchRect.bottom &&
              line.boundingBox.bottom >= searchRect.top) {
            
            // Found the matching line - extract all elements on this baseline
            final baseline = line.boundingBox.top + (line.boundingBox.height / 2);
            final tolerance = line.boundingBox.height * 0.3; // 30% tolerance
            
            // Collect all elements on the same horizontal baseline
            final baselineElements = <TextElement>[];
            for (final elem in line.elements) {
              final elemBaseline = elem.boundingBox.top + (elem.boundingBox.height / 2);
              if ((elemBaseline - baseline).abs() <= tolerance) {
                baselineElements.add(elem);
              }
            }
            
            // Join all elements into final text
            if (baselineElements.isNotEmpty) {
              extractedValue = baselineElements
                  .map((e) => e.text)
                  .join(' ')
                  .trim();
              
              // Clean up leading punctuation
              final leadingPunctMatch = RegExp(r'^[\s:;\-–—]+').firstMatch(extractedValue);
              final trimmedChars = leadingPunctMatch?.group(0)?.length ?? 0;
              if (trimmedChars > 0) {
                extractedValue = extractedValue.substring(trimmedChars).trim();
              }
            }
            break;
          }
        }
        if (extractedValue != null) break;
      }
      
      results.add(extractedValue ?? '');
    }
    
    return results;
  }

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
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer != null) await recognizer.close();
  }
}

/// Serializable paths/numbers only. One decoded page, sequential crops, no plugin.
Future<List<Map<String, Object>>> _prepareCrops(
  Map<String, Object> args,
) async {
  final page = img.decodeImage(
    await File(args['imagePath'] as String).readAsBytes(),
  );
  if (page == null) throw const FormatException('Cannot decode page image');
  final oriented = img.bakeOrientation(page);
  final regions = args['regions'] as List<List<double>>;
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
      await File(path).writeAsBytes(img.encodePng(crop), flush: true);
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
