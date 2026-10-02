# UX Workflow Summary - Doc QR Scanner

## Thiết kế UX Hoàn chỉnh theo 3 Bước

Đã cấu trúc lại toàn bộ luồng tương tác để ứng dụng trực quan, thoáng màn hình và mượt mà.

---

## 1. Vị trí Nút Điều khiển

### ✅ 2 Nút góc trên trái (FloatingActionButton.small)
- **Nút Quét chữ:** Icon `document_scanner`, màu vàng (`#FBBF24`), tooltip "Quét chữ"
- **Nút Đổi tệp:** Icon `swap_horiz`, màu xanh (`#5B8CFF`), tooltip "Đổi tệp"
- Vị trí: `FloatingActionButtonLocation.startTop`
- Hiển thị: Chỉ khi có tài liệu được chọn
- File: `lib/screens/document_picker_screen.dart:279-329`

---

## 2. Khung Tương Tác (InteractiveZone)

### Viền & Màu sắc
- **Chưa quét (Manual):** Viền cyan (`#22D3EE`) 2.5px, nền cyan bán trong suốt
- **Đã quét (Scanned):** Viền đen 1.5px, nền trong suốt
- **Active (đang chọn):** Viền xanh dương (`#5B8CFF`) bất kể trạng thái

### Controls (chỉ hiển thị khi zone active)
1. **Nút Xóa** (góc trên trái):
   - Icon: `close` (màu trắng)
   - Nền: Đỏ, hình tròn, 18px
   - Chức năng: Xóa zone ngay lập tức

2. **Nút Quét vùng này** (góc trên phải):
   - Icon: `qr_code_scanner` (màu trắng)
   - Nền: Cyan (`#22D3EE`), hình tròn, 18px
   - Chức năng: Trích xuất text trong vùng khung

3. **Tay nắm Resize** (góc dưới phải):
   - Icon: `drag_handle` (màu trắng)
   - Nền: Cyan (`#22D3EE`), 24x24px, bo góc trên trái 4px
   - Chức năng: Kéo để thay đổi kích thước (tối thiểu 50x30)

4. **Di chuyển toàn khung:**
   - Chạm vào lòng khung → kéo di chuyển khắp tài liệu
   - `GestureDetector.onPanUpdate` trên toàn bộ Container

### File: `lib/widgets/interactive_zone.dart`

---

## 3. Quy Trình 3 Bước (Workflow)

### 🔵 Bước 1: Đặt khung
**Hành động người dùng:**
- Tap nút "+ Thêm trường mới" trong panel

**Phản hồi hệ thống:**
- Tạo khung cyan 200x50 ở giữa ảnh
- **ẨN HOÀN TOÀN panel** (`_isPanelVisible = false`)
- Đặt zone mới thành active
- Hiện đầy đủ controls (xóa/scan/resize/move)

**Mục đích:**
- Màn hình rộng rãi 100% để người dùng thấy rõ tài liệu
- Thoải mái kéo thả, resize bao trọn vùng chữ cần lấy

**Code:**
```dart
// lib/services/document_state.dart:110-123
void addZone() {
  final zone = TemplateZone(
    id: _uuid.v4(),
    rect: Rect.fromCenter(center: center, width: 200, height: 50),
    label: 'New Field',
    extractedText: '',
    isManual: true,
  );
  _zones = [..._zones, zone];
  _activeZoneId = zone.id;
  _isPanelVisible = false; // ẨN PANEL
  notifyListeners();
}
```

---

### 🔵 Bước 2: Quét & Co khít
**Hành động người dùng:**
- Tap nút scan (cyan, góc trên phải) trên khung

**Phản hồi hệ thống:**
- Tìm tất cả OCR blocks/lines nằm trong `zone.rect`
- Trích xuất text từ các line giao nhau
- Tính bounding box khít của các line text thực tế
- **Tự động co kích thước khung khít lại** theo bounding box
- Chuyển `isManual = false` → viền đổi sang đen 1.5px
- **HIỆN PANEL** (`_isPanelVisible = true`)
- Dữ liệu xuất hiện trong form để kiểm tra

**Mục đích:**
- Khung ôm sát text, không dư khoảng trắng
- Chuyển từ trạng thái chỉnh sửa → trạng thái tĩnh
- Người dùng kiểm tra/sửa text trong form panel

**Code:**
```dart
// lib/services/document_state.dart:165-237
void scanManualZone(String zoneId) {
  // ... lọc OCR blocks/lines
  // Tính tight rect
  if (intersectingLines.isNotEmpty) {
    tightRect = Rect.fromLTRB(minLeft, minTop, maxRight, maxBottom);
  }
  
  // Cập nhật zone
  _zones = [
    for (final z in _zones)
      if (z.id == zoneId)
        z.copyWith(
          extractedText: extractedText,
          isManual: false,        // Chuyển thành tĩnh
          rect: tightRect ?? z.rect, // Co khít
        )
      else z,
  ];
  
  _isPanelVisible = true; // HIỆN PANEL
  notifyListeners();
}
```

---

### 🔵 Bước 3: Hiện Form & Tiếp tục cho phép sửa
**Hành động người dùng:**
- Kiểm tra dữ liệu trong form panel
- Xóa chữ thừa hoặc gõ thêm trong TextField Value
- **QUAN TRỌNG:** Tap lại vào khung đã quét

