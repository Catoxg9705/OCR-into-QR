import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';

import '../models/batch_result.dart';
import '../models/selected_document.dart';
import '../models/template_zone.dart';
import 'debug_log_service.dart';
import 'document_picker_service.dart';
import 'ocr_coordinator_service.dart';

class DocumentState extends ChangeNotifier {
  DocumentState({
    DocumentPickerService? pickerService,
    OcrCoordinatorService? ocrService,
  }) : _picker = pickerService ?? DocumentPickerService(),
       _ocr = ocrService ?? OcrCoordinatorService();

  final DocumentPickerService _picker;
  final OcrCoordinatorService _ocr;
  SelectedDocument? _document;
  DocumentCanvas? _canvas;
  List<TemplateZone> _zones = [];
  String? _activeZoneId;
  String? _errorMessage;
  BatchResult? _batchResult;
  bool _isLoading = false;
  bool _isProcessingOcr = false;
  bool _isProcessingBatch = false;
  bool _isPanelVisible = false;
  bool _disposed = false;
  bool _notificationScheduled = false;
  int _generation = 0;
  int _processedPages = 0;

  // QR placement mode state
  bool _isQrPlacementMode = false;
  Offset? _qrPosition;
  double _qrSize = 30.0;
  String _qrPayload = 'EMPTY';

  SelectedDocument? get document => _document;
  DocumentCanvas? get canvas => _canvas;
  List<TemplateZone> get zones => List.unmodifiable(_zones);
  String? get activeZoneId => _activeZoneId;
  String? get errorMessage => _errorMessage;
  BatchResult? get batchResult => _batchResult;
  bool get isLoading => _isLoading;
  bool get isProcessingOcr => _isProcessingOcr;
  bool get isProcessingBatch => _isProcessingBatch;
  bool get isPanelVisible => _isPanelVisible;
  int get processedPages => _processedPages;
  bool get isBusy => _isLoading || _isProcessingOcr || _isProcessingBatch;
  bool get canBatch =>
      !isBusy &&
      _document?.format == DocumentFormat.pdf &&
      _zones.isNotEmpty &&
      _zones.every((z) => (z.isStatic || !z.isManual) && z.label.trim().isNotEmpty);

  // QR placement getters
  bool get isQrPlacementMode => _isQrPlacementMode;
  Offset? get qrPosition => _qrPosition;
  double get qrSize => _qrSize;
  String get qrPayload => _qrPayload;

