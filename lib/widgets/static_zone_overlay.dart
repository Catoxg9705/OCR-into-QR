import 'package:flutter/material.dart';

import '../models/template_zone.dart';

/// Overlay vẽ các khung chữ nhật tĩnh bao quanh các trường đã nhận diện.
/// Khung đang được chọn (active) sẽ có viền màu xanh dương, các khung khác viền đen mảnh.
class StaticZoneOverlay extends StatelessWidget {
  const StaticZoneOverlay({
    super.key,
    required this.zones,
    required this.scale,
    required this.onZoneTap,
    this.activeZoneId,
  });

  final List<TemplateZone> zones;
  final String? activeZoneId;
  final double scale;
  final ValueChanged<TemplateZone> onZoneTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: zones.map((zone) {
        final scaledRect = Rect.fromLTRB(
          zone.rect.left * scale,
          zone.rect.top * scale,
          zone.rect.right * scale,
          zone.rect.bottom * scale,
        );

        final isActive = zone.id == activeZoneId;

        return Positioned(
          left: scaledRect.left,
          top: scaledRect.top,
          width: scaledRect.width,
          height: scaledRect.height,
          child: GestureDetector(
            onTap: () => onZoneTap(zone),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? const Color(0xFF5B8CFF) : Colors.black,
                  width: isActive ? 2.0 : 1.5,
                ),
                color: Colors.transparent,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
