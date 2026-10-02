import 'package:file_picker/file_picker.dart';

import '../models/selected_document.dart';

class DocumentPickerService {
  Future<SelectedDocument?> pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (file == null) return null;

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      throw const FormatException('Không thể lấy đường dẫn tệp.');
    }

    final extension = file.extension?.toLowerCase();
    if (!{'pdf', 'png', 'jpg', 'jpeg'}.contains(extension)) {
      throw const FormatException('Chỉ hỗ trợ PDF, PNG, JPG và JPEG.');
    }

    return SelectedDocument(
      name: file.name,
      format: extension == 'pdf' ? DocumentFormat.pdf : DocumentFormat.image,
      filePath: filePath,
    );
  }
}