  // Coalesce a rare build-phase notification; gesture updates never call this.
  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } else {
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  void setPanelVisible(bool visible) {
    if (_disposed || isBusy) return;
    _isPanelVisible = visible && _zones.any((z) => !z.isManual || z.isStatic);
    _notify();
  }

  void selectZone(String id, {bool fromCanvas = false}) {
    if (_disposed || isBusy || !_zones.any((z) => z.id == id)) return;
    _activeZoneId = id;
    if (fromCanvas) _isPanelVisible = false;
    _notify();
  }

  void updateZoneLabel(String id, String label) {
    if (_disposed || isBusy) return;
    _zones = [
      for (final z in _zones)
        if (z.id == id) z.copyWith(label: label) else z,
    ];
    _batchResult = null;
    _notify();
  }

  void updateZoneValue(String id, String value) {
    if (_disposed || isBusy) return;
    _zones = [
      for (final z in _zones)
        if (z.id == id) z.copyWith(extractedText: value) else z,
    ];
    _batchResult = null;
    _notify();
  }

  void reorderZones(int oldIndex, int newIndex) {
    if (_disposed || isBusy) return;
    // onReorderItem callback already provides the adjusted newIndex
    final mutable = List<TemplateZone>.from(_zones);
    final zone = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, zone);
    _zones = mutable;
    _batchResult = null;
    _notify();
  }

  void enterQrPlacementMode() {
    final page = _canvas;
    if (_disposed || isBusy || page == null || !canBatch) return;
    final size = page.imageSize;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      _errorMessage = 'Kích thước canvas không hợp lệ';
      _notify();
      return;
    }
    // Build payload with ALL fields (static + OCR), respecting user's ordering
    final payload = _zones
        .map((zone) => '${zone.label}: ${zone.extractedText}')
        .join('\n');
    _qrPayload = payload.trim().isEmpty ? 'EMPTY' : payload;
    _batchResult = null;
    _isQrPlacementMode = true;
    _isPanelVisible = false;
    _activeZoneId = null;
    _qrSize = math.min(30, math.min(size.width, size.height) * 0.15);
    _qrPosition = Offset(
      math.max(0, (size.width - _qrSize) / 2),
      math.max(0, (size.height - _qrSize) / 2),
    );
    _notify(); // One transition only; drag uses the widget's local state.
  }

  /// Called ONLY by the confirm button, never by onPanUpdate.
  bool confirmQrPlacement(
    double relativeX,
    double relativeY,
    double relativeSize,
  ) {
    final page = _canvas;
    if (_disposed || isBusy || !_isQrPlacementMode || page == null) {
      return false;
    }
    if (!relativeX.isFinite ||
        !relativeY.isFinite ||
        !relativeSize.isFinite ||
        relativeSize <= 0 ||
        page.imageSize.width <= 0 ||
        page.imageSize.height <= 0) {
      return false;
    }
    _qrSize = math.min(
      relativeSize * page.imageSize.width,
      math.min(page.imageSize.width, page.imageSize.height),
    );
    _qrPosition = Offset(
      (relativeX * page.imageSize.width).clamp(
        0.0,
        math.max(0, page.imageSize.width - _qrSize),
      ),
      (relativeY * page.imageSize.height).clamp(
        0.0,
        math.max(0, page.imageSize.height - _qrSize),
      ),
    );
    _isQrPlacementMode = false;
    _notify();
    return true;
  }

  void cancelQrPlacement() {
    if (_disposed) return;
    _isQrPlacementMode = false;
    _qrPosition = null;
    _isPanelVisible = true;
    _notify();
  }

  void addZone() {
    final page = _canvas;
    if (_disposed || isBusy || page == null) return;
    final zone = TemplateZone(
      id: const Uuid().v4(),
      rect: Rect.fromCenter(
        center: Offset(page.imageSize.width / 2, page.imageSize.height / 2),
        width: page.imageSize.width * 0.3,
        height: page.imageSize.height * 0.06,
      ),
      label: 'Trường ${_zones.length + 1}',
      extractedText: '',
      isManual: true,
    );
    _zones = [..._zones, zone];
    _activeZoneId = zone.id;
    _isPanelVisible = false;
    _batchResult = null;
    _notify();
  }

  void addStaticField() {
    if (_disposed || isBusy) return;
    final zone = TemplateZone(
      id: const Uuid().v4(),
      rect: Rect.zero,
      label: '',
      extractedText: '',
      isStatic: true,
      isManual: false,
    );
    _zones = [..._zones, zone];
    _batchResult = null;
    _notify();
  }

  /// Exactly one atomic commit from onPanEnd (position and size together).
  void updateZoneRect(String id, Rect rect) {
    final page = _canvas;
    if (_disposed || isBusy || page == null) return;
    final bounded = rect.intersect(Offset.zero & page.imageSize);
    if (bounded.isEmpty || !bounded.isFinite) return;
    _zones = [
      for (final z in _zones)
        if (z.id == id && z.rect != bounded)
          z.copyWith(rect: bounded, samplingRect: bounded, isManual: true)
        else
          z,
    ];
    _batchResult = null;
    _isPanelVisible = false;
    _notify();
  }

  void deleteZone(String id) {
    if (_disposed || isBusy) return;
    _zones = _zones.where((z) => z.id != id).toList();
    if (_activeZoneId == id) _activeZoneId = null;
    if (_zones.isEmpty) _isPanelVisible = false;
    _batchResult = null;
    _notify();
  }

  Future<void> pickDocument() async {
    if (_disposed || isBusy) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    final generation = _generation;
    try {
      final doc = await _picker.pickDocument();
      if (doc == null || _disposed) return;
      final page = await _ocr.prepareDocument(
        doc,
      ); // Render only. No recognizer.
      if (_disposed || generation != _generation) {
        await _ocr.releaseCanvas(page);
        return;
      }
      final old = _canvas;
      _document = doc;
      _canvas = page;
      _zones = [];
      _activeZoneId = null;
      _isPanelVisible = false;
      _batchResult = null;
      _processedPages = 0;
      _isQrPlacementMode = false;
      _qrPosition = null;
      _qrPayload = 'EMPTY';
      _generation++;
      _notify();
      await _ocr.releaseCanvas(old);
      DebugLogService.instance.logInfo(
        'Page 1 canvas ready (${page.pageCount} pages); no auto OCR',
      );
    } catch (error, stack) {
      if (!_disposed) _errorMessage = 'Không thể mở tài liệu: $error';
      DebugLogService.instance.logError('Open document failed', error, stack);
    } finally {
      _isLoading = false;
      _finishOperation();
    }
  }

  Future<void> scanFields() async {
    final page = _canvas;
    if (_disposed || isBusy || page == null || _zones.isEmpty) return;
    final snapshot = List<TemplateZone>.of(_zones);
    final generation = _generation;
    _isProcessingOcr = true;
    _errorMessage = null;
    _notify();
    try {
      // Skip OCR for static fields; only scan non-static fields
      final nonStaticZones = snapshot.where((z) => !z.isStatic).toList();
      final editedTexts = nonStaticZones.map((z) => z.extractedText).toList();

      final results = await _ocr.scanZones(
        page,
        nonStaticZones.map((z) => z.samplingRect ?? z.rect).toList(),
        editedTexts: editedTexts,
      );
      if (_disposed || generation != _generation) return;
      
      var emptyCount = 0;
      var resultIndex = 0;
      final List<TemplateZone> newZones = [];
      for (var i = 0; i < snapshot.length; i++) {
        if (snapshot[i].isStatic) {
          newZones.add(snapshot[i]); // Keep static fields unchanged
        } else {
          if (results[resultIndex].text.isEmpty || results[resultIndex].bounds == null) {
            // Skip empty results - do not add to newZones, auto-delete failed fields
            emptyCount++;
          } else {
            newZones.add(snapshot[i].copyWith(
              extractedText: results[resultIndex].text,
              rect: results[resultIndex].bounds,
              samplingRect: snapshot[i].samplingRect ?? snapshot[i].rect,
              isManual: false,
            ));
          }
          resultIndex++;
        }
      }
      _zones = newZones;
      _activeZoneId =
          null; // Black shrink-wrapped borders, tap reactivates controls.
      _isPanelVisible = _zones.any((z) => !z.isManual || z.isStatic);
      _batchResult = null;
      if (emptyCount > 0) {
        _errorMessage =
            'Không tìm thấy chữ trong $emptyCount trường; hãy điều chỉnh và quét lại.';
      }
      DebugLogService.instance.logInfo(
        'Confirmed ${nonStaticZones.length - emptyCount}/${nonStaticZones.length} fields on page 1',
      );
    } catch (error, stack) {
      if (!_disposed) _errorMessage = 'Lỗi quét trường: $error';
      DebugLogService.instance.logError('Scan fields failed', error, stack);
    } finally {
      _isProcessingOcr = false;
      _finishOperation();
    }
  }

  Future<void> applyTemplateToAllPages() async {
    if (_disposed || !canBatch) return;
    final doc = _document!;
    final pageOne = _canvas!;
    final snapshot = List<TemplateZone>.of(_zones);
    final qrPos = _qrPosition;

    // Only non-static zones need relative coordinates for OCR on other pages
    final nonStaticZones = snapshot.where((z) => !z.isStatic).toList();
    final relative = [
      for (final z in nonStaticZones)
        z.toRelativeRect(pageOne.imageSize, forSampling: true),
    ];

    // QR relative coordinates (optional, only needed for PDF export)
    final double? qrRelX = qrPos != null
        ? qrPos.dx / pageOne.imageSize.width
        : null;
    final double? qrRelY = qrPos != null
        ? qrPos.dy / pageOne.imageSize.height
        : null;
    final double? qrRelSize = qrPos != null
        ? _qrSize / pageOne.imageSize.width
        : null;

    final generation = _generation;
    _isProcessingBatch = true;
    _errorMessage = null;
    _batchResult = null;
    _processedPages = 1;
    _isQrPlacementMode = false;
    _notify();
    try {
      final pages = <PageData>[
        PageData(
          pageNumber: 1,
          fields: [
            for (final z in snapshot)
              PageField(zoneId: z.id, label: z.label, value: z.extractedText),
          ],
        ),
      ]; // Preserve manually corrected Page 1 values, never rescan it in batch.
      for (var number = 2; number <= pageOne.pageCount; number++) {
        if (_disposed || generation != _generation) return;
        final page = await _ocr.preparePage(doc.filePath, number);
        try {
          if (_disposed) return;
          // Only scan non-static zones
          final results = await _ocr.scanZones(page, [
            for (final r in relative)
              TemplateZone.fromRelativeRect(r, page.imageSize),
          ]);
          if (_disposed || generation != _generation) return;
          
          // Build fields: static values from page 1 + OCR results
          var resultIndex = 0;
          pages.add(
            PageData(
              pageNumber: number,
              fields: [
                for (final zone in snapshot)
                  if (zone.isStatic)
                    PageField(
                      zoneId: zone.id,
                      label: zone.label,
                      value: zone.extractedText, // Use static value from page 1
                    )
                  else
                    PageField(
                      zoneId: zone.id,
                      label: zone.label,
                      value: results[resultIndex++].text,
                    ),
              ],
            ),
          );
          _processedPages = number;
          _notify(); // Once per page, never per gesture/crop.
          DebugLogService.instance.logInfo(
            'Batch page $number/${pageOne.pageCount} done',
          );
        } finally {
          await _ocr.releaseCanvas(page);
        }
      }
      if (!_disposed) {
        _batchResult = BatchResult(
          documentName: doc.name,
          totalPages: pageOne.pageCount,
          pages: pages,
          processedAt: DateTime.now(),
          qrRelativeX: qrRelX,
          qrRelativeY: qrRelY,
          qrRelativeSize: qrRelSize,
        );
      }
    } catch (error, stack) {
      if (!_disposed) _errorMessage = 'Lỗi xử lý hàng loạt: $error';
      DebugLogService.instance.logError('Batch failed', error, stack);
    } finally {
      _isProcessingBatch = false;
      _finishOperation();
    }
  }

  void updateBatchFieldValue(int pageNumber, int fieldIndex, String newValue) {
    if (_disposed || _batchResult == null) return;
    final pages = List<PageData>.from(_batchResult!.pages);
    final pageIndex = pages.indexWhere((p) => p.pageNumber == pageNumber);
    if (pageIndex == -1 || fieldIndex >= pages[pageIndex].fields.length) return;
    
    final updatedFields = List<PageField>.from(pages[pageIndex].fields);
    updatedFields[fieldIndex] = updatedFields[fieldIndex].copyWith(value: newValue);
    
    pages[pageIndex] = pages[pageIndex].copyWith(fields: updatedFields);
    _batchResult = _batchResult!.copyWith(pages: pages);
    _notify();
  }

  void clearBatchResult() {
    _batchResult = null;
    _notify();
  }

  void clearDocument() {
    if (_disposed || isBusy) return;
    final old = _canvas;
    _generation++;
    _document = null;
    _canvas = null;
    _zones = [];
    _activeZoneId = null;
    _errorMessage = null;
    _isPanelVisible = false;
    _batchResult = null;
    _isQrPlacementMode = false;
    _qrPosition = null;
    _qrPayload = 'EMPTY';
    _notify();
    unawaited(_ocr.releaseCanvas(old));
  }

  void _finishOperation() {
    if (_disposed) {
      unawaited(_releaseResources());
    } else {
      _notify();
    }
  }

  Future<void> _releaseResources() async {
    final page = _canvas;
    _canvas = null;
    await _ocr.releaseCanvas(page);
    await _ocr.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    // Do not close native recognizer or delete image during in-flight work.
    if (!isBusy) unawaited(_releaseResources());
    super.dispose();
  }
}
