/// Structured per-page records for a future QR generation step.
class BatchResult {
  BatchResult({
    required this.documentName,
    required this.totalPages,
    required List<PageData> pages,
    required this.processedAt,
    this.qrRelativeX,
    this.qrRelativeY,
    this.qrRelativeSize,
  }) : pages = List.unmodifiable(pages);

  final String documentName;
  final int totalPages;
  final List<PageData> pages;
  final DateTime processedAt;
  final double? qrRelativeX;
  final double? qrRelativeY;
  final double? qrRelativeSize;

  BatchResult copyWith({
    String? documentName,
    int? totalPages,
    List<PageData>? pages,
    DateTime? processedAt,
    double? qrRelativeX,
    double? qrRelativeY,
    double? qrRelativeSize,
  }) {
    return BatchResult(
      documentName: documentName ?? this.documentName,
      totalPages: totalPages ?? this.totalPages,
      pages: pages ?? this.pages,
      processedAt: processedAt ?? this.processedAt,
      qrRelativeX: qrRelativeX ?? this.qrRelativeX,
      qrRelativeY: qrRelativeY ?? this.qrRelativeY,
      qrRelativeSize: qrRelativeSize ?? this.qrRelativeSize,
    );
  }

  Map<String, Object> toJson() => {
    'documentName': documentName,
    'totalPages': totalPages,
    'processedAt': processedAt.toIso8601String(),
    'pages': pages.map((page) => page.toJson()).toList(),
    ...?qrRelativeX != null ? {'qrRelativeX': qrRelativeX!} : null,
    ...?qrRelativeY != null ? {'qrRelativeY': qrRelativeY!} : null,
    ...?qrRelativeSize != null ? {'qrRelativeSize': qrRelativeSize!} : null,
  };
}

class PageData {
  PageData({required this.pageNumber, required List<PageField> fields})
    : fields = List.unmodifiable(fields);

  final int pageNumber;
  final List<PageField> fields;

  PageData copyWith({int? pageNumber, List<PageField>? fields}) {
    return PageData(
      pageNumber: pageNumber ?? this.pageNumber,
      fields: fields ?? this.fields,
    );
  }

  Map<String, Object> toJson() => {
    'pageNumber': pageNumber,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// IDs preserve distinct fields even if users give two fields the same label.
class PageField {
  const PageField({
    required this.zoneId,
    required this.label,
    required this.value,
  });

  final String zoneId;
  final String label;
  final String value;

  PageField copyWith({String? zoneId, String? label, String? value}) {
    return PageField(
      zoneId: zoneId ?? this.zoneId,
      label: label ?? this.label,
      value: value ?? this.value,
    );
  }

  Map<String, String> toJson() => {
    'zoneId': zoneId,
    'label': label,
    'value': value,
  };
}
