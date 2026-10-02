# Hướng Dẫn Rebuild App

## Rebuild App Là Gì?

**Rebuild app** nghĩa là **xây dựng lại toàn bộ ứng dụng từ đầu**, xóa sạch cache và file build cũ. Điều này cần thiết khi:

- Thay đổi native Android code (`.kt`, `AndroidManifest.xml`, `file_paths.xml`)
- Thêm/sửa FileProvider configuration
- Thay đổi permissions
- App bị lỗi cache

---

## Cách Rebuild App

### Option 1: Clean + Run (Khuyến Nghị)

```bash
# Bước 1: Xóa cache và build cũ
flutter clean

# Bước 2: Lấy dependencies lại
flutter pub get

# Bước 3: Chạy app (tự động rebuild)
flutter run
```

**Giải thích:**
- `flutter clean` → Xóa folder `build/`, `.dart_tool/`
- `flutter pub get` → Tải lại packages
- `flutter run` → Build app mới hoàn toàn và cài lên device

---

### Option 2: Uninstall + Install (Khi Clean Không Đủ)

```bash
# Bước 1: Gỡ app khỏi điện thoại hoàn toàn
adb uninstall com.example.doc_qr_scanner

# Bước 2: Clean
flutter clean

# Bước 3: Run
flutter run
```

**Giải thích:**
- Gỡ app → Xóa toàn bộ data, cache, permissions cũ
- Clean → Xóa build artifacts
- Run → Cài app mới hoàn toàn

---

### Option 3: Build APK (Release Build)

```bash
# Build APK release
flutter build apk --release

# Cài APK lên device
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Khi Nào Cần Rebuild?

✅ **CẦN rebuild** khi thay đổi:
- `MainActivity.kt`
- `AndroidManifest.xml`
- `file_paths.xml`
- Gradle config
- Native permissions

❌ **KHÔNG CẦN rebuild** khi thay đổi:
- Flutter code (`.dart` files)
- UI/widgets
- Business logic
- Flutter hot reload sẽ tự apply

---

## Hot Reload vs Hot Restart vs Rebuild

| | Hot Reload | Hot Restart | Rebuild |
|---|---|---|---|
| **Thay đổi UI/logic** | ✅ Instant | ✅ Fast | ❌ Slow |
| **Thay đổi state** | ❌ Giữ state | ✅ Reset state | ✅ Reset all |
| **Thay đổi native** | ❌ | ❌ | ✅ Full rebuild |
| **Tốc độ** | <1s | ~5s | ~30s+ |

**Phím tắt:**
- `r` = Hot reload
- `R` = Hot restart
- `q` = Quit + `flutter run` = Rebuild

---

## Troubleshooting

### Lỗi "FileProvider not found"
→ Cần rebuild vì thay đổi `AndroidManifest.xml`

```bash
flutter clean
flutter run
```

### Lỗi "Failed to find configured root"
→ Cần rebuild vì thay đổi `file_paths.xml`

```bash
adb uninstall com.example.doc_qr_scanner
flutter clean
flutter run
```

### App vẫn lỗi sau clean
→ Uninstall hoàn toàn

```bash
adb uninstall com.example.doc_qr_scanner
flutter clean
flutter pub get
flutter run
```

---

## Tóm Tắt

**Cho fix lỗi "Mở thư mục" hiện tại:**

```bash
# Đơn giản nhất
flutter clean
flutter run

# Nếu vẫn lỗi
adb uninstall com.example.doc_qr_scanner
flutter run
```

Chỉ mất ~30-60 giây!
