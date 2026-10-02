import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doc_qr_scanner/main.dart';
import 'package:doc_qr_scanner/models/batch_result.dart';
import 'package:doc_qr_scanner/models/ocr_result.dart';
import 'package:doc_qr_scanner/models/selected_document.dart';
import 'package:doc_qr_scanner/services/document_picker_service.dart';
import 'package:doc_qr_scanner/services/document_state.dart';
import 'package:doc_qr_scanner/services/ocr_coordinator_service.dart';
import 'package:doc_qr_scanner/widgets/interactive_zone.dart';
import 'package:doc_qr_scanner/widgets/zone_editor_panel.dart';

class _MockPicker extends DocumentPickerService {
  @override
  Future<SelectedDocument?> pickDocument() async => const SelectedDocument(
    name: 'mock.pdf',
    format: DocumentFormat.pdf,
    filePath: 'mock.pdf',
  );
}

class _MockOcr extends OcrCoordinatorService {
  final List<int> pagesRendered = [];
  final List<List<Rect>> scanRects = [];
  final List<String> released = [];
  Completer<List<ZoneOcrResult>>? pendingScan;
  bool closed = false;

  @override
  Future<DocumentCanvas> prepareDocument(SelectedDocument document) async {
    pagesRendered.add(1);
    return const DocumentCanvas(
      imagePath: 'page1.png',
      imageSize: Size(1000, 800),
      pageCount: 3,
      ownsImage: true,
    );
  }

  @override
  Future<DocumentCanvas> preparePage(String pdfPath, int number) async {
    pagesRendered.add(number);
    return DocumentCanvas(
      imagePath: 'page$number.png',
      imageSize: const Size(2000, 1600),
      pageCount: 1,
      ownsImage: true,
    );
  }

  @override
  Future<List<ZoneOcrResult>> scanZones(
    DocumentCanvas page,
    List<Rect> rects, {
    List<String?>? editedTexts,
  }) async {
    scanRects.add(rects);
    if (pendingScan != null) return pendingScan!.future;
    return [
      for (final rect in rects)
        ZoneOcrResult(text: 'Mock value', bounds: rect.deflate(4)),
    ];
  }

  @override
  Future<void> releaseCanvas(DocumentCanvas? canvas) async {
    if (canvas != null) released.add(canvas.imagePath);
  }

  @override
  Future<void> dispose() async {
    closed = true;
  }
}

