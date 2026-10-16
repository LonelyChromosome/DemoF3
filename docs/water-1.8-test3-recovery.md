# BPA 1.8 Water Cooling — Test3 recovery

## Nguồn và phạm vi

- Nhánh: `feature/1.8-water-cooling-recovery`.
- Baseline main 1.7: `8e6d1064f90dd9c2b252e3c5a865289c3ba25eba` (không sửa main).
- APK test2 đầu vào: SHA256 `df8b1c0d8d3dc8a28b44762461577a42f5ad37e9759427dbf23be4fa67c9ee98`.
- Đây là **source phục dựng**, không phải bản source Dart gốc được lấy lại từ APK. APK chỉ chứa Dart AOT đã biên dịch. Font Batman và ảnh Water Cooling Widget2 được khôi phục nguyên byte; native contracts được đối chiếu bằng JADX; logic ổn định dùng lại từ main 1.7.

## Năm chỉnh sửa

1. Splash nằm ngoài WaterStage, có thời hạn kết thúc, được loại bỏ khi app vào nền. Stage giữ cùng cây state khi đổi theme; dừng ticker/cảm biến khi nền hoặc bị trang opaque che.
2. Đo font thật và text scaler theo vùng tên môn; giới hạn 2 dòng/42 logical px, thu nhỏ rồi ellipsis. Giữ vùng báo thức, co giờ/ngày theo bề ngang. Sửa việc scale TextStyle có fontSize kế thừa null.
3. WaterEditor là nội dung inline trong sheet Giao diện, không có route/Scaffold/AppBar riêng. Giữ một nút Lưu & Áp dụng; draft, preset và bản tùy chỉnh lưu riêng.
4. Giữ VFX illumination khi quay từ Custom về Theme; tách sự kiện này khỏi sync thành công để không kết thúc pump boost sớm.
5. Tăng màu truyền qua acrylic và meniscus/phản xạ/độ hấp thụ theo chiều sâu. Bỏ lớp nền gần đặc đang che bể. Hình khối nước dùng mặt thoáng, bảo toàn thể tích, trọng lực, sóng và các giọt tách khi lắc; không chỉ xoay gradient.

## Phần được giữ/phục dựng

- 11 LED modes, một đồng hồ và trường RGB toàn cục trong app; bảng màu RGB 2D, preview trực tiếp.
- Nước đi theo hướng trọng lực đủ vòng, có quán tính và sóng giảm dần; Tilt có công tắc. Solver mặt thoáng 2D + giọt ballistic, không tuyên bố là CFD/SPH 3D.
- Ba pipeline widget dùng RGB tĩnh, nền full fit, widget nhỏ/lớn blur; Widget2 có ảnh cơ khí, ảnh/crop cá nhân được ưu tiên. Preview dùng compositor native.
- Widget Android truyền thống không chạy RGB 60 FPS; không dùng live wallpaper/overlay ngoài widget.
- Tiên Môn, theme cũ, đăng nhập/retained QLĐT, TraCuu/parser/verifier, attendance/TH-LT, alarm, NFC và updater giữ pipeline 1.7. Không thêm Parking.

## Kiểm tra đã chạy

- 108 kiểm tra Flutter chọn lọc: PASS; gồm 9 kiểm tra Water mới (shader GPU thật, xoay 180°, font Batman thật, hitbox góc bo, inline Theme, mở lại app, giữ lịch khi đổi theme).
- Bộ Flutter rộng: 171 PASS, 14 FAIL. Main nguyên trạng: 162 PASS, cùng đúng 14 FAIL; không thêm tên test lỗi. Các lỗi kế thừa được liệt kê dưới đây, không báo toàn bộ suite xanh.
- Native: 67 tests, 0 failures/errors, gồm 3 kiểm tra Robolectric native graphics trên ba renderer, draft màu và ảnh/crop cá nhân.
- JS retained WebView, inline sync, TraCuu 7 scenarios và Notification changelog: PASS.
- Phân tích Dart: không có lỗi biên dịch; vẫn còn lint/cảnh báo trong repo. Shader được compile/render trong Flutter test.

### 14 lỗi đã có trên main

