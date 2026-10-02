# OCR Document Processing - Development Log

## Current Status
**Phase:** Persistent Logging & Gesture-Safe QR Placement ✅ (2026-09-29 14:36 UTC)

Ứng dụng đã triển khai đầy đủ luồng OCR, chỉnh sửa vùng, export PDF/TXT và đặt mã QR. Bản hotfix này khắc phục hai vấn đề quan trọng:

1. **Persistent Crash History:**
   - `DebugLogService` lưu log vào `crash_history.log` đồng bộ (`writeAsStringSync`), tức thì khi ghi error.
   - Ứng dụng khôi phục log từ file trước frame đầu tiên (`main.dart` gọi `logger.initialize()` trước `runApp`).
   - Crash history không mất sau khi khởi động lại hoặc force-stop; giới hạn 100 entry gần nhất.
   - Debug Console hiển thị "View Last Crash" với nội dung đã lưu.

2. **QR Placement Fixes:**
   - QR được render bên trong `InteractiveViewer` canvas (`DocumentPreviewWidget`), dùng tọa độ tài liệu thay vì màn hình.
   - Trong chế độ đặt QR: `panEnabled: false` và `scaleEnabled: false` để tránh xung đột cử chỉ kéo/zoom.
   - Vị trí QR được lưu trong local state (`DraggableQrOverlay._qrPosition`); chỉ ghi vào global state khi nhấn Confirm.
   - Canvas không hợp lệ (0, NaN, Infinity hoặc quá nhỏ <40pt) không render QR và không crash.
   - Payload trống hiển thị `"EMPTY"` an toàn thay vì để null gây lỗi assertion `QrImageView`.

**Verification:** 
- `flutter analyze`: 0 issues
- Tests: 13/13 pass (`widget_test.dart` + `qr_logging_test.dart`)
- Build: APK debug thành công (142s, Kotlin daemon warning không ảnh hưởng kết quả)

**Files Changed:**
- `lib/main.dart`: Đăng ký error handlers trước `initialize()`, khôi phục log trước `runApp`.
- `lib/services/debug_log_service.dart`: Ghi file đồng bộ (`writeAsStringSync`), load log cũ vào `_entries` khi khởi tạo.
- `lib/screens/debug_console_screen.dart`: Hiển thị "View Last Crash" với entry gần nhất nếu có.
- `lib/widgets/draggable_qr_overlay.dart`: Tính toán vị trí an toàn, local drag state, validation trước khi commit.
- `lib/widgets/document_preview_widget.dart`: Đặt QR overlay bên trong canvas, tắt pan/scale khi `isQrPlacementMode`.
- `lib/screens/document_picker_screen.dart`: Kết nối `DraggableQrOverlay` với canvas thực tế.
- `lib/services/document_state.dart`: Thêm `confirmQrPlacement` validation, reset `_batchResult` khi vào chế độ QR.
- `test/qr_logging_test.dart`: 5 test cases mới kiểm tra khôi phục log, QR drag, canvas invalid.
- `test/widget_test.dart`: Thêm test `confirmQrPlacement` validation.


## Project Tree Changes (Hotfix)
```text
lib/services/
└── debug_log_service.dart         # Ghi file đồng bộ, khôi phục log từ crash_history.log
lib/screens/
├── debug_console_screen.dart      # Hiển thị "View Last Crash" với entry gần nhất
└── document_picker_screen.dart    # Canvas/QR placement/export; kết nối DraggableQrOverlay
lib/widgets/
├── draggable_qr_overlay.dart      # QR local drag state, validation, commit on confirm
└── document_preview_widget.dart   # Render QR bên trong canvas, tắt pan/scale khi placement
```

```text
test/
├── qr_logging_test.dart           # 5 test cases: khôi phục log, QR drag, invalid canvas
└── widget_test.dart               # Thêm test confirmQrPlacement validation
```


## Architecture Overview

### Template-First Workflow (Current Implementation)
1. **Render Page 1 Only**: Mở PDF/ảnh → render trang 1 thành PNG cache, không chạy OCR tự động
2. **Manual Zone Design**: User thêm/chỉnh khung trường với invisible handles, toolbar tròn đen, không có label trên canvas
3. **Scan Confirmation**: Tap "Quét chữ" → OCR từng crop → smart trim punctuation → shrink-wrap bounding box, preserve sampling rect
4. **Reorder & Edit**: Drag fields to reorder QR payload sequence, edit values in bottom sheet
5. **Interactive QR Placement**: Tap "Xác nhận & Đặt mã QR" → sheet collapses, draggable QR widget appears with confirm button
6. **Batch Export**: Lock QR position → batch process all pages with smart baseline expansion → stamp QR at relative coordinates → export PDF with `_with_QR.pdf` suffix

