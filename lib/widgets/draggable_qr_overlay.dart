import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Lives in the same coordinates as the page raster. No Provider calls on drag.
class DraggableQrOverlay extends StatefulWidget {
  const DraggableQrOverlay({
    super.key,
    required this.qrData,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onConfirm,
    this.canvasOrigin = Offset.zero,
    this.onCancel,
  });

  final String qrData;
  final double canvasWidth;
  final double canvasHeight;
  final Offset canvasOrigin;
  final void Function(double relativeX, double relativeY, double relativeSize)
  onConfirm;
  final VoidCallback? onCancel;

  @override
  State<DraggableQrOverlay> createState() => _DraggableQrOverlayState();
}

class _DraggableQrOverlayState extends State<DraggableQrOverlay> {
  Offset _position = Offset.zero;
  bool _positionReady = false;
  bool _confirmed = false;
  double _boxSize = 30.0;
  late Widget _qr;

  bool get _validCanvas =>
      widget.canvasWidth.isFinite &&
      widget.canvasHeight.isFinite &&
      widget.canvasWidth >= 16 &&
      widget.canvasHeight >= 16 &&
      widget.canvasOrigin.dx.isFinite &&
      widget.canvasOrigin.dy.isFinite;

  double get _size => _boxSize;
  double get _maxSize => math.min(160, math.min(widget.canvasWidth, widget.canvasHeight));
  double get _minSize => math.min(20, _maxSize);

  @override
  void initState() {
    super.initState();
    _prepareQr();
    _initializePosition();
  }

  void _prepareQr() {
    final payload = widget.qrData.trim().isEmpty ? 'EMPTY' : widget.qrData;
    // A cached child isolates QR matrix/paint work from local position updates.
    _qr = RepaintBoundary(
      child: ColoredBox(
        color: Colors.white,
        child: QrImageView(
          data: payload,
          version: QrVersions.auto,
          gapless: true,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          padding: const EdgeInsets.all(4),
          errorStateBuilder: (_, _) => const Center(
            child: Text('QR không hợp lệ',
                style: TextStyle(color: Colors.red, fontSize: 10)),
          ),
        ),
      ),
    );
  }

  void _initializePosition() {
    if (!_validCanvas) return;
    _boxSize = math.min(30.0, _maxSize);
    _position = Offset(
      math.max(0, (widget.canvasWidth - _size) / 2),
      math.max(0, (widget.canvasHeight - _size) / 2),
    );
    _positionReady = true;
  }

  Offset _clamp(Offset position) => Offset(
    position.dx.clamp(0.0, math.max(0.0, widget.canvasWidth - _size)),
    position.dy.clamp(0.0, math.max(0.0, widget.canvasHeight - _size)),
  );

  @override
  void didUpdateWidget(covariant DraggableQrOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qrData != widget.qrData) _prepareQr();
    if (!_validCanvas) {
      _positionReady = false;
      return;
    }
    if (!_positionReady) {
      _initializePosition();
    }
    if (oldWidget.canvasWidth != widget.canvasWidth ||
        oldWidget.canvasHeight != widget.canvasHeight) {
      final x = oldWidget.canvasWidth > 0 && oldWidget.canvasWidth.isFinite
          ? _position.dx / oldWidget.canvasWidth
          : 0.5;
      final y = oldWidget.canvasHeight > 0 && oldWidget.canvasHeight.isFinite
          ? _position.dy / oldWidget.canvasHeight
          : 0.5;
      _boxSize = _boxSize.clamp(_minSize, _maxSize);
      _position = _clamp(
        Offset(x * widget.canvasWidth, y * widget.canvasHeight),
      );
    }
  }

  void _resize(DragUpdateDetails details) {
    if (!_validCanvas || _confirmed) return;
    final box = context.findRenderObject()! as RenderBox;
    final delta =
        box.globalToLocal(details.globalPosition) -
        box.globalToLocal(details.globalPosition - details.delta);
    if (!delta.dx.isFinite || !delta.dy.isFinite) return;
    // Increase resize sensitivity by 2x
    final change = (delta.dx + delta.dy);
    final next = (_boxSize + change).clamp(_minSize, _maxSize);
    if (next != _boxSize) {
      setState(() {
        _boxSize = next;
        _position = _clamp(_position);
      });
    }
  }

  void _move(DragUpdateDetails details) {
    if (!_validCanvas || _confirmed) return;
    // Transform screen delta back to this scene (accounts for pre-existing zoom).
    final box = context.findRenderObject()! as RenderBox;
    final delta =
        box.globalToLocal(details.globalPosition) -
        box.globalToLocal(details.globalPosition - details.delta);
    if (!delta.dx.isFinite || !delta.dy.isFinite) return;
    // Increase sensitivity by multiplying delta by 1.5
    final next = _clamp(_position + delta * 1.5);
    if (next != _position) setState(() => _position = next);
  }

  void _confirm() {
    if (!_validCanvas || !_positionReady || _confirmed) return;
    setState(() => _confirmed = true);
    widget.onConfirm(
      _position.dx / widget.canvasWidth,
      _position.dy / widget.canvasHeight,
      _size / widget.canvasWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_validCanvas || !_positionReady) return const SizedBox.shrink();
    final position = widget.canvasOrigin + _position;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: position.dx,
          top: position.dy,
          width: _size,
          height: _size,
          child: GestureDetector(
            key: const ValueKey('qr-box'),
            onPanUpdate: _move,
            child: Stack(
              children: [
                _qr,
                // Bottom-right corner resize handle - positioned outside QR box
                Positioned(
                  right: -6, // Offset outside
                  bottom: -6, // Offset outside
                  child: GestureDetector(
                    key: const ValueKey('qr-resize-handle'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: _resize,
                    child: Container(
                      width: 16, // Smaller
                      height: 16, // Smaller
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black87, width: 2),
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: position.dx + _size + 8,
          top: position.dy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const ValueKey('qr-move'),
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _move,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.open_with,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                key: const ValueKey('qr-confirm'),
                onTap: _confirm,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  key: const ValueKey('qr-cancel'),
                  onTap: widget.onCancel,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