void main() {
  testWidgets(
    'Root Provider boots past first frame without late/context errors',
    (tester) async {
      await tester.pumpWidget(const DocQrScannerApp());
      await tester.pumpAndSettle();
      expect(find.text('Doc QR Scanner'), findsOneWidget);
      expect(find.text('Chọn tài liệu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Render-only, atomic gesture commit, shrink-wrap and batch start at page 2',
    (tester) async {
      final ocr = _MockOcr();
      final state = DocumentState(
        pickerService: _MockPicker(),
        ocrService: ocr,
      );
      await state.pickDocument();
      expect(ocr.scanRects, isEmpty); // Opening never performs recognition.
      expect(state.canvas!.pageCount, 3);
      expect(state.isPanelVisible, isFalse);
      state.addZone();
      final id = state.zones.single.id;
      final sampling = state.zones.single.rect;
      var notices = 0;
      state.addListener(() => notices++);
      state.updateZoneRect(id, sampling.shift(const Offset(5, 2)));
      expect(notices, 1);
      final confirmedSampling = state.zones.single.rect;
      await state.scanFields();
      expect(state.isPanelVisible, isTrue);
      expect(state.zones.single.rect, confirmedSampling.deflate(4));
      expect(state.zones.single.samplingRect, confirmedSampling);
      expect(state.canBatch, isTrue);
      state.updateZoneLabel(id, 'Họ tên');
      state.updateZoneValue(id, 'Corrected mock value');
      await state.applyTemplateToAllPages();
      expect(ocr.pagesRendered, [1, 2, 3]);
      expect(
        ocr.scanRects,
        hasLength(3),
      ); // page1 confirmed once, then page2 and page3 scanned individually.
      expect(
        ocr.scanRects[1].single,
        Rect.fromLTWH(
          confirmedSampling.left * 2,
          confirmedSampling.top * 2,
          confirmedSampling.width * 2,
          confirmedSampling.height * 2,
        ),
      );
      final batch = state.batchResult!;
      expect(batch.pages.map((p) => p.pageNumber), [1, 2, 3]);
      expect(batch.pages.first.fields.single.value, 'Corrected mock value');
      expect(batch.pages[1].fields.single.zoneId, id);
      expect(batch.pages[1].fields.single.label, 'Họ tên');
      expect(ocr.released, containsAll(['page2.png', 'page3.png']));
      expect(batch.toJson()['pages'], isA<List<Map<String, Object>>>());
      state.dispose();
      await tester.pump();
      expect(ocr.closed, isTrue);
    },
  );

  testWidgets(
    'Dispose during OCR ignores stale result and defers resource cleanup',
    (tester) async {
      final ocr = _MockOcr();
      final state = DocumentState(
        pickerService: _MockPicker(),
        ocrService: ocr,
      );
      await state.pickDocument();
      state.addZone();
      final rect = state.zones.single.rect;
      ocr.pendingScan = Completer<List<ZoneOcrResult>>();
      final task = state.scanFields();
      state.dispose();
      expect(ocr.closed, isFalse);
      ocr.pendingScan!.complete([ZoneOcrResult(text: 'Mock', bounds: rect)]);
      await task;
      await tester.pump();
      expect(ocr.closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Invisible resize and toolbar move publish only once on release',
    (tester) async {
      final commits = <Rect>[];
      Widget zone() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveZone(
                  zoneId: 'z',
                  initialRect: const Rect.fromLTWH(100, 100, 120, 60),
                  imageSize: const Size(600, 400),
                  origin: Offset.zero,
                  scale: 1,
                  label: 'Mock field',
                  isActive: true,
                  isScanned: false,
                  onRectCommitted: commits.add,
                  onTap: () {},
                  onLabelTap: () {},
                  onDelete: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(zone());
      final move = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('z-move'))),
      );
      await move.moveBy(const Offset(25, 15));
      await tester.pump();
      await move.moveBy(const Offset(10, 5));
      await tester.pump();
      expect(commits, isEmpty);
      await move.up();
      await tester.pump();
      expect(commits, hasLength(1));
      expect(commits.single.left, greaterThan(100));
      final resize = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('z-resize-bottomRight'))),
      );
      await resize.moveBy(const Offset(25, 20));
      await tester.pump();
      await resize.moveBy(const Offset(10, 5));
      await tester.pump();
      expect(commits, hasLength(1));
      await resize.up();
      await tester.pump();
      expect(commits, hasLength(2));
      expect(commits.last.width, greaterThan(commits.first.width));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Collapsed sheet stays scrollable on short viewport/keyboard', (
    tester,
  ) async {
    final state = DocumentState(
      pickerService: _MockPicker(),
      ocrService: _MockOcr(),
    );
    await state.pickDocument();
    state.addZone();
    await state.scanFields();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: MediaQuery(
            data: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: SizedBox(
              height: 200,
              width: 320,
              child: Stack(
                children: [
                  ZoneEditorPanel(
                    zones: state.zones,
                    onClose: () {},
                    onUpdateLabel: state.updateZoneLabel,
                    onUpdateValue: state.updateZoneValue,
                    onDeleteZone: state.deleteZone,
                    onReorder: (oldIndex, newIndex) {},
                    onConfirmAndPlaceQR: () {},
                    canPlaceQR: true,
                    onAddStaticField: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final list = find.byType(CustomScrollView);
    await tester.drag(list, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QR mode compiles ordered values, validates confirmation and resets',
    (tester) async {
      final state = DocumentState(
        pickerService: _MockPicker(),
        ocrService: _MockOcr(),
      );
      await state.pickDocument();
      state.addZone();
      state.addZone();
      await state.scanFields();
      final first = state.zones[0].id;
      final second = state.zones[1].id;
      state.updateZoneLabel(first, 'Name');
      state.updateZoneValue(first, 'Mock User');
      state.updateZoneLabel(second, 'D.O.B');
      state.updateZoneValue(second, '15/04/1978');
      state.reorderZones(1, 0);
      state.enterQrPlacementMode();
      expect(state.qrPayload, 'D.O.B: 15/04/1978\nName: Mock User');
      expect(state.isPanelVisible, isFalse);
      final position = state.qrPosition;
      expect(state.confirmQrPlacement(double.nan, 0.5, 0.1), isFalse);
      expect(state.qrPosition, position);
      var notifications = 0;
      state.addListener(() => notifications++);
      expect(state.confirmQrPlacement(0.25, 0.4, 0.1), isTrue);
      expect(notifications, 1);
      expect(state.qrPosition, const Offset(250, 320));
      expect(state.qrSize, 100);
      expect(state.isQrPlacementMode, isFalse);
      state.clearDocument();
      expect(state.qrPosition, isNull);
      expect(state.qrPayload, 'EMPTY');
      state.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test('Structured fields do not overwrite duplicate labels', () {
    final page = PageData(
      pageNumber: 1,
      fields: const [
        PageField(zoneId: 'a', label: 'Name', value: 'Mock A'),
        PageField(zoneId: 'b', label: 'Name', value: 'Mock B'),
      ],
    );
    expect(page.fields, hasLength(2));
    expect((page.toJson()['fields'] as List), hasLength(2));
  });
}