### Key Components

#### Services Layer
- **DocumentState** (Provider): Trạng thái tài liệu, vùng mẫu, tiến độ batch và lifecycle toàn cục
- **OcrCoordinatorService**: Chuẩn bị canvas (render PDF/normalize ảnh), quản lý ảnh tạm
- **OcrService**: Crop ảnh off-thread (`compute`), nhận dạng ML Kit Latin, smart prefix trimming (strip leading `:`, `-`, whitespace), bounding box snap to first alphanumeric, smart baseline expansion for full-name capture, ánh xạ về tọa độ gốc
- **PdfToImageService**: Render trang PDF, đếm số trang, dọn ảnh tạm
- **DocumentPickerService**: Chọn và kiểm tra định dạng PDF/ảnh
- **BatchExportService**: Batch processing với progress callback, QR generation, PDF stamping, file export

#### UI Layer
- **DocumentPreviewWidget**: Canvas InteractiveViewer với zoom/pan, persistent raster, không duplicate overlay, supports QR placement overlay
- **InteractiveZone**: Local-state gesture (move/resize 8 handles ẩn + toolbar tròn đen 28×28px), atomic commit `onPanEnd`, không có floating label
- **ZoneEditorPanel**: DraggableScrollableSheet persistent (minChildSize: 0.12); reorderable field list với drag handles, "Xác nhận & Đặt mã QR" button
- **DocumentPickerScreen**: Orchestrate canvas/panel/batch, keyboard-aware, dialog lifecycle an toàn, QR placement mode coordination
- **QrPlacementOverlay**: Interactive draggable QR widget with move handle and confirm button (circular black buttons)

#### Models
- **TemplateZone**: Vùng mẫu với `rect` (bounding box shrink-wrapped), `samplingRect` (vùng crop ban đầu), nhãn/giá trị và cờ manual
- **DocumentCanvas**: Canvas metadata (đường dẫn, kích thước, số trang, cờ sở hữu)
- **BatchResult**: Kết quả batch theo trang/trường với xuất JSON, includes QR relative coordinates
- **OcrResult**: Kết quả OCR cấu trúc block/line/element từ ML Kit

### Critical Design Decisions

1. **No Auto-OCR on Open**: Chỉ render canvas trang 1, không quét tự động → tránh lag khi mở tài liệu lớn
2. **Atomic Gesture Commits**: `InteractiveZone` setState local suốt gesture, chỉ gọi callback một lần `onPanEnd` → 0 notifyListeners trong lúc kéo
3. **Shrink-Wrap + Sampling Rect**: Sau OCR, `rect` thu về bounding box thật, `samplingRect` giữ vùng crop gốc để batch dùng lại
4. **Batch Preserves Page 1**: Batch không quét lại trang 1, giữ giá trị đã sửa tay; chỉ render+crop trang 2..N
5. **Scrollable Sheet Everything**: Header/actions cũng nằm trong ListView để không overflow khi bàn phím lên
6. **Clean Canvas**: Không có floating label; zone chỉ hiển thị border và toolbar khi active
7. **Smart OCR Trimming**: Tự động loại bỏ dấu hai chấm/gạch đầu dòng, snap bounding box về ký tự đầu tiên có nghĩa
8. **Deferred Text-to-Box Alignment**: TextField editing chỉ cập nhật string, không tính toán layout. Shrinking xảy ra khi user nhấn "Quét chữ" → loại bỏ lag khi gõ
9. **Smart Baseline Expansion**: OCR không clip text theo chiều rộng zone cứng nhắc. Tìm TextLine bắt đầu trong zone, rồi lấy toàn bộ TextElement cùng baseline (Y-axis) để capture tên dài/ngắn đầy đủ
10. **Reorderable Payload**: User drag field để sắp xếp thứ tự trong chuỗi QR (newline-separated format)
11. **Interactive QR Placement**: Sheet thu gọn, QR draggable trên canvas, confirm lock vị trí trước khi batch export
12. **Relative Coordinates**: QR position lưu tỷ lệ `(x/width, y/height)` để áp dụng đồng nhất cho mọi kích thước trang

### Known Limitations & Verification Status

