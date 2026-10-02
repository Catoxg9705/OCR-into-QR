import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../services/document_state.dart';
import '../services/pdf_export_service.dart';
import '../services/export_directory_service.dart';

/// Multi-page review screen where users can manually edit extracted field values
/// before exporting PDF with QR codes.
class BatchReviewScreen extends StatefulWidget {
  const BatchReviewScreen({required this.state, super.key});

  final DocumentState state;

  @override
  State<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends State<BatchReviewScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isExporting = false;
  String? _exportedFilePath; // Track exported file path

  @override
  void initState() {
    super.initState();
    // Initialize controllers for all fields across all pages
    final result = widget.state.batchResult;
    if (result != null) {
      for (final page in result.pages) {
        for (var i = 0; i < page.fields.length; i++) {
          final key = '${page.pageNumber}_$i';
          _controllers[key] = TextEditingController(text: page.fields[i].value);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    
    final result = widget.state.batchResult;
    final document = widget.state.document;
    
    if (result == null || document == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu để xuất')),
      );
      return;
    }

    // Generate default file name: original_name_OCR
    final originalFileName = document.name.replaceAll('.pdf', '');
    final defaultFileName = '${originalFileName}_OCR';

    // Step 1: Show directory selection dialog
    final exportDirService = ExportDirectoryService();
    final currentDir = await exportDirService.getExportDirectory();
    final customPath = await exportDirService.getSavedCustomPath();
    
    if (!mounted) return;
    
    final fileName = await showDialog<String?>(
      context: context,
      builder: (context) => _DirectorySelectionDialog(
        currentPath: customPath ?? currentDir.path,
        defaultFileName: defaultFileName,
        onSelectDirectory: () async {
          final selected = await exportDirService.selectCustomDirectory();
          return selected?.path;
        },
      ),
    );

    if (fileName == null || fileName.isEmpty) {
      return; // User cancelled
    }

    setState(() => _isExporting = true);

    try {
      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF1E222A),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _exportProgress,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final pdfService = PdfExportService();

      final outputPath = await pdfService.exportWithQrCodes(
        sourcePdfPath: document.filePath,
        result: result,
        outputFileName: fileName,
        onProgress: (current, total) {
          setState(() {
            _exportProgress = 'Đang dán mã QR: Trang $current/$total...';
          });
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss progress dialog

      if (outputPath != null) {
        setState(() {
          _exportedFilePath = outputPath; // Save the exported file path
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất PDF thành công!\n$outputPath'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Đóng',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xuất PDF thất bại')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _exportProgress = 'Đang xuất PDF...';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final result = widget.state.batchResult;
        if (result == null) {
          // If batch result was cleared, pop back
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dữ liệu đã quét'),
            leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: () async {
                // Clear document and batch result to return to initial state
                widget.state.clearDocument();
                widget.state.clearBatchResult();
                
                // Wait for state to update
                await Future.delayed(const Duration(milliseconds: 50));
                
                // Pop all routes until we reach the first route (Document Picker)
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: result.pages.length,
                  itemBuilder: (context, index) {
                    final page = result.pages[index];
                    return ExpansionTile(
                      title: Text('Trang ${page.pageNumber}'),
                      initiallyExpanded: index == 0,
                      children: [
                        for (var i = 0; i < page.fields.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _controllers['${page.pageNumber}_$i'],
                              decoration: InputDecoration(
                                labelText: page.fields[i].label,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (newValue) {
                                widget.state.updateBatchFieldValue(
                                  page.pageNumber,
                                  i,
                                  newValue,
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Show "Mở file" and "Quay lại màn hình chính" buttons after export
                      if (_exportedFilePath != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await OpenFile.open(_exportedFilePath!);
                                },
                                icon: const Icon(Icons.picture_as_pdf, size: 20),
                                label: const Text('Mở file'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  // Clear document and batch result to return to initial state
                                  widget.state.clearDocument();
                                  widget.state.clearBatchResult();
                                  
                                  // Wait for state to update
                                  await Future.delayed(const Duration(milliseconds: 50));
                                  
                                  // Pop all routes until we reach the first route (Document Picker)
                                  if (!context.mounted) return;
                                  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                                },
                                icon: const Icon(Icons.home, size: 20),
                                label: const Text('Màn hình chính'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Export button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting ? null : _exportPdf,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Xuất PDF'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog for selecting export directory before PDF export
class _DirectorySelectionDialog extends StatefulWidget {
  const _DirectorySelectionDialog({
    required this.currentPath,
    required this.onSelectDirectory,
    required this.defaultFileName,
  });

  final String currentPath;
  final Future<String?> Function() onSelectDirectory;
  final String defaultFileName;

  @override
  State<_DirectorySelectionDialog> createState() => _DirectorySelectionDialogState();
}

class _DirectorySelectionDialogState extends State<_DirectorySelectionDialog> {
  late String _selectedPath;
  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.currentPath;
    _fileNameController = TextEditingController(text: widget.defaultFileName);
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String get fileName => _fileNameController.text.trim();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E222A),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn thư mục xuất file',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F131C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPath,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final newPath = await widget.onSelectDirectory();
                  if (newPath != null && mounted) {
                    setState(() {
                      _selectedPath = newPath;
                    });
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Chọn thư mục khác'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tên file',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fileNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập tên file...',
                hintStyle: const TextStyle(color: Colors.white38),
                suffixText: '.pdf',
                suffixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F131C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (fileName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập tên file')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(fileName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
