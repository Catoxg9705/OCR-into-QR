import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/selected_document.dart';
import '../models/template_zone.dart';
import 'interactive_zone.dart';
import 'draggable_qr_overlay.dart';

/// One persistent raster canvas: no PDF viewer, no OCR/raw overlay duplication.
class DocumentPreviewWidget extends StatefulWidget {
  const DocumentPreviewWidget({
    super.key,
    required this.canvas,
    required this.zones,
    required this.activeZoneId,
    required this.onSelectZone,
    required this.onRectCommitted,
    required this.onDeleteZone,
    required this.onLabelTap,
    this.enabled = true,
    this.isQrPlacementMode = false,
    this.qrData = 'EMPTY',
    this.onQrConfirmed,
    this.onQrCancel,
  });

  final DocumentCanvas canvas;
  final List<TemplateZone> zones;
  final String? activeZoneId;
  final ValueChanged<String> onSelectZone;
  final void Function(String id, Rect rect) onRectCommitted;
  final ValueChanged<String> onDeleteZone;
  final void Function(String id, String label) onLabelTap;
  final bool enabled;
  final bool isQrPlacementMode;
  final String qrData;
  final void Function(double x, double y, double size)? onQrConfirmed;
  final VoidCallback? onQrCancel;

  @override
  State<DocumentPreviewWidget> createState() => _DocumentPreviewWidgetState();
}

class _DocumentPreviewWidgetState extends State<DocumentPreviewWidget> {
  final _transformation = TransformationController();
  late Widget _background;

  @override
  void initState() {
    super.initState();
    _prepareBackground();
  }

  void _prepareBackground() {
    final width = widget.canvas.imageSize.width;
    if (!width.isFinite || width <= 0) {
      _background = const SizedBox.shrink();
      return;
    }
    _background = RepaintBoundary(
      child: Image.file(
        File(widget.canvas.imagePath),
        cacheWidth: math.min(2048, widget.canvas.imageSize.width.round()),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, error, _) =>
            Center(child: Text('Không thể mở ảnh: $error')),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DocumentPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvas.imagePath != widget.canvas.imagePath) {
      _transformation.value = Matrix4.identity();
      _prepareBackground();
    }
    if (!oldWidget.isQrPlacementMode && widget.isQrPlacementMode) {
      // Return to a visible fitted page once, without resetting zoom on drag.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isQrPlacementMode) {
          _transformation.value = Matrix4.identity();
        }
      });
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = widget.canvas.imageSize;
          if (!constraints.maxWidth.isFinite ||
              !constraints.maxHeight.isFinite ||
              constraints.maxWidth <= 0 ||
              constraints.maxHeight <= 0 ||
              !size.width.isFinite ||
              !size.height.isFinite ||
              size.width <= 0 ||
              size.height <= 0) {
            return const SizedBox.shrink();
          }
          const gutter =
              48.0; // Room for toolbar and outer invisible hit margins.
          final availableWidth = math.max(
            1.0,
            constraints.maxWidth - gutter * 2,
          );
          final availableHeight = math.max(
            1.0,
            constraints.maxHeight - gutter * 2,
          );
          final scale = math.min(
            availableWidth / size.width,
            availableHeight / size.height,
          );
          final rasterSize = Size(size.width * scale, size.height * scale);
          final origin = Offset(
            (constraints.maxWidth - rasterSize.width) / 2,
            (constraints.maxHeight - rasterSize.height) / 2,
          );
          return InteractiveViewer(
            transformationController: _transformation,
            panEnabled: true,
            scaleEnabled: true,
            clipBehavior: Clip.hardEdge,
            minScale: 0.5,
            maxScale: 6,
            boundaryMargin: const EdgeInsets.all(120),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fromRect(
                    rect: origin & rasterSize,
                    child: _background,
                  ),
                  for (final zone
                      in widget.isQrPlacementMode
                          ? <TemplateZone>[]
                          : widget.zones)
                    InteractiveZone(
                      key: ValueKey(zone.id),
                      zoneId: zone.id,
                      initialRect: zone.rect,
                      imageSize: size,
                      origin: origin,
                      scale: scale,
                      label: zone.label,
                      isActive: widget.activeZoneId == zone.id,
                      isScanned: !zone.isManual,
                      enabled: widget.enabled,
                      onRectCommitted: (rect) =>
                          widget.onRectCommitted(zone.id, rect),
                      onTap: () => widget.onSelectZone(zone.id),
                      onLabelTap: () => widget.onLabelTap(zone.id, zone.label),
                      onDelete: () => widget.onDeleteZone(zone.id),
                    ),
                  if (widget.isQrPlacementMode && widget.onQrConfirmed != null)
                    DraggableQrOverlay(
                      qrData: widget.qrData,
                      canvasWidth: rasterSize.width,
                      canvasHeight: rasterSize.height,
                      canvasOrigin: origin,
                      onConfirm: widget.onQrConfirmed!,
                      onCancel: widget.onQrCancel,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