#### Verified (Tests/Build)
- ✅ Provider boots, no late/context errors
- ✅ Render-only open, atomic gesture, shrink-wrap, batch from page 2
- ✅ Dispose during OCR defers cleanup
- ✅ Invisible handles publish once on release
- ✅ Collapsed sheet scrollable with keyboard
- ✅ R8 build passes with ProGuard rules (81.4MB APK)
- ✅ Analyzer clean (0 issues), 13/13 tests pass
- ✅ UI refinements: persistent sheet, no canvas labels, circular toolbar, delete in cards, prefix trimming
- ✅ Reorderable field list with drag handles
- ✅ Smart baseline expansion logic implemented
- ✅ Interactive QR placement overlay with local drag state
- ✅ Batch export service with progress tracking
- ✅ **Persistent crash history**: Logs survive app restart, restored before first frame
- ✅ **QR gesture isolation**: Canvas pan/scale disabled during placement, no drag conflicts
- ✅ **QR position validation**: NaN/Infinity/invalid canvas handled safely, no crashes

#### Unverified (Requires Device/Manual Testing)
- ⚠️ **60fps claim from old logs**: Chưa profile trên thiết bị thật
- ⚠️ **Large PDF (50+ pages)**: Chưa test batch memory/timeout thực tế
- ⚠️ **ML Kit accuracy**: Phụ thuộc chất lượng ảnh, font, góc nghiêng
- ⚠️ **Smart prefix trimming effectiveness**: Chưa test với nhiều pattern dấu câu khác nhau
- ⚠️ **Dialog lifecycle across route push/pop**: Smoke test có controller dispose, chưa verify race với Navigator transition
- ⚠️ **Sheet gesture conflict**: InteractiveViewer + DraggableScrollableSheet chưa test gesture priority trên device
- ⚠️ **Temp file cleanup on crash**: `finally` clause đảm bảo, nhưng chưa test force-kill/OOM
- ⚠️ **Reorder gesture**: Drag handle interaction with sheet scrolling chưa test trên device
- ⚠️ **Smart baseline expansion accuracy**: Chưa test với tên nhiều từ, dấu thanh, các layout phức tạp
- ⚠️ **QR placement UX on device**: Draggable smoothness, confirm flow, sheet collapse chưa verify trên thiết bị thật
- ⚠️ **Batch PDF stamping quality**: QR resolution, positioning accuracy, file size impact chưa đo
- ⚠️ **QR generation from real data**: Payload format (newline-separated), encoding, readability chưa test với QR scanner thật
- ⚠️ **Crash log persistence after native kill**: OS force-stop có thể không ghi được log cuối cùng
- ⚠️ **WYSIWYG QR scaling accuracy**: Proportional sizing logic chưa verify trên thiết bị với PDFs có kích thước trang khác nhau
- ⚠️ **Android media scan reliability**: `am broadcast` có thể không hoạt động trên một số ROM tùy chỉnh hoặc Android 11+
- ⚠️ **Newline QR payload readability**: Format mới có thể gây vấn đề với QR scanner cũ hoặc limits của QR version

### Android Configuration
- **minSdkVersion**: 21 (Android 5.0)
- **targetSdkVersion**: 35 (Android 15)
- **ProGuard Rules** (`android/app/proguard-rules.pro`): 8 `-dontwarn` rules cho ML Kit Chinese/Devanagari/Japanese/Korean script options (chỉ dùng Latin)

## Project Structure

