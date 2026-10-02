import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'debug_log_service.dart';

/// Render trang PDF trên một PdfDocument độc lập với PdfViewPinch.
class PdfToImageService {
  /// Chỉ trả về path sau khi render và ghi PNG đã hoàn tất.
  Future<String> renderPageToImage(String pdfPath, int pageNumber) async {
    PdfDocument? document;
    PdfPage? page;
    File? output;
    try {
      document = await PdfDocument.openFile(pdfPath);
      if (pageNumber < 1 || pageNumber > document.pagesCount) {
        throw RangeError.range(
          pageNumber,
          1,
          document.pagesCount,
          'pageNumber',
        );
      }
      // autoCloseAndroid=true khiến pdfx đánh dấu isClosed ngay khi tạo page;
      // render() sau đó ném PdfPageAlreadyClosedException.
      page = await document.getPage(pageNumber);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (image == null) {
        throw StateError('Không thể render trang PDF $pageNumber');
      }

      final directory = await getTemporaryDirectory();
      output = File(
        '${directory.path}/pdf_page_${pageNumber}_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await output.writeAsBytes(image.bytes, flush: true);
      final path = output.path;

      // Hoàn tất ghi file trước khi đóng native page/document.
      await page.close();
      page = null;
      await document.close();
      document = null;
      return path;
    } catch (error, stackTrace) {
      debugPrint(
        'PdfToImageService.renderPageToImage thất bại '
        '(file: $pdfPath, page: $pageNumber): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      DebugLogService.instance.logError(
        'Render PDF trang $pageNumber thất bại',
        error,
        stackTrace,
      );
      if (output != null) {
        try {
          if (await output.exists()) await output.delete();
        } catch (cleanupError) {
          debugPrint('Không thể xóa ảnh PDF ghi dở: $cleanupError');
        }
      }
      rethrow; // DocumentState hiển thị lỗi; không làm crash app.
    } finally {
      if (page != null && !page.isClosed) {
        try {
          await page.close();
        } catch (closeError) {
          debugPrint('Không thể đóng PDF page: $closeError');
        }
      }
      if (document != null && !document.isClosed) {
        try {
          await document.close();
        } catch (closeError) {
          debugPrint('Không thể đóng PDF document: $closeError');
        }
      }
    }
  }

  Future<void> cleanupTempImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      debugPrint('Không thể xóa ảnh PDF tạm $imagePath: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Lấy tổng số trang của file PDF
  Future<int> getPdfPageCount(String pdfPath) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(pdfPath);
      return document.pagesCount;
    } catch (error, stackTrace) {
      debugPrint('Không thể đọc số trang PDF $pdfPath: $error');
      debugPrintStack(stackTrace: stackTrace);
      DebugLogService.instance.logError(
        'Lỗi đọc số trang PDF',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      if (document != null && !document.isClosed) {
        try {
          await document.close();
        } catch (closeError) {
          debugPrint('Không thể đóng PDF document: $closeError');
        }
      }
    }
  }
}
