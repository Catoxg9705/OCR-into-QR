import 'dart:ui';

/// Kết quả OCR đầy đủ từ một tài liệu
class OcrResult {
  const OcrResult({
    required this.blocks,
    required this.fullText,
    this.imageSize,
    this.previewImagePath,
  });

  final List<OcrBlock> blocks;
  final String fullText;
  final Size? imageSize;

  /// PNG trang 1 của PDF, giữ tới khi đổi tài liệu để editor có nền ổn định.
  final String? previewImagePath;

  bool get isEmpty => blocks.isEmpty;
  bool get isNotEmpty => blocks.isNotEmpty;
}

/// Recognition of one crop; bounds have been mapped into source-page pixels.
class ZoneOcrResult {
  const ZoneOcrResult({required this.text, this.bounds});

  final String text;
  final Rect? bounds;
}

/// Khối text (Block) với tọa độ bounding box
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.boundingBox,
    required this.lines,
  });

  final String text;
  final Rect boundingBox; // Tọa độ hộp bao
  final List<OcrLine> lines;
}

/// Dòng text (Line) với tọa độ bounding box
class OcrLine {
  const OcrLine({
    required this.text,
    required this.boundingBox,
    this.elements = const [],
  });

  final String text;
  final Rect boundingBox;
  final List<OcrElement> elements;
}

class OcrElement {
  const OcrElement({required this.text, required this.boundingBox});

  final String text;
  final Rect boundingBox;
}