```text
lib/
├── main.dart                           # Provider root, theme, error handlers
├── models/
│   ├── batch_result.dart               # Batch result theo trang/trường, xuất JSON, QR coordinates
│   ├── ocr_result.dart                 # OCR result từ ML Kit (block/line/element)
│   ├── selected_document.dart          # Document metadata và canvas
│   └── template_zone.dart              # Zone với rect/samplingRect/label/value
├── screens/
│   ├── debug_console_screen.dart       # Xem/sao chép/xóa debug log
│   └── document_picker_screen.dart     # Main screen: canvas/panel/batch orchestration, QR mode
├── services/
│   ├── batch_export_service.dart       # Batch processing, QR generation, PDF stamping, progress
│   ├── debug_log_service.dart          # Bộ đệm log giới hạn 100 entry
│   ├── document_picker_service.dart    # Chọn PDF/ảnh
│   ├── document_state.dart             # Provider state: zones/canvas/batch/lifecycle
│   ├── ocr_coordinator_service.dart    # Canvas prep, normalize, temp cleanup
│   ├── ocr_service.dart                # Crop compute, ML Kit Latin, smart prefix trim, baseline expansion
│   └── pdf_to_image_service.dart       # PDF render/count/cleanup
└── widgets/
    ├── document_preview_widget.dart    # InteractiveViewer canvas, QR placement overlay support
    ├── interactive_zone.dart           # Local-state gesture, 8 invisible handles, circular toolbar, atomic commit
    ├── qr_placement_overlay.dart       # Draggable QR widget with move handle and confirm button
    ├── zone_editor_panel.dart          # Persistent scrollable sheet: reorderable list, "Xác nhận & Đặt mã QR"
    ├── invisible_handle_zone.dart      # [UNUSED] Old widget, có thể xóa
    ├── manual_crop_zone.dart           # [UNUSED] Old widget, có thể xóa
    ├── ocr_overlay_widget.dart         # [UNUSED] Old widget, có thể xóa
    └── static_zone_overlay.dart        # [UNUSED] Old widget, có thể xóa

test/
├── ocr_heuristic_test.dart             # Test legacy key-value heuristic (giữ cho tương lai)
├── qr_logging_test.dart                # 5 tests: crash persistence, QR drag/canvas validation
└── widget_test.dart                    # 8 regression tests: Provider/gesture/batch/lifecycle/QR

android/app/proguard-rules.pro          # R8 rules cho ML Kit optional scripts
```

**Note**: Bốn widget `invisible_handle_zone`, `manual_crop_zone`, `ocr_overlay_widget`, `static_zone_overlay` không còn được import trong source hiện tại nhưng vẫn tồn tại trong `lib/widgets/`. Có thể xóa sau khi xác nhận không còn reference nào.

## Dependencies

### Core
- **flutter**: SDK 3.47.5 (Dart 3.13.4)
- **provider**: ^6.1.2 (state management)
- **uuid**: ^4.5.1 (zone/crop ID generation)

### ML & Image Processing
- **google_mlkit_text_recognition**: ^0.13.0 (Latin OCR)
- **image**: ^4.3.0 (crop/normalize off-thread)
- **pdfx**: ^2.11.0 (PDF render/count)
- **qr_flutter**: ^4.1.0 (QR code generation)
- **pdf**: ^3.11.1 (PDF export with QR stamping)

### System Integration
- **path_provider**: ^2.1.6 (temp directory, crash log persistence)
- **file_picker**: ^13.1.0 (document picker)

## Testing Strategy

### Current Coverage
1. **Provider Lifecycle**: Boot/dispose, no late var access
2. **Workflow**: Render-only → manual zone → scan → shrink-wrap → batch
3. **Gesture**: Atomic commit, no notifyListeners during drag
4. **Dispose Safety**: Stale OCR result ignored, cleanup deferred
5. **UI Regression**: Sheet scroll with keyboard, dialog controller lifecycle
6. **QR Placement**: Local drag state, confirm validation, canvas isolation
7. **Crash Persistence**: Log durability across restarts, restore before first frame
8. **Invalid Geometry**: NaN/Infinity/zero canvas handled without crashes

### Missing Coverage (Manual Required)
- Large PDF batch (memory/timeout)
- Device gesture conflicts (InteractiveViewer + sheet)
- ML Kit accuracy across fonts/angles
- Smart prefix trimming with diverse punctuation patterns
- Performance profiling (60fps claim)
- Crash recovery (temp cleanup)
- QR drag smoothness on real device
- QR readability with actual scanners

## Build & Deployment

### Debug
```bash
flutter run
```

### Release APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Verification
```bash
flutter analyze        # 0 issues
flutter test          # 13/13 pass
```

## Next Steps

### Recommended (Device Verification)
1. **Deploy to Android Device**: Test full workflow on real device via ADB/scrcpy
2. **QR Drag Interaction**: Verify smoothness, gesture isolation, confirm button usability
3. **Baseline Expansion Accuracy**: Test with real certificates containing multi-word names with Vietnamese diacritics
4. **Batch Export Quality**: Verify QR resolution, positioning accuracy, file size on multi-page PDFs
5. **QR Readability**: Test generated QR codes with real scanners, validate payload format
6. **Crash Log Review**: Force-kill app during batch export, verify crash_history.log persistence

### Optional Enhancements
1. **Template Persistence**: Save confirmed Page 1 templates to disk for reuse across sessions
2. **Cleanup Unused Widgets**: Remove 4 unused widget files after confirming no external references
3. **Performance Profiling**: Measure frame rates during OCR, batch processing, QR drag
4. **Large PDF Stress Test**: Test 50+ page documents for memory/timeout handling

