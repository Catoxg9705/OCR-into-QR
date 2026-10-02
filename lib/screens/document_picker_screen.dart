import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../models/batch_result.dart';
import '../services/debug_log_service.dart';
import '../services/document_state.dart';
import '../services/export_directory_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/document_preview_widget.dart';
import '../widgets/zone_editor_panel.dart';
import 'batch_review_screen.dart';
import 'debug_console_screen.dart';

class DocumentPickerScreen extends StatefulWidget {
  const DocumentPickerScreen({super.key});

  @override
  State<DocumentPickerScreen> createState() => _DocumentPickerScreenState();
}

class _DocumentPickerScreenState extends State<DocumentPickerScreen> {
  DocumentState? _state;
  String? _lastErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<DocumentState>();
      setState(
        () => _state = state,
      ); // First build never reads a late variable.
    });
  }

  Future<void> _editLabel(String id, String label) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditLabelDialog(initialLabel: label),
    );
    if (!mounted || result == null) return;
    // Dialog owns its controller until it actually unmounts after transition.
    _state?.updateZoneLabel(id, result);
  }

  Future<void> _applyBatch() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _state?.applyTemplateToAllPages();
    if (!mounted) return;
    final result = _state?.batchResult;
    if (result == null) return;

    // Navigate to batch review screen (DO NOT export PDF yet)
    if (!mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BatchReviewScreen(state: _state!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => _buildScreen(state),
    );
  }

  Widget _buildScreen(DocumentState state) {
    final page = state.canvas;
    
    // Auto-dismiss error message after 3 seconds
    if (state.errorMessage != null && state.errorMessage != _lastErrorMessage) {
      _lastErrorMessage = state.errorMessage;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && state.errorMessage == _lastErrorMessage) {
          state.clearError();
        }
      });
    } else if (state.errorMessage == null) {
      _lastErrorMessage = null;
    }
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Quét Doc'),
        actions: [
          if (state.zones.any((z) => !z.isManual))
            IconButton(
              tooltip: 'Xem dữ liệu',
              icon: const Icon(Icons.list_alt),
              onPressed: state.isBusy
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      state.setPanelVisible(!state.isPanelVisible);
                    },
            ),
          if (state.document != null)
            IconButton(
              tooltip: 'Đóng tài liệu',
              icon: const Icon(Icons.close),
              onPressed: state.isBusy ? null : state.clearDocument,
            ),
          IconButton(
            tooltip: 'Debug Console',
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DebugConsoleScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (page == null)
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: state.isBusy ? null : state.pickDocument,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Chọn tài liệu'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            DocumentPreviewWidget(
              key: ValueKey(page.imagePath),
              canvas: page,
              zones: state.zones,
              activeZoneId: state.activeZoneId,
              enabled: !state.isBusy,
              onSelectZone: (id) {
                FocusManager.instance.primaryFocus?.unfocus();
                state.selectZone(id, fromCanvas: true);
              },
              onRectCommitted: state.updateZoneRect,
              onDeleteZone: state.deleteZone,
              onLabelTap: _editLabel,
              isQrPlacementMode: state.isQrPlacementMode,
              qrData: state.qrPayload,
              onQrConfirmed: (x, y, size) {
                if (state.confirmQrPlacement(x, y, size)) _applyBatch();
              },
              onQrCancel: state.cancelQrPlacement,
            ),
            // No bottom-right FAB to obstruct the confirmation sheet.
            if (!state.isQrPlacementMode)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: state.isBusy ? null : state.pickDocument,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Đổi tệp'),
                      ),
                      ElevatedButton.icon(
                        onPressed: state.isBusy ? null : state.addZone,
                        icon: const Icon(Icons.add_box, size: 18),
                        label: const Text('Thêm trường'),
                      ),
                      ElevatedButton.icon(
                        onPressed: state.isBusy || state.zones.isEmpty
                            ? null
                            : () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                state.scanFields();
                              },
                        icon: const Icon(Icons.document_scanner, size: 18),
                        label: const Text('Quét chữ / Scan Fields'),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.isPanelVisible && !state.isQrPlacementMode)
              ZoneEditorPanel(
                zones: state.zones,
                enabled: !state.isBusy,
                onClose: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  state.setPanelVisible(false);
                },
                onUpdateLabel: state.updateZoneLabel,
                onUpdateValue: state.updateZoneValue,
                onDeleteZone: state.deleteZone,
                onReorder: state.reorderZones,
                onConfirmAndPlaceQR: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  state.enterQrPlacementMode();
                },
                canPlaceQR: state.canBatch,
                onAddStaticField: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  state.addStaticField();
                },
              ),
          ],
          if (state.errorMessage != null)
            Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: state.clearError,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.isBusy) ...[
            const ModalBarrier(dismissible: false, color: Colors.black38),
            Center(
              child: Material(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        state.isLoading
                            ? 'Đang quét trang...'
                            : state.isProcessingBatch
                            ? 'Đang xử lý ${state.processedPages}/${page?.pageCount ?? 0} trang...'
                            : 'Đang quét các vùng đã chọn...',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}

/// Controller follows the actual dialog subtree lifecycle, never a timer/pop.
class _EditLabelDialog extends StatefulWidget {
  const _EditLabelDialog({required this.initialLabel});
  final String initialLabel;

  @override
  State<_EditLabelDialog> createState() => _EditLabelDialogState();
}

class _EditLabelDialogState extends State<_EditLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi tên trường'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Tên trường'),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _ExportProgressDialog extends StatefulWidget {
  const _ExportProgressDialog({required this.state, required this.result});

  final DocumentState state;
  final BatchResult result;

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  String _status = 'Đang xuất PDF...';
  bool _completed = false;
  String? _outputPath;

  @override
  void initState() {
    super.initState();
    _exportPdf();
  }

  Future<void> _exportPdf() async {
    final result = widget.result;
    final sourcePath = widget.state.document!.filePath;
    final exporter = PdfExportService();

    // Show initial progress immediately
    setState(() => _status = 'Đang xuất PDF...');
    
    // Yield to allow the progress dialog to render before starting heavy work
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final outputPath = await exporter.exportWithQrCodes(
        sourcePdfPath: sourcePath,
        result: result,
        onProgress: (current, total) {
          if (!mounted) return;
          // Update status message to show QR stamping progress
          setState(() => _status = 'Đang dán mã QR: Trang $current/$total...');
        },
      );

      if (!mounted) return;

      if (outputPath != null) {
        setState(() {
          _status = 'Hoàn tất!';
          _completed = true;
          _outputPath = outputPath;
        });
      } else {
        setState(() {
          _status = 'Lỗi: Không thể xuất PDF';
          _completed = true;
        });
        
        // Show error snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể xuất PDF. Vui lòng thử lại.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (error, stack) {
      // Log error for debugging
      DebugLogService.instance.logError('PDF export failed', error, stack);
      
      if (!mounted) return;
      
      setState(() {
        _status = 'Lỗi: $error';
        _completed = true;
      });
      
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xuất PDF: ${error.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xuất PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_completed) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_status),
          if (_outputPath != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đường dẫn file:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _outputPath!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_completed && _outputPath != null) ...[
          TextButton.icon(
            onPressed: () async {
              final exportService = ExportDirectoryService();
              final messenger = ScaffoldMessenger.of(context);
              final customDir = await exportService.selectCustomDirectory();
              if (!mounted) return;
              if (customDir != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Thư mục mới: ${customDir.path}')),
                );
              }
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('Đổi thư mục'),
          ),
          TextButton.icon(
            onPressed: () async {
              if (_outputPath != null) {
                final file = File(_outputPath!);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                if (await file.exists()) {
                  if (!mounted) return;
                  try {
                    if (Platform.isAndroid || Platform.isIOS) {
                      // On mobile, use OpenFile package to open the PDF
                      final openResult = await OpenFile.open(_outputPath!);
                      if (openResult.type != ResultType.done) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Không thể mở file: ${openResult.message}')),
                        );
                      }
                    } else if (Platform.isWindows) {
                      await Process.run('explorer', ['/select,', _outputPath!]);
                    } else if (Platform.isMacOS) {
                      await Process.run('open', ['-R', _outputPath!]);
                    } else if (Platform.isLinux) {
                      await Process.run('xdg-open', [File(_outputPath!).parent.path]);
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Lỗi mở file: $e')),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Mở file'),
          ),
        ],
        if (_completed)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
      ],
    );
  }
}
