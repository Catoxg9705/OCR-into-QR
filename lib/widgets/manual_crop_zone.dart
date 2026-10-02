import 'package:flutter/material.dart';

/// Widget khung crop thủ công với viền xanh cyan, kéo thả + resize mượt bằng setState cục bộ.
/// KHÔNG gọi notifyListeners() toàn cục khi đang kéo để đảm bảo 60fps.
class ManualCropZone extends StatefulWidget {
  const ManualCropZone({
    super.key,
    required this.initialRect,
    required this.scale,
    required this.onPositionChanged,
    required this.onSizeChanged,
    this.onScan,
    this.onDelete,
  });

  final Rect initialRect;
  final double scale;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<Size> onSizeChanged;
  final VoidCallback? onScan;
  final VoidCallback? onDelete;

  @override
  State<ManualCropZone> createState() => _ManualCropZoneState();
}

class _ManualCropZoneState extends State<ManualCropZone> {
  late Offset _localPosition;
  late Size _localSize;

  @override
  void initState() {
    super.initState();
    _localPosition = widget.initialRect.topLeft;
    _localSize = widget.initialRect.size;
  }

  @override
  void didUpdateWidget(covariant ManualCropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRect != widget.initialRect) {
      _localPosition = widget.initialRect.topLeft;
      _localSize = widget.initialRect.size;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      // Di chuyển theo delta, quy về tọa độ ảnh gốc
      final dx = details.delta.dx / widget.scale;
      final dy = details.delta.dy / widget.scale;
      _localPosition = Offset(_localPosition.dx + dx, _localPosition.dy + dy);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    // Khi thả tay ra, mới báo state toàn cục một lần
    widget.onPositionChanged(_localPosition);
  }

  void _handleResizeUpdate(DragUpdateDetails details) {
    setState(() {
      // Thay đổi kích thước theo delta, quy về tọa độ ảnh gốc
      final dx = details.delta.dx / widget.scale;
      final dy = details.delta.dy / widget.scale;
      _localSize = Size(
        (_localSize.width + dx).clamp(50.0, double.infinity),
        (_localSize.height + dy).clamp(30.0, double.infinity),
      );
    });
  }

  void _handleResizeEnd(DragEndDetails details) {
    // Báo kích thước mới về state toàn cục
    widget.onSizeChanged(_localSize);
  }

  @override
  Widget build(BuildContext context) {
    final scaledLeft = _localPosition.dx * widget.scale;
    final scaledTop = _localPosition.dy * widget.scale;
    final scaledWidth = _localSize.width * widget.scale;
    final scaledHeight = _localSize.height * widget.scale;

    return Positioned(
      left: scaledLeft,
      top: scaledTop,
      width: scaledWidth,
      height: scaledHeight,
      child: GestureDetector(
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF22D3EE), width: 2.5),
            color: const Color(0x1A22D3EE),
          ),
          child: Stack(
            children: [
              // Nút scan góc trên phải
              if (widget.onScan != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onScan,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22D3EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              // Nút xóa góc trên trái
              if (widget.onDelete != null)
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              // Tay nắm resize góc dưới phải
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onPanUpdate: _handleResizeUpdate,
                  onPanEnd: _handleResizeEnd,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22D3EE),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                      ),
                    ),
                    child: const Icon(
                      Icons.drag_handle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