**Phản hồi hệ thống:**
- Zone đã quét VẪN LÀ WIDGET TƯƠNG TÁC
- Khi tap vào → kích hoạt lại (`isActive = true`)
- Hiện lại viền xanh dương + controls (xóa/scan/resize/move)
- Có thể tiếp tục nới rộng/di chuyển và quét lại nếu muốn

**Mục đích:**
- **Không khóa cứng khung sau khi quét**
- Cho phép sửa sai nếu quét thiếu/thừa
- Linh hoạt điều chỉnh bất cứ lúc nào

**Code:**
```dart
// lib/widgets/interactive_zone.dart:110-114
child: GestureDetector(
  onTap: widget.onTap, // Tap để kích hoạt lại
  onPanUpdate: showControls ? _handlePanUpdate : null,
  onPanEnd: showControls ? _handlePanEnd : null,
  child: Container(...)
)

// lib/widgets/document_preview_widget.dart:187-189
onTap: onZoneTap != null && zone.id != activeZoneId
    ? () => onZoneTap!(zone) // Gọi selectZone()
    : null,
```

---

## 4. Tính Năng Panel (ZoneEditorPanel)

### Header với nút đóng
- Thanh kéo ở giữa (40x4, màu white24)
- **Nút đóng** (IconButton `close`, màu white54) bên phải
- Callback: `onPanelVisibilityChanged(false)` → ẩn panel thủ công

### Tự động ẩn/hiện
- **Ẩn khi:** Tạo zone mới (`addZone()`)
- **Hiện khi:** Quét xong (`scanManualZone()`)
- **Ẩn khi:** Xóa hết zones (`deleteZone()` kiểm tra `_zones.isEmpty`)

### File: `lib/widgets/zone_editor_panel.dart:51-77`

---

## 5. Hiệu Năng & Mượt Mà

### Local State Management
- Di chuyển & Resize chỉ gọi `setState()` cục bộ
- Callback `onPositionChanged`/`onSizeChanged` chỉ gọi **một lần** khi `onPanEnd`
- **Không** gọi `notifyListeners()` toàn cục khi đang kéo
- Đảm bảo 60fps mượt mà

### Code:
```dart
// lib/widgets/interactive_zone.dart:56-68
void _handlePanUpdate(DragUpdateDetails details) {
  setState(() { // Chỉ update local
    final dx = details.delta.dx / widget.scale;
    final dy = details.delta.dy / widget.scale;
    _localPosition = Offset(
      _localPosition.dx + dx,
      _localPosition.dy + dy,
    );
  });
}

void _handlePanEnd(DragEndDetails details) {
  widget.onPositionChanged(_localPosition); // Callback một lần
}
```

---

## 6. Kiểm Tra Hoàn Tất

### ✅ Đã Triển Khai
1. 2 nút góc trên trái (Quét chữ + Đổi tệp) ✓
2. Khung tương tác đầy đủ (xóa/scan/resize/move) ✓
3. Quy trình 3 bước (ẩn panel → quét → hiện panel) ✓
4. Zone đã quét vẫn có thể tap để chỉnh sửa lại ✓
5. Panel có nút đóng thủ công ✓
6. Tự động ẩn panel khi xóa hết zones ✓
7. Hiệu năng 60fps (local state, callback một lần) ✓

### ⚠️ Cần Test Trên Thiết Bị Thật
- UX kéo thả khung cyan mượt mà không
- Overflow có xảy ra khi bật bàn phím không
- Quét vùng chọn trích xuất text chính xác không
- Tap zone đã quét có kích hoạt lại được không
- Chỉnh sửa dữ liệu trong form panel hoạt động tốt không

---

## 7. Files Đã Sửa

| File | Thay đổi |
|------|----------|
| `lib/widgets/zone_editor_panel.dart` | Thêm callback `onPanelVisibilityChanged`, header có nút đóng |
| `lib/services/document_state.dart` | `setPanelVisible()`, logic ẩn/hiện tự động trong `addZone()`, `scanManualZone()`, `deleteZone()` |
| `lib/widgets/interactive_zone.dart` | Widget thống nhất cho tất cả zones, controls chỉ hiển thị khi active |
| `lib/screens/document_picker_screen.dart` | Truyền callback `onPanelVisibilityChanged` |
| `DEV_LOG.md` | Cập nhật Current Status và Completed Tasks |

---

## 8. Next Steps

1. **Build APK và test trên điện thoại Android:**
   ```bash
   flutter build apk --debug
   adb install build/app/outputs/flutter-apk/app-debug.apk
   ```

2. **Kiểm tra UX workflow:**
   - Chọn tài liệu → Quét chữ
   - Tap "+ Thêm trường mới" → Panel ẩn
   - Kéo thả khung cyan → mượt không
   - Resize khung → tay nắm hoạt động tốt không
   - Tap nút scan → khung co khít, panel hiện
   - Tap vào zone đã quét → kích hoạt lại được không
   - Chỉnh sửa text trong form → dữ liệu cập nhật đúng không

3. **Sau khi xác nhận UX hoàn chỉnh:**
   - Phase 4: Lưu Template theo loại tài liệu
   - Phase 5: Tạo mã QR & Chèn lên tài liệu
   - Phase 6: Xuất dữ liệu ra file .txt

---

**Kiểm tra biên dịch:**
```bash
flutter analyze
# No issues found! (ran in 4.5s)
```
