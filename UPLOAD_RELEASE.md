# 📦 Hướng Dẫn Upload Release v1.0.0

## ✅ Các File Đã Sẵn Sàng

1. **APK File:** `OCR-QR_v1.0.0.apk` (83.23 MB)
2. **Release Notes:** `RELEASE_NOTES_v1.0.0.md`
3. **Git Tag:** `v1.0.0` (đã push lên GitHub)

---

## 📤 Cách Upload Lên GitHub Release

### Bước 1: Mở GitHub Releases
1. Truy cập: https://github.com/Catoxg9705/OCR-into-QR/releases
2. Click nút **"Draft a new release"** (hoặc **"Create a new release"**)

### Bước 2: Điền Thông Tin Release

**Choose a tag:**
- Chọn tag: `v1.0.0` (đã tồn tại)

**Release title:**
```
OCR-QR v1.0.0 - Static Fields + Critical Fixes
```

**Description:**
- Copy toàn bộ nội dung từ file `RELEASE_NOTES_v1.0.0.md` vào ô description
- (Nội dung đã có emoji, formatting, và changelog đầy đủ)

### Bước 3: Upload APK
1. Kéo thả file `OCR-QR_v1.0.0.apk` vào phần **"Attach binaries"**
2. Hoặc click **"Attach files by selecting them"** → chọn `OCR-QR_v1.0.0.apk`

### Bước 4: Publish
1. ✅ Check "Set as the latest release"
2. Click **"Publish release"**

---

## 🎯 Kết Quả Mong Đợi

Sau khi publish, GitHub release sẽ có:
- ✅ Tag: v1.0.0
- ✅ Title: OCR-QR v1.0.0 - Static Fields + Critical Fixes
- ✅ Body: Full changelog với emoji formatting
- ✅ APK download: OCR-QR_v1.0.0.apk (83.23 MB)
- ✅ Source code (zip + tar.gz) - tự động generate

---

## ⚠️ Lưu Ý

### Nếu Release v1.0.0 Đã Tồn Tại:
1. Vào release cũ
2. Click **"Edit release"** (icon bút chì)
3. Scroll xuống phần **Assets**
4. Xóa APK cũ (click X bên cạnh tên file)
5. Upload APK mới
6. Update description từ `RELEASE_NOTES_v1.0.0.md`
7. Click **"Update release"**

### APK Size Lớn (83 MB vs 30 MB cũ):
Đây là **bản debug** hoặc chưa optimize. Để giảm size xuống ~30 MB:

**Option 1: Build với --split-per-abi**
```bash
flutter build apk --release --split-per-abi
```
Tạo 3 APK nhỏ riêng:
- `app-armeabi-v7a-release.apk` (~28 MB)
- `app-arm64-v8a-release.apk` (~29 MB) ← Recommend cho device mới
- `app-x86_64-release.apk` (~30 MB)

**Option 2: Optimize với R8/ProGuard**
Đã enable trong `android/app/build.gradle`:
```gradle
buildTypes {
    release {
        shrinkResources true
        minifyEnabled true
        signingConfig signingConfigs.release
    }
}
```

---

## 📋 Quick Copy-Paste

### Release Title:
```
OCR-QR v1.0.0 - Static Fields + Critical Fixes
```

### Release Description:
(Copy toàn bộ nội dung từ `RELEASE_NOTES_v1.0.0.md`)

---

## 🔗 Link Upload Trực Tiếp

https://github.com/Catoxg9705/OCR-into-QR/releases/new?tag=v1.0.0&title=OCR-QR%20v1.0.0%20-%20Static%20Fields%20%2B%20Critical%20Fixes

---

**Sau khi upload xong, bạn có thể share link:**
```
https://github.com/Catoxg9705/OCR-into-QR/releases/tag/v1.0.0
```

Người dùng download APK từ **Assets** → `OCR-QR_v1.0.0.apk`
