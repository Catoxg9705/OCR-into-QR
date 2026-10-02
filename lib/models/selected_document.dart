import 'dart:ui';

enum DocumentFormat { image, pdf }

class SelectedDocument {
  const SelectedDocument({
    required this.name,
    required this.format,
    required this.filePath,
  });

  final String name;
  final DocumentFormat format;
  final String filePath;
}

/// Raster of one page, prepared without running text recognition.
class DocumentCanvas {
  const DocumentCanvas({
    required this.imagePath,
    required this.imageSize,
    required this.pageCount,
    this.ownsImage = false,
  });

  final String imagePath;
  final Size imageSize;
  final int pageCount;

  /// Only generated PDF rasters may be deleted; never delete picked originals.
  final bool ownsImage;
}