## Changelog

### 2026-10-01 10:26 UTC (Comprehensive Workflow & UX Refinements)
- ✅ **QR Payload Format**: Changed from JSON to newline-separated plaintext (`Label: Value\n`) for human-readable scanning
- ✅ **WYSIWYG QR Scaling**: QR size now stored as relative ratio (`qrRelativeSize = size/width`) and applied proportionally to PDF page dimensions for consistent visual appearance
- ✅ **PDF Y-Axis Correction**: Compensated for PDF coordinate system (bottom-left origin) vs Flutter (top-left) in stamping logic
- ✅ **Review Screen First**: Batch results now show in dedicated "Dữ liệu đã quét" screen with AppBar title, back button, and bottom action button
- ✅ **Export CTA Button**: Added prominent "Chọn nơi lưu & Xuất PDF" button at bottom of review screen to initiate export
- ✅ **Export Dialog Contrast**: Fixed unreadable white-on-white text; path container now uses dark surface `#1E222A` with white text (13px, height 1.4)
- ✅ **Android Media Indexing**: Added `_triggerMediaScan()` using `am broadcast` to make exported PDFs immediately visible in Files app without device restart
- ✅ **Reorder Touch Target**: Enlarged drag handle to 48×48px with `ReorderableDragStartListener` wrapper; removed tooltip from delete button
- ✅ **Verification**: `flutter analyze` shows 3 info-level warnings only (`use_build_context_synchronously`), no errors
- 📝 **Files Changed**: 
  - `lib/services/pdf_export_service.dart`: Newline payload format, media scan trigger, WYSIWYG coordinate scaling
  - `lib/screens/document_picker_screen.dart`: Review screen redesign with AppBar + bottom CTA, export dialog contrast fix
  - `lib/widgets/zone_editor_panel.dart`: 48×48px drag handle with proper listener, tooltip removal

### 2026-10-01 10:02 UTC (Runtime Fixes: Android Export Path, Transparent QR, Corner Resize Handle)
- ✅ **Android Public Download Directory**: `ExportDirectoryService` now defaults to `/storage/emulated/0/Download` on Android instead of sandboxed app-internal storage
- ✅ **Directory Picker Fixed**: Removed obsolete `FilePicker.platform` API; now uses `FilePicker.getDirectoryPath()` directly (compatible with `file_picker` 13.1.0)
- ✅ **Enhanced Export Dialog**: Added "Change Directory" and "Open File" buttons in completion dialog; displays full accessible path with copyable TextField
- ✅ **Transparent QR Background**: QR codes now render with fully transparent background in both interactive preview and PDF stamping
- ✅ **Modern QR API**: Migrated from deprecated `color`/`emptyColor` to `eyeStyle`/`dataModuleStyle` with explicit black modules
- ✅ **Corner Resize Handle**: Replaced toolbar resize button with intuitive bottom-right corner drag handle (24px circle with zoom icon)
- ✅ **Toolbar Cleanup**: Removed "Thay đổi kích thước" button and tooltip; toolbar now shows only Move, Confirm, Cancel
- ✅ **Verification**: `flutter analyze` reduced from 5 issues to 3 (only `use_build_context_synchronously` info warnings remain)
- 📝 **Files Changed**: `export_directory_service.dart` (Android path + FilePicker API), `pdf_export_service.dart` (transparent QR with new API), `draggable_qr_overlay.dart` (corner handle UI), `document_picker_screen.dart` (enhanced export dialog)

### 2026-09-29 14:36 UTC (Hotfix: Persistent Logging & QR Gesture Safety)
- ✅ **Crash Persistence**: `DebugLogService` now writes to `crash_history.log` synchronously (`writeAsStringSync`) for immediate durability
- ✅ **Log Restoration**: `initialize()` loads existing log entries from file before first frame; called in `main.dart` before `runApp`
- ✅ **Error Handlers**: `FlutterError.onError` and `PlatformDispatcher.instance.onError` append full exception and stack trace to file
- ✅ **Debug Console**: Added "View Last Crash" section displaying most recent saved error
- ✅ **QR Canvas Safety**: `DraggableQrOverlay` validates canvas dimensions (NaN/Infinity/zero/negative), clamps initial position to visible bounds
- ✅ **Gesture Isolation**: `DocumentPreviewWidget` sets `panEnabled: false`, `scaleEnabled: false` during QR placement mode to prevent drag conflicts
- ✅ **Local Drag State**: QR position updates in widget-local `_qrPosition`, only commits to global state on Confirm button press
- ✅ **Safe Payload**: Empty `confirmedZones` list renders `"EMPTY"` instead of null to prevent QrImageView assertion crashes
- ✅ **Test Coverage**: Added 5 new tests in `qr_logging_test.dart` (log persistence, QR drag, invalid canvas); updated `widget_test.dart` with QR confirmation validation
- ✅ **Verification**: `flutter analyze` 0 issues, 13/13 tests pass, debug APK builds successfully (142s)
- 📝 **Limitation**: OS force-stop or native crash may not flush final error to disk

