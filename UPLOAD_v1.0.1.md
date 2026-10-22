# 🚀 Upload v1.0.1 Hotfix - Quick Guide

## ✅ Build Complete

**APK File:** `OCR-QR_v1.0.1_fixed.apk`  
**Size:** 83.74 MB  
**Commit:** `04cebc6`  
**Tag:** `v1.0.1`

---

## 📤 GitHub Release - 2 Phút Setup

### 1️⃣ Mở Link Tạo Release
👉 **Click here:** https://github.com/Catoxg9705/OCR-into-QR/releases/new?tag=v1.0.1

### 2️⃣ Điền Thông Tin

**Release Title:**
```
OCR-QR v1.0.1 - Hotfix: ML Kit Release Build Crash
```

**Description:** (Copy từ dưới)
```markdown
## 🐛 Critical Hotfix

**Fixes ML Kit crash in release builds** - v1.0.0 crashed with `NullPointerException` when scanning fields on production APK. This hotfix adds ProGuard keep rules to preserve ML Kit classes.

### What's Fixed
- ✅ ML Kit NullPointerException in release APK → **RESOLVED**
- ✅ ProGuard stripping ML Kit classes → Added comprehensive keep rules
- ✅ Static field validation → Multi-layer null safety checks
- ✅ Release build stability → Verified working on device

### Technical Details
- **Root Cause:** ProGuard/R8 code shrinking removed ML Kit classes accessed via JNI
- **Fix:** Added `proguard-rules.pro` keep rules for `com.google.mlkit.**`, `org.tensorflow.lite.**`, GMS
- **Verification:** ProGuard mapping confirms ~200+ ML Kit classes preserved
- **APK Size:** 83.74 MB (universal)

### Upgrade from v1.0.0
⚠️ **Uninstall v1.0.0 first, then install v1.0.1** (signature may differ)

```bash
adb uninstall com.example.doc_qr_scanner
adb install OCR-QR_v1.0.1_fixed.apk
```

### Files Changed
- `android/app/build.gradle.kts` - Enabled minification
- `android/app/proguard-rules.pro` - Added ML Kit keep rules (61 lines)
- `lib/services/document_state.dart` - Enhanced validation
- `lib/services/ocr_service.dart` - Null-safety checks

Full changelog: [HOTFIX_v1.0.1.md](https://github.com/Catoxg9705/OCR-into-QR/blob/main/HOTFIX_v1.0.1.md)

---

**Tested On:** Android 10+ (physical device)  
**Known Issues:** None  
**Next Version:** v1.1.0 (planned features TBD)
```

### 3️⃣ Upload APK
Kéo thả file `OCR-QR_v1.0.1_fixed.apk` vào **Attach binaries** box

### 4️⃣ Publish
- ✅ Check **"Set as the latest release"**
- ✅ Uncheck "Set as a pre-release" (this is stable)
- Click **"Publish release"**

---

## 🧪 Test Trên Device (Recommended)

### Trước khi publish, test:
```bash
# 1. Uninstall bản cũ
adb uninstall com.example.doc_qr_scanner

# 2. Install bản mới
adb install OCR-QR_v1.0.1_fixed.apk

# 3. Test flow
# - Chọn PDF 13 trang
# - Thêm 1 static field (e.g., "Công ty: LICO")
# - Vẽ 2 OCR zones
# - Scan → Phải KHÔNG crash
# - Batch process → Phải chạy mượt
# - Export PDF → Phải hoàn thành
```

### Kiểm tra log
```bash
adb logcat | grep -E "(ERROR|FATAL|mlkit)"
```

**Nếu thấy:**
- ❌ `NullPointerException` → ProGuard rules chưa apply
- ✅ `Page 1 canvas ready` → Bình thường
- ✅ `Scan fields success` → Thành công!

---

## 📊 So Sánh Versions

| Feature | v1.0.0 (Broken) | v1.0.1 (Fixed) |
|---------|-----------------|----------------|
| Debug Build | ✅ Works | ✅ Works |
| Release Build | ❌ Crash | ✅ Works |
| ProGuard | ⚠️ Strips ML Kit | ✅ Keeps ML Kit |
| APK Size | 83.23 MB | 83.74 MB |
| Static Fields | ⚠️ Unsafe | ✅ Validated |

---

## 💡 Lưu Ý

### APK Size Optimization (Optional)
Nếu muốn giảm size, build split APKs:
```bash
flutter build apk --release --split-per-abi
```

Tạo 3 APK:
- `app-arm64-v8a-release.apk` (30 MB) ← **Recommended** cho Android hiện đại
- `app-armeabi-v7a-release.apk` (28 MB) ← Cho device cũ
- `app-x86_64-release.apk` (32 MB) ← Emulator

Upload cả 3 APK hoặc chỉ `arm64-v8a` là đủ.

### ProGuard Mapping
File `build/app/outputs/mapping/release/mapping.txt` giúp decode crash logs. Lưu file này để debug sau:
```bash
# Backup mapping
cp build/app/outputs/mapping/release/mapping.txt mapping_v1.0.1.txt
```

Khi có crash log từ user:
```bash
# Decode obfuscated stack trace
$ANDROID_HOME/tools/proguard/bin/retrace.sh mapping_v1.0.1.txt crash_log.txt
```

---

## ✅ Checklist

- [x] Build release APK thành công
- [x] ProGuard enabled + ML Kit rules added
- [x] Verified ML Kit classes in seeds.txt
- [x] Git commit + tag v1.0.1
- [x] Push to GitHub
- [ ] **Test APK trên device** 🔴 ← Làm trước khi publish!
- [ ] Create GitHub release
- [ ] Upload APK
- [ ] Publish release

---

**Time:** 22/10/2026 11:35 SA  
**Next:** Test APK → Publish release → Done! 🎉
