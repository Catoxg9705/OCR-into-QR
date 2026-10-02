import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Invisible border hit areas. Only this widget rebuilds while a finger moves.
class InteractiveZone extends StatefulWidget {
  const InteractiveZone({
    super.key,
    required this.zoneId,
    required this.initialRect,
    required this.imageSize,
    required this.origin,
    required this.scale,
    required this.label,
    required this.isActive,
    required this.isScanned,
    required this.onRectCommitted,
    required this.onTap,
    required this.onLabelTap,
    required this.onDelete,
    this.enabled = true,
  });

  final String zoneId;
  final Rect initialRect;
  final Size imageSize;
  final Offset origin;
  final double scale;
  final String label;
  final bool isActive;
  final bool isScanned;
  final bool enabled;
  final ValueChanged<Rect> onRectCommitted;
  final VoidCallback onTap;
  final VoidCallback onLabelTap;
  final VoidCallback onDelete;

  @override
  State<InteractiveZone> createState() => _InteractiveZoneState();
}

enum _Edge {
  move,
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _InteractiveZoneState extends State<InteractiveZone> {
  late Rect _rect;
  Rect? _startRect;
  Offset _startPoint = Offset.zero;
  _Edge _edge = _Edge.move;

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect;
  }

  @override
  void didUpdateWidget(covariant InteractiveZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_startRect == null && oldWidget.initialRect != widget.initialRect) {
      _rect = widget.initialRect;
    }
  }

  // Stable full-canvas coordinates account for InteractiveViewer zoom/pan.
  Offset _point(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    return (box.globalToLocal(global) - widget.origin) / widget.scale;
  }

  void _start(DragStartDetails details, _Edge edge) {
    _startPoint = _point(details.globalPosition);
    _startRect = _rect;
    _edge = edge;
  }

  void _update(DragUpdateDetails details) {
    final start = _startRect;
    if (start == null || !widget.enabled) return;
    final delta = _point(details.globalPosition) - _startPoint;
    final size = widget.imageSize;
    final minWidth = math.min(12 / widget.scale, size.width);
    final minHeight = math.min(12 / widget.scale, size.height);
    Rect next;
    if (_edge == _Edge.move) {
      next = Rect.fromLTWH(
        (start.left + delta.dx).clamp(0.0, size.width - start.width),
        (start.top + delta.dy).clamp(0.0, size.height - start.height),
        start.width,
        start.height,
      );
    } else {
      var left = start.left;
      var top = start.top;
      var right = start.right;
      var bottom = start.bottom;
      if ({_Edge.left, _Edge.topLeft, _Edge.bottomLeft}.contains(_edge)) {
        left = (start.left + delta.dx).clamp(
          0.0,
          math.max(0, right - minWidth),
        );
      }
      if ({_Edge.right, _Edge.topRight, _Edge.bottomRight}.contains(_edge)) {
        right = (start.right + delta.dx).clamp(
          math.min(size.width, left + minWidth),
          size.width,
        );
      }
      if ({_Edge.top, _Edge.topLeft, _Edge.topRight}.contains(_edge)) {
        top = (start.top + delta.dy).clamp(
          0.0,
          math.max(0, bottom - minHeight),
        );
      }
      if ({_Edge.bottom, _Edge.bottomLeft, _Edge.bottomRight}.contains(_edge)) {
        bottom = (start.bottom + delta.dy).clamp(
          math.min(size.height, top + minHeight),
          size.height,
        );
      }
      next = Rect.fromLTRB(left, top, right, bottom);
    }
    if (next != _rect) setState(() => _rect = next); // No Provider calls here.
  }

  void _end(DragEndDetails details) {
    final changed = _startRect != null && _startRect != _rect;
    _startRect = null;
    if (changed && widget.enabled) {
      widget.onRectCommitted(_rect); // Exactly once.
    }
  }

  void _cancel() {
    final start = _startRect;
    _startRect = null;
    if (start != null) setState(() => _rect = start);
  }

  Widget _hit(Rect area, _Edge edge) => Positioned.fromRect(
    rect: area,
    child: GestureDetector(
      key: ValueKey('${widget.zoneId}-resize-${edge.name}'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _start(details, edge),
      onPanUpdate: _update,
      onPanEnd: _end,
      onPanCancel: _cancel,
      child: const SizedBox.expand(), // Touch target only, no drawn handles.
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = Rect.fromLTWH(
      widget.origin.dx + _rect.left * widget.scale,
      widget.origin.dy + _rect.top * widget.scale,
      _rect.width * widget.scale,
      _rect.height * widget.scale,
    );
    final cyan = const Color(0xFF22D3EE);
    final color = widget.isScanned && !widget.isActive ? Colors.black : cyan;
    const margin = 12.0;
    final mx = math.min(margin, r.width / 2);
    final my = math.min(margin, r.height / 2);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: r,
          child: GestureDetector(
            key: ValueKey('${widget.zoneId}-box'),
            behavior: HitTestBehavior.translucent,
            onTap: widget.enabled ? widget.onTap : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
        ),
        if (widget.isActive && widget.enabled) ...[
          // All targets live inside a full-canvas Stack so outer 12px is hittable.
          _hit(
            Rect.fromLTRB(
              r.left + mx,
              r.top - margin,
              r.right - mx,
              r.top + margin,
            ),
            _Edge.top,
          ),
          _hit(
            Rect.fromLTRB(
              r.left + mx,
              r.bottom - margin,
              r.right - mx,
              r.bottom + margin,
            ),
            _Edge.bottom,
          ),
          _hit(
            Rect.fromLTRB(
              r.left - margin,
              r.top + my,
              r.left + margin,
              r.bottom - my,
            ),
            _Edge.left,
          ),
          _hit(
            Rect.fromLTRB(
              r.right - margin,
              r.top + my,
              r.right + margin,
              r.bottom - my,
            ),
            _Edge.right,
          ),
          _hit(
            Rect.fromCenter(center: r.topLeft, width: mx * 2, height: my * 2),
            _Edge.topLeft,
          ),
          _hit(
            Rect.fromCenter(center: r.topRight, width: mx * 2, height: my * 2),
            _Edge.topRight,
          ),
          _hit(
            Rect.fromCenter(
              center: r.bottomLeft,
              width: mx * 2,
              height: my * 2,
            ),
            _Edge.bottomLeft,
          ),
          _hit(
            Rect.fromCenter(
              center: r.bottomRight,
              width: mx * 2,
              height: my * 2,
            ),
            _Edge.bottomRight,
          ),
          Positioned(
            left: r.right + 8,
            top: r.top,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: ValueKey('${widget.zoneId}-move'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) => _start(details, _Edge.move),
                  onPanUpdate: _update,
                  onPanEnd: _end,
                  onPanCancel: _cancel,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.open_with,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  key: ValueKey('${widget.zoneId}-delete'),
                  onTap: widget.onDelete,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