### 2026-09-29 09:39 UTC (Phase 4: Reordering, Smart Baseline, QR Placement, Batch Export)
- ✅ **Removed**: "Áp dụng cho toàn bộ các trang" button from `zone_editor_panel.dart`
- ✅ **Added**: `ReorderableListView` for dynamic field ordering with drag handles (`Icons.drag_handle`)
- ✅ **Added**: "Xác nhận & Đặt mã QR" primary action button at bottom of sheet
- ✅ **Smart OCR Enhancement**: `OcrService.scanZones()` now expands TextLine extraction by baseline matching instead of rigid zone clipping to capture full names
- ✅ **New Widget**: `QrPlacementOverlay` with draggable QR widget, move handle (`Icons.open_with`), and confirm button (`Icons.check_circle`)
- ✅ **New Service**: `BatchExportService` with progress callback, QR generation stub, PDF stamping stub, and `_with_QR.pdf` export
- ✅ **New Model**: `BatchResult` with optional `qrRelativeX`, `qrRelativeY`, `qrRelativeSize` fields
- ✅ **QR Mode State**: Added `_isQrPlacementMode`, `_qrPosition`, `_qrSize` to `DocumentPickerScreen`
- ✅ **Payload Format**: Strict newline-separated format (`Label: Value\n`)
- ✅ Analyzer: 3 info-level suggestions (null-aware markers preference), no errors
- 📝 **Next**: Wire `qr_flutter` generation, implement PDF stamping with `pdf` package, test on device

### 2026-09-29 09:01 UTC (Deferred Text-to-Box Alignment)
- ✅ Refactored shrink logic: editing "Giá trị" TextField now only updates text string in `DocumentState.updateZoneValue()`, no rect calculations
- ✅ Added `editedTexts` optional parameter to `OcrService.scanZones()` and `OcrCoordinatorService.scanZones()`
- ✅ Shrink-to-fit logic now triggers only when user presses "Quét chữ": matches edited text against cached ML Kit elements, adjusts zone boundaries
- ✅ Batch apply uses tightened `samplingRect` coordinates from Page 1
- ✅ Updated `_MockOcr.scanZones()` signature in test to match new interface
- ✅ Analyzer clean (0 issues), tests 7/7 pass
- 📝 **Performance verification pending**: typing lag elimination requires device testing

### 2026-09-29 08:45 UTC (UI/UX Refinements)
- ✅ Persistent bottom sheet: `minChildSize: 0.12`, always visible even with 0 fields
- ✅ Clean canvas: removed floating field labels (line 299-317 deleted from `interactive_zone.dart`)
- ✅ Dark circular toolbar buttons: 28×28px black87 background for move/delete icons
- ✅ Delete buttons in sheet cards: red icon at top-right of each field card
- ✅ Smart prefix trimming: regex-based removal of leading `:`, `-`, whitespace in `ocr_service.dart:56-88`
- ✅ Bounding box adjustment: snap left edge to first alphanumeric character after punctuation removal
- ✅ Tests updated: added `onDeleteZone` callback to `ZoneEditorPanel` instantiation
- ✅ Analyzer clean, 7/7 tests pass

### 2026-09-29 08:00 UTC (Core Refactor)
- ✅ Provider refactor: lazy first-frame, no late var errors
- ✅ Render-only workflow: no auto-OCR on open
- ✅ Atomic gesture commit: local state + onPanEnd callback
- ✅ Shrink-wrap OCR: rect = bounding, samplingRect preserved
- ✅ Batch from page 2: preserve page 1 corrections
- ✅ Scrollable sheet: no fixed header overflow
- ✅ R8 blocker fix: ProGuard rules cho ML Kit optional scripts
- ✅ Regression tests: 7 tests, analyzer clean
- ✅ Build verification: APK 81.4MB release build success

### Pre-2026-09-29 (Legacy)
- Initial implementation với auto-OCR và các widget thử nghiệm
- Các tuyên bố về performance chưa được verify