- app boots into the official QLDT login flow
- manual update requires displayed name before hold
- period status survives notification center and exam navigation
- notification groups show only the changed schedule types
- restores subject database through the legacy view adapter
- notification center has a nonblank empty state
- notification center fits AppThemeId.classic
- notification center replaces bell Snackbar and opens exam page
- notification center fits AppThemeId.minecraft
- notification center fits AppThemeId.valorant
- custom notification theme and font keep arrow card within screen
- countdown fits and remains readable in AppThemeId.minecraft
- countdown fits and remains readable in AppThemeId.valorant
- custom palette and wide custom font keep the tag within card

## Build và cài thử

```bash
export CI=true
export ORG_GRADLE_PROJECT_bpaWaterRecovery=true
export COOC_VERSION_NAME=cooc.1.8-test3
flutter build apk --profile --target-platform android-arm64 \
  --build-name=1.8.0 --build-number=62 --no-pub
```

Dùng Flutter 3.47.2 / Dart 3.13.2, JDK 17, AGP 9.1.1, Kotlin 2.4.0, Android compile SDK 37. Chạy `tool/bootstrap.sh` theo repo trước khi build. Thiết lập proxy/SDK trong môi trường phục dựng là cấu hình máy cục bộ, không commit vào source.

APK test3 dùng package `vn.edu.phenikaa.better_phenikaa_schedule.waterrecovery`, label `BPA Water Cooling Test3`, versionName `cooc.1.8-test3`, versionCode 62. Chỉ bật suffix cho non-release khi có property trên. Signing release và updater feed không sửa.

Khóa ký test2 đã mất và không thể lấy từ APK. Test3 dùng khóa debug mới, **cài song song**; không nâng đè test2, không tự chuyển dữ liệu/ảnh từ sandbox của test2. Giữ test2 trên máy.

## Còn cần thiết bị thật

- Mở app/lùi nền/quay lại nhiều lần, khóa màn hình, mở từ widget.
- Xoay 90/180/360°, lắc nhẹ/mạnh, dừng máy; kiểm tra chiều trọng lực, sóng và độ ổn định.
- Kiểm tra tên môn dài với Batman/system và cỡ chữ hệ thống lớn; vùng báo thức không chồng chữ.
- Thay mode/màu trong Theme, mở Custom rồi quay lại, Lưu & Áp dụng, khởi động lại.
- Thêm cả ba widget lên launcher thật, đổi kích thước, kiểm tra ảnh/crop, điều hướng và sync.
- Login thật, session reuse, reload/timeout, attendance, TH/LT, alarm nền, NFC, Notification Center, updater và theme cũ.
- Đo FPS/CPU/RAM/pin trên thiết bị. Chưa có kết quả đo Android thật hoặc bảo đảm 60 FPS.

Chưa merge, push nhánh hay phát hành chính thức. APK thử nghiệm chưa thay thế xác nhận trên thiết bị của người dùng.

## Artifact đã xác minh

- File: `BPA-1.8-Water-Cooling-Test3-arm64.apk` (123,893,380 bytes).
- SHA256: `e5fc62e6b00ba2ba0abec95f6bee75c53dff7bbf39c7554b0772ccfbce69429e`.
- APK Signature Scheme v2: verified; signer debug SHA256 `ab00f2d5d292d4866f66fc7ab8fc22b7016af42ac94a7a6c0a98889546bf7f2a`.
- Package/label/version đã đọc lại bằng aapt: `.waterrecovery`, `BPA Water Cooling Test3`, `cooc.1.8-test3` / 62. Min SDK 24, target SDK 36, compile SDK 37; Flutter engine/AOT arm64.
- ZIP integrity và shader/font/ảnh Widget2/libapp.so trong APK đều đã kiểm tra.
- Build cuối: PASS (profile arm64). Native kiểm tra lại sau chỉnh sửa nội dung cuối: 67/67 PASS.
- Lưu APK qua Library thất bại ở bước chuẩn bị; các link tải trực tiếp trỏ tới tệp thực trong phiên làm việc. Tải cả APK và source sao lưu.

## Khôi phục source

`BPA-1.8-Water-Cooling-Source.zip` chứa toàn bộ cây source của commit giao. `BPA-1.8-Recovery.bundle` giữ các commit nhánh phục dựng, với prerequisite là baseline main ghi ở trên. Với repo đã clone baseline, fetch bundle rồi chuyển sang nhánh `feature/1.8-water-cooling-recovery`. Không có keystore production hoặc cấu hình máy cục bộ trong các gói source.
