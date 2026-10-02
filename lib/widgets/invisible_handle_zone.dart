import 'package:flutter/material.dart';

/// Widget khung tương tác với handles tàng hình và thanh công cụ bên phải
class InvisibleHandleZone extends StatefulWidget {
  const InvisibleHandleZone({
    super.key,
    required this.zoneId,
    required this.initialRect,
    required this.scale,
    required this.label,
    required this.isActive,
    required this.isScanned,
    this.onPositionChanged,
    this.onSizeChanged,
    this.onLabelTap,
    this.onScan,
    this.onDelete,
    this.onTap,
  });

  final String zoneId;
  final Rect initialRect;
  final double scale;
  final String label;
  final bool isActive;
  final bool isScanned;
  final Function(Offset)? onPositionChanged;
  final Function(Size)? onSizeChanged;
  final VoidCallback? onLabelTap;
  final VoidCallback? onScan;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  State<InvisibleHandleZone> createState() => _InvisibleHandleZoneState();
}

class _InvisibleHandleZoneState extends State<InvisibleHandleZone> {
  late Rect _currentRect;
  static const double _handleMargin = 12.0; // Hit-test margin

  @override
  void initState() {
    super.initState();
    _currentRect = widget.initialRect;
  }

  @override
  void didUpdateWidget(InvisibleHandleZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRect != widget.initialRect) {
      _currentRect = widget.initialRect;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaledRect = Rect.fromLTWH(
      _currentRect.left * widget.scale,
      _currentRect.top * widget.scale,
      _currentRect.width * widget.scale,
      _currentRect.height * widget.scale,
    );

    return Positioned(
      left: scaledRect.left,
      top: scaledRect.top,
      width: scaledRect.width,
      height: scaledRect.height,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Khung chữ nhật
            Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: widget.isScanned
                      ? Colors.black
                      : (widget.isActive
                            ? const Color(0xFF5B8CFF)
                            : const Color(0xFF22D3EE)),
                  width: widget.isScanned ? 1.5 : 2.5,
                ),
              ),
            ),

            // Label ở góc trên trái
            Positioned(
              left: 0,
              top: -20,
              child: GestureDetector(
                onTap: widget.onLabelTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // Thanh công cụ bên phải (chỉ hiện khi active)
            if (widget.isActive) ...[
              Positioned(
                right: -36,
                top: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nút di chuyển
                    _ToolButton(
                      icon: Icons.open_with,
                      color: const Color(0xFF5B8CFF),
                      onPanUpdate: (details) {
                        final newLeft =
                            _currentRect.left + details.delta.dx / widget.scale;
                        final newTop =
                            _currentRect.top + details.delta.dy / widget.scale;
                        widget.onPositionChanged?.call(Offset(newLeft, newTop));
                      },
                    ),
                    const SizedBox(height: 4),

                    // Nút quét (chỉ hiện nếu chưa scan)
                    if (widget.onScan != null)
                      _ToolButton(
                        icon: Icons.qr_code_scanner,
                        color: const Color(0xFF22D3EE),
                        onTap: widget.onScan,
                      ),
                    if (widget.onScan != null) const SizedBox(height: 4),

                    // Nút xóa
                    _ToolButton(
                      icon: Icons.delete_outline,
                      color: Colors.redAccent,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],

            // Handles tàng hình ở 4 góc và 4 cạnh (chỉ active mới resize được)
            if (widget.isActive) ..._buildInvisibleHandles(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInvisibleHandles() {
    return [
      // Góc trên trái
      _buildCornerHandle(
        Alignment.topLeft,
        onPanUpdate: (details) {
          final newWidth = _currentRect.width - details.delta.dx / widget.scale;
          final newHeight =
              _currentRect.height - details.delta.dy / widget.scale;
          final newLeft = _currentRect.left + details.delta.dx / widget.scale;
          final newTop = _currentRect.top + details.delta.dy / widget.scale;

          if (newWidth > 20 && newHeight > 20) {
            widget.onPositionChanged?.call(Offset(newLeft, newTop));
            widget.onSizeChanged?.call(Size(newWidth, newHeight));
          }
        },
      ),

      // Góc trên phải
      _buildCornerHandle(
        Alignment.topRight,
        onPanUpdate: (details) {
          final newWidth = _currentRect.width + details.delta.dx / widget.scale;
          final newHeight =
              _currentRect.height - details.delta.dy / widget.scale;
          final newTop = _currentRect.top + details.delta.dy / widget.scale;

          if (newWidth > 20 && newHeight > 20) {
            widget.onPositionChanged?.call(Offset(_currentRect.left, newTop));
            widget.onSizeChanged?.call(Size(newWidth, newHeight));
          }
        },
      ),

      // Góc dưới trái
      _buildCornerHandle(
        Alignment.bottomLeft,
        onPanUpdate: (details) {
          final newWidth = _currentRect.width - details.delta.dx / widget.scale;
          final newHeight =
              _currentRect.height + details.delta.dy / widget.scale;
          final newLeft = _currentRect.left + details.delta.dx / widget.scale;

          if (newWidth > 20 && newHeight > 20) {
            widget.onPositionChanged?.call(Offset(newLeft, _currentRect.top));
            widget.onSizeChanged?.call(Size(newWidth, newHeight));
          }
        },
      ),

      // Góc dưới phải (tay nắm chính)
      _buildCornerHandle(
        Alignment.bottomRight,
        onPanUpdate: (details) {
          final newWidth = _currentRect.width + details.delta.dx / widget.scale;
          final newHeight =
              _currentRect.height + details.delta.dy / widget.scale;

          if (newWidth > 20 && newHeight > 20) {
            widget.onSizeChanged?.call(Size(newWidth, newHeight));
          }
        },
        showIcon: true, // Hiển thị icon drag_handle ở góc này
      ),

      // Cạnh trên
      _buildEdgeHandle(
        Alignment.topCenter,
        onPanUpdate: (details) {
          final newHeight =
              _currentRect.height - details.delta.dy / widget.scale;
          final newTop = _currentRect.top + details.delta.dy / widget.scale;

          if (newHeight > 20) {
            widget.onPositionChanged?.call(Offset(_currentRect.left, newTop));
            widget.onSizeChanged?.call(Size(_currentRect.width, newHeight));
          }
        },
      ),

      // Cạnh dưới
      _buildEdgeHandle(
        Alignment.bottomCenter,
        onPanUpdate: (details) {
          final newHeight =
              _currentRect.height + details.delta.dy / widget.scale;

          if (newHeight > 20) {
            widget.onSizeChanged?.call(Size(_currentRect.width, newHeight));
          }
        },
      ),

      // Cạnh trái
      _buildEdgeHandle(
        Alignment.centerLeft,
        onPanUpdate: (details) {
          final newWidth = _currentRect.width - details.delta.dx / widget.scale;
          final newLeft = _currentRect.left + details.delta.dx / widget.scale;

          if (newWidth > 20) {
            widget.onPositionChanged?.call(Offset(newLeft, _currentRect.top));
            widget.onSizeChanged?.call(Size(newWidth, _currentRect.height));
          }
        },
      ),

      // Cạnh phải
      _buildEdgeHandle(
        Alignment.centerRight,
        onPanUpdate: (details) {
          final newWidth = _currentRect.width + details.delta.dx / widget.scale;

          if (newWidth > 20) {
            widget.onSizeChanged?.call(Size(newWidth, _currentRect.height));
          }
        },
      ),
    ];
  }

  Widget _buildCornerHandle(
    Alignment alignment, {
    required Function(DragUpdateDetails) onPanUpdate,
    bool showIcon = false,
  }) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: Container(
          width: _handleMargin * 2,
          height: _handleMargin * 2,
          color: Colors.transparent,
          child: showIcon
              ? const Center(
                  child: Icon(
                    Icons.drag_handle,
                    size: 16,
                    color: Color(0xFF22D3EE),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildEdgeHandle(
    Alignment alignment, {
    required Function(DragUpdateDetails) onPanUpdate,
  }) {
    final isHorizontal =
        alignment == Alignment.centerLeft || alignment == Alignment.centerRight;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: Container(
          width: isHorizontal ? _handleMargin * 2 : double.infinity,
          height: isHorizontal ? double.infinity : _handleMargin * 2,
          color: Colors.transparent,
        ),
      ),
    );
  }
}

/// Nút công cụ nhỏ trên thanh bên phải
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.onPanUpdate,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Function(DragUpdateDetails)? onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
