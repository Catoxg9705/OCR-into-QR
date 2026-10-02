import 'dart:convert';
import 'dart:io';

import 'package:doc_qr_scanner/models/selected_document.dart';
import 'package:doc_qr_scanner/screens/debug_console_screen.dart';
import 'package:doc_qr_scanner/services/debug_log_service.dart';
import 'package:doc_qr_scanner/widgets/document_preview_widget.dart';
import 'package:doc_qr_scanner/widgets/draggable_qr_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Crash entry is durable immediately and survives log reinitialization',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'doc_qr_crash_test_',
      );
      final file = File('${directory.path}/crash_history.log');
      final logger = DebugLogService.instance;
      try {
        await logger.initialize(file: file);
        await logger.clear();
        logger.logInfo('mock startup');
        logger.logError(
          'mock Flutter crash',
          StateError('mock failure'),
          StackTrace.fromString('mock_frame_one\nmock_frame_two'),
        );
        // Error is flushed before logError returns, without awaiting async writes.
        expect(file.readAsStringSync(), contains('mock failure'));
        await logger.flush();
        await logger.initialize(file: file);
        expect(logger.logs.value, hasLength(2));
        expect(logger.toClipboardText(), contains('mock_frame_two'));
        await file.writeAsString('{"incomplete', mode: FileMode.append);
        await logger.initialize(file: file);
        expect(logger.logs.value, hasLength(2));
        for (var i = 0; i < 105; i++) {
          logger.logInfo('mock record $i');
        }
        await logger.flush();
        await logger.initialize(file: file);
        expect(logger.logs.value, hasLength(100));
        expect(logger.logs.value.last, contains('mock record 104'));
        await logger.clear();
        await logger.initialize(file: file);
        expect(logger.logs.value, isEmpty);
        expect(await file.readAsString(), isEmpty);
      } finally {
        await logger.flush();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('Restored error appears in View Last Crash', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('doc_qr_console_test_'),
    ))!;
    final file = File('${directory.path}/crash_history.log');
    final logger = DebugLogService.instance;
    await tester.runAsync(() async {
      await file.writeAsString(
        '${jsonEncode('[mock time] [ERROR] - restored mock crash\nmock stack')}\n',
      );
      await logger.initialize(file: file);
    });
    await tester.pumpWidget(const MaterialApp(home: DebugConsoleScreen()));
    await tester.pumpAndSettle();
    expect(find.text('View Last Crash / Lỗi gần nhất'), findsOneWidget);
    expect(find.textContaining('restored mock crash'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await logger.clear();
      await directory.delete(recursive: true);
    });
  });

  testWidgets(
    'QR renders EMPTY safely, drags locally, commits only on confirm',
    (tester) async {
      final confirmed = <List<double>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DraggableQrOverlay(
                qrData: '',
                canvasWidth: 300,
                canvasHeight: 200,
                canvasOrigin: const Offset(40, 20),
                onConfirm: (x, y, size) => confirmed.add([x, y, size]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('QR không hợp lệ'), findsNothing);
      final before = tester.getTopLeft(find.byKey(const ValueKey('qr-box')));
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('qr-move'))),
      );
      await drag.moveBy(const Offset(30, 20));
      await tester.pump();
      await drag.moveBy(const Offset(15, 10));
      await tester.pump();
      expect(confirmed, isEmpty);
      await drag.up();
      await tester.pump();
      expect(confirmed, isEmpty);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('qr-box'))).dx,
        greaterThan(before.dx),
      );
      expect(
        identical(tester.widget<QrImageView>(find.byType(QrImageView)), qr),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('qr-confirm')));
      await tester.pump();
      expect(confirmed, hasLength(1));
      expect(confirmed.single[0], inInclusiveRange(0, 1));
      expect(confirmed.single[1], inInclusiveRange(0, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Invalid and tiny canvases are safe and recover after layout', (
    tester,
  ) async {
    Widget overlay(double w, double h) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 220,
          child: DraggableQrOverlay(
            qrData: 'Mock: Value',
            canvasWidth: w,
            canvasHeight: h,
            onConfirm: (_, _, _) {},
          ),
        ),
      ),
    );
    for (final size in [
      const Size(0, 0),
      const Size(double.nan, 40),
      const Size(double.infinity, 80),
      const Size(10, 10),
    ]) {
      await tester.pumpWidget(overlay(size.width, size.height));
      await tester.pump();
      expect(find.byKey(const ValueKey('qr-box')), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(overlay(40, 35));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qr-box')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('qr-box'))),
      const Size(35, 35),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Active canvas disables pan/scale throughout QR drag', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('doc_qr_canvas_test_'),
    ))!;
    final file = File('${directory.path}/mock.png');
    await tester.runAsync(
      () => file.writeAsBytes(img.encodePng(img.Image(width: 100, height: 80))),
    );
    final canvas = DocumentCanvas(
      imagePath: file.path,
      imageSize: const Size(100, 80),
      pageCount: 1,
    );
    final commits = <List<double>>[];
    Widget screen(bool placing) => MaterialApp(
      home: Scaffold(
        body: DocumentPreviewWidget(
          canvas: canvas,
          zones: const [],
          activeZoneId: null,
          onSelectZone: (_) {},
          onRectCommitted: (_, _) {},
          onDeleteZone: (_) {},
          onLabelTap: (_, _) {},
          isQrPlacementMode: placing,
          qrData: 'Mock: Value',
          onQrConfirmed: (x, y, size) => commits.add([x, y, size]),
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .panEnabled,
      isTrue,
    );
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.panEnabled, isFalse);
    expect(viewer.scaleEnabled, isFalse);
    final matrix = viewer.transformationController!.value.clone();
    await tester.drag(
      find.byKey(const ValueKey('qr-move')),
      const Offset(25, 10),
    );
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value, matrix);
    expect(commits, isEmpty);
    await tester.tap(find.byKey(const ValueKey('qr-confirm')));
    await tester.pump();
    expect(commits, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
}
