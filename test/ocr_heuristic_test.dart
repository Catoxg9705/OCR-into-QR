import 'dart:ui';

import 'package:doc_qr_scanner/models/ocr_result.dart';
import 'package:doc_qr_scanner/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Key-value zone chỉ bao phần giá trị sau dấu hai chấm', () {
    const result = OcrResult(
      fullText: 'Họ tên: Trần Văn A',
      imageSize: Size(400, 200),
      blocks: [
        OcrBlock(
          text: 'Họ tên: Trần Văn A',
          boundingBox: Rect.fromLTWH(10, 20, 240, 28),
          lines: [
            OcrLine(
              text: 'Họ tên: Trần Văn A',
              boundingBox: Rect.fromLTWH(10, 20, 240, 28),
              elements: [
                OcrElement(
                  text: 'Họ',
                  boundingBox: Rect.fromLTWH(10, 20, 30, 28),
                ),
                OcrElement(
                  text: 'tên:',
                  boundingBox: Rect.fromLTWH(45, 20, 40, 28),
                ),
                OcrElement(
                  text: 'Trần',
                  boundingBox: Rect.fromLTWH(95, 20, 40, 28),
                ),
                OcrElement(
                  text: 'Văn',
                  boundingBox: Rect.fromLTWH(140, 20, 40, 28),
                ),
                OcrElement(
                  text: 'A',
                  boundingBox: Rect.fromLTWH(190, 20, 20, 28),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final zones = OcrService.extractKeyValueZones(result);
    expect(zones, hasLength(1));
    expect(zones.single.label, 'Họ tên');
    expect(zones.single.extractedText, 'Trần Văn A');
    expect(zones.single.rect, const Rect.fromLTRB(95, 20, 210, 48));
  });
}
