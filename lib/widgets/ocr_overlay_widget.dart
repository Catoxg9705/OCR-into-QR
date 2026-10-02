import 'package:flutter/material.dart';

import '../models/ocr_result.dart';

/// Widget vẽ bounding box đè lên ảnh/PDF preview
class OcrOverlayPainter extends CustomPainter {
  final OcrResult ocrResult;
  final Size imageSize;

  OcrOverlayPainter({required this.ocrResult, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Tính tỷ lệ scale giữa widget size và image size
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Vẽ bounding box cho từng block
    for (final block in ocrResult.blocks) {
      final scaledRect = Rect.fromLTRB(
        block.boundingBox.left * scaleX,
        block.boundingBox.top * scaleY,
        block.boundingBox.right * scaleX,
        block.boundingBox.bottom * scaleY,
      );
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(OcrOverlayPainter oldDelegate) {
    return oldDelegate.ocrResult != ocrResult ||
        oldDelegate.imageSize != imageSize;
  }
}

/// Widget kết hợp preview với overlay bounding box
class DocumentWithOcrOverlay extends StatelessWidget {
  final Widget preview;
  final OcrResult? ocrResult;
  final Size imageSize;

  const DocumentWithOcrOverlay({
    super.key,
    required this.preview,
    required this.ocrResult,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    if (ocrResult == null) {
      return preview;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        IgnorePointer(
          child: CustomPaint(
            painter: OcrOverlayPainter(
              ocrResult: ocrResult!,
              imageSize: imageSize,
            ),
          ),
        ),
      ],
    );
  }
}
