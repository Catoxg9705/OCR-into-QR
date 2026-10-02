import 'package:flutter/material.dart';

import '../models/template_zone.dart';

class ZoneEditorPanel extends StatelessWidget {
  const ZoneEditorPanel({
    super.key,
    required this.zones,
    required this.onClose,
    required this.onUpdateLabel,
    required this.onUpdateValue,
    required this.onDeleteZone,
    required this.onReorder,
    required this.onConfirmAndPlaceQR,
    required this.canPlaceQR,
    required this.onAddStaticField,
    this.enabled = true,
  });

  final List<TemplateZone> zones;
  final VoidCallback onClose;
  final void Function(String id, String label) onUpdateLabel;
  final void Function(String id, String value) onUpdateValue;
  final void Function(String id) onDeleteZone;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onConfirmAndPlaceQR;
  final bool canPlaceQR;
  final VoidCallback onAddStaticField;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Material(
        color: const Color(0xFF1E222E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Text('Trường dữ liệu'),

                          ),
                          IconButton(
                            tooltip: 'Thêm thông tin chung',
                            onPressed: enabled ? onAddStaticField : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            tooltip: 'Ẩn bảng dữ liệu',
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Reorderable field list
                  SliverReorderableList(
                    itemCount: zones.length,
                    onReorderStart: (index) {},
                    onReorderEnd: (index) {},
                    onReorderItem: (int oldIndex, int newIndex) {
                      onReorder(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(zone.id),
                        index: index,
                        child: _ZoneCard(
                          zone: zone,
                          enabled: enabled,
                          onLabelChanged: (label) => onUpdateLabel(zone.id, label),
                          onValueChanged: (value) => onUpdateValue(zone.id, value),
                          onDelete: () => onDeleteZone(zone.id),
                          index: index,
                          isStatic: zone.isStatic,
                        ),
                      );
                    },
                  ),
                  // Bottom action button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          if (!canPlaceQR)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Quét xác nhận tất cả trường trước khi đặt mã QR.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: canPlaceQR && enabled
                                  ? onConfirmAndPlaceQR
                                  : null,
                              icon: const Icon(Icons.qr_code_2),
                              label: const Text('Đặt mã QR'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneCard extends StatefulWidget {
  const _ZoneCard({
    required this.zone,
    required this.enabled,
    required this.onLabelChanged,
    required this.onValueChanged,
    required this.onDelete,
    required this.index,
    required this.isStatic,
  });

  final TemplateZone zone;
  final bool enabled;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onDelete;
  final int index;
  final bool isStatic;

  @override
  State<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends State<_ZoneCard> {
  late final TextEditingController _label;
  late final TextEditingController _value;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.zone.label);
    _value = TextEditingController(text: widget.zone.extractedText);
  }

  @override
  void didUpdateWidget(covariant _ZoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Do not reset cursor/composing text on every provider echo of onChanged.
    if (_label.text != widget.zone.label) {
      _label.value = TextEditingValue(
        text: widget.zone.label,
        selection: TextSelection.collapsed(offset: widget.zone.label.length),
      );
    }
    if (_value.text != widget.zone.extractedText) {
      _value.value = TextEditingValue(
        text: widget.zone.extractedText,
        selection: TextSelection.collapsed(
          offset: widget.zone.extractedText.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.isStatic ? const Color(0xFF2A3F5F) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (widget.isStatic)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.lightBlueAccent),
                    SizedBox(width: 4),
                    Text(
                      'Thông tin chung (áp dụng cho mọi trang)',
                      style: TextStyle(fontSize: 11, color: Colors.lightBlueAccent),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        key: ValueKey('${widget.zone.id}-label-input'),
                        controller: _label,
                        enabled: widget.enabled,
                        decoration: const InputDecoration(
                          labelText: 'Tên trường',
                          isDense: true,
                        ),
                        onChanged: widget.onLabelChanged,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: ValueKey('${widget.zone.id}-value-input'),
                        controller: _value,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Giá trị',
                          isDense: true,
                        ),
                        onChanged: widget.onValueChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: widget.enabled ? widget.onDelete : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(height: 4),
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.drag_handle,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
