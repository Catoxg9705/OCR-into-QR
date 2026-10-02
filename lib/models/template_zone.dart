import 'dart:ui';

/// Vùng template đại diện cho một trường dữ liệu (field) trên tài liệu
/// Có thể được tạo tự động (auto key-value) hoặc chỉnh sửa thủ công
class TemplateZone {
  TemplateZone({
    required this.id,
    required this.rect,
    required this.label,
    required this.extractedText,
    this.isEditingLabel = false,
    this.isManual = false,
    this.isStatic = false,
    this.samplingRect,
  });

  /// ID duy nhất của zone
  final String id;

  /// Hình chữ nhật bao quanh vùng text (tọa độ trên ảnh gốc)
  final Rect rect;

  /// Keep the user-defined ROI for later pages; shrink-wrap is display-only.
  final Rect? samplingRect;

  /// Nhãn/tên trường (ví dụ: "Họ tên", "Ngày sinh", "Số hiệu")
  final String label;

  /// Nội dung text đã trích xuất trong vùng này
  final String extractedText;

  /// Trạng thái đang chỉnh sửa label hay không
  final bool isEditingLabel;

  /// Đánh dấu zone được tạo thủ công (chưa quét) hay đã quét xong
  final bool isManual;

  /// Đánh dấu trường thông tin tĩnh (không cần OCR, áp dụng cho mọi trang)
  final bool isStatic;

  /// Copy với thay đổi một số field
  TemplateZone copyWith({
    String? id,
    Rect? rect,
    String? label,
    String? extractedText,
    bool? isEditingLabel,
    bool? isManual,
    bool? isStatic,
    Rect? samplingRect,
  }) {
    return TemplateZone(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      label: label ?? this.label,
      extractedText: extractedText ?? this.extractedText,
      isEditingLabel: isEditingLabel ?? this.isEditingLabel,
      isManual: isManual ?? this.isManual,
      isStatic: isStatic ?? this.isStatic,
      samplingRect: samplingRect ?? this.samplingRect,
    );
  }

  /// Chuyển rect thành tọa độ tương đối (0.0-1.0) dựa trên kích thước ảnh gốc
  Map<String, double> toRelativeRect(
    Size imageSize, {
    bool forSampling = false,
  }) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      throw ArgumentError.value(imageSize, 'imageSize');
    }
    final region = (forSampling ? samplingRect ?? rect : rect).intersect(
      Offset.zero & imageSize,
    );
    if (region.isEmpty) throw StateError('Field is outside the image');
    return {
      'left': region.left / imageSize.width,
      'top': region.top / imageSize.height,
      'width': region.width / imageSize.width,
      'height': region.height / imageSize.height,
    };
  }

  /// Tạo rect tuyệt đối từ tọa độ tương đối và kích thước ảnh
  static Rect fromRelativeRect(Map<String, double> relative, Size imageSize) {
    return Rect.fromLTWH(
      relative['left']! * imageSize.width,
      relative['top']! * imageSize.height,
      relative['width']! * imageSize.width,
      relative['height']! * imageSize.height,
    );
  }

  /// Chuyển thành Map để lưu trữ/serialize với tọa độ tương đối
  Map<String, dynamic> toJson(Size imageSize) {
    return {
      'id': id,
      'rect': toRelativeRect(imageSize),
      'samplingRect': toRelativeRect(imageSize, forSampling: true),
      'label': label,
      'extractedText': extractedText,
      'isManual': isManual,
      'isStatic': isStatic,
    };
  }

  /// Tạo từ Map (deserialize) với tọa độ tương đối
  factory TemplateZone.fromJson(Map<String, dynamic> json, Size imageSize) {
    final rectMap = json['rect'] as Map<String, dynamic>;
    final relativeRect = {
      'left': (rectMap['left'] as num).toDouble(),
      'top': (rectMap['top'] as num).toDouble(),
      'width': (rectMap['width'] as num).toDouble(),
      'height': (rectMap['height'] as num).toDouble(),
    };
    return TemplateZone(
      id: json['id'] as String,
      rect: fromRelativeRect(relativeRect, imageSize),
      label: json['label'] as String,
      extractedText: json['extractedText'] as String,
      isManual: json['isManual'] as bool? ?? false,
      isStatic: json['isStatic'] as bool? ?? false,
      samplingRect: json['samplingRect'] == null
          ? null
          : fromRelativeRect(
              (json['samplingRect'] as Map<String, dynamic>).map(
                (key, value) => MapEntry(key, (value as num).toDouble()),
              ),
              imageSize,
            ),
    );
  }
}
