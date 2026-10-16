# BPA 1.8 Water Cooling — Test4 verification

## Nhánh và phạm vi

- Nhánh riêng: `feature/1.8-water-cooling-test4`, từ Test3 `4f0afb7466730ed29dbafc9b9cf363dde78aae3e`.
- Code APK: `e5817d0`; các giai đoạn trước: `43bfb94` (fluid/page/font), `32651d7` (landscape/flat-phone).
- Main vẫn là `8e6d1064f90dd9c2b252e3c5a865289c3ba25eba`. Chưa merge, push nhánh hoặc publish chính thức.
- Source tiếp nối bản phục dựng Test3; xem `water-1.8-test3-recovery.md` về nguồn gốc và giới hạn phục dựng. Không tuyên bố đã lấy lại Dart source gốc từ APK.

## Đã thay đổi

1. Thay nước dạng mặt phẳng nghiêng bằng solver hạt 2D Position Based Fluids: áp lực mật độ, vận tốc/quán tính từng mẫu, viscosity, biên trượt; tái dựng mặt nước liên tục bằng density field/marching squares. Hạt chỉ là dữ liệu mô phỏng, không vẽ thành chấm. Có bề mặt biến dạng, sóng, tách vùng khi va đập/lắc và nhập lại; giữ diện tích chiếu mục tiêu bằng ngưỡng density thích ứng. Shader xử lý truyền màu coolant, khúc xạ và độ sâu trên hình khối thật của solver.
2. Đọc thêm trọng lực Z. Xoay 90/180/360° dùng hướng trọng lực trong mặt màn hình. Khi nằm ngửa/úp gần phẳng, mô hình lớp nông tăng vùng phủ, giảm độ dày; cùng số mẫu nước, tích vùng phủ × độ dày giữ nguyên. Dựng lại sẽ chảy về đáy. Đây là **2D particle physics + phép chiếu lớp nông 2.5D**, không phải mô phỏng CFD 3D đầy đủ.
3. Water Cooling có route riêng chỉ mở từ tile Water. Bỏ toàn bộ editor khỏi sheet Theme chung. Không AppBar Back/tiêu đề/Lưu trên cùng; giữ một nút Lưu & Áp dụng chính. Preview thật ghim phía trên, vuốt tương tác, mở toàn màn hình; cùng solver/shader/RGB clock với nền app. Draft/discard/save và VFX illumination khi quay lại Theme được giữ.
4. Tên môn Water chiếm trọn chiều ngang phía trên, đo bằng font thật, thu về một dòng nếu còn đọc được hoặc tối đa hai dòng. Giờ/phòng/tiết/tag dùng Roboto dễ đọc; dành riêng vùng báo thức 44×44. Font Batman vẫn dùng cho tiêu đề/tên môn. Không sửa bố cục study card của theme khác.
5. Dừng render/cảm biến theo lifecycle như Test3; dùng buffer tái sử dụng và cache surface giữa background/preview. Surface khởi tạo lazy, không thêm bitmap mỗi frame.

Không thay renderer/logic ba widget, login, TraCuu, attendance/TH-LT, alarm, NFC, updater hoặc Tiên Môn trong Test4. Widget vẫn dùng RGB tĩnh theo giới hạn RemoteViews; video này chỉ là renderer trong app. Không thêm Parking.

Tham khảo thuật toán: Macklin & Müller, Position Based Fluids (2013), https://mmacklin.com/pbf_sig_preprint.pdf . Mã solver triển khai riêng, không nhúng mã nguồn paper.

## Kết quả kiểm tra

- Flutter toàn bộ: **175 PASS, 14 FAIL**. Baseline main nguyên trạng: **162 PASS, cùng đúng 14 tên FAIL**. So sánh tập tên lỗi không thêm/bớt; không tuyên bố suite xanh.
- Các kiểm tra Water đều qua: hạt hữu hạn/biên/đổi trọng lực, quán tính và tiêu tán, viscosity, diện tích khi breakup/rejoin, landscape, nằm phẳng/độ dày và dựng lại, GPU shader thật, route/preview/RGB/save, pause/resume, font Batman + Roboto thật, tên môn/phòng/tag với scale 1 và 1.4, hitbox báo thức.
- Native: **67 tests, 0 failures, 0 errors**, gồm ba renderer widget. Native build/test đã compile thay đổi payload gravity Z.
- JS: inline sync, retained WebView, TraCuu 7 scenarios, Notification changelog đều PASS.
- Dart analyze: không có diagnostic `error`; vẫn có warning/lint trong repo, không báo lint-clean.
- Render stress: 180 frame GPU thật qua va đập thành, đảo ngược, nằm phẳng và dựng lại; không exception/đường path vô hạn. MP4 được xuất offline từ renderer thật, **không phải quay thiết bị và không phải bằng chứng 30/60 FPS Android**.
- Probe Dart AOT trên máy build: 614 mẫu, 1212 frame; solver trung bình 3.83 ms/frame (không gồm surface/GPU). Năng lượng từ 0.00115 khi ổn định tăng 0.23720 sau xung lắc, rồi xuống 0.00716 sau dựng/đợi. Chỉ là số đo host, không thay kết quả FPS/CPU/RAM/pin điện thoại.

### Các lỗi Flutter đã có ở main

- app boots into the official QLDT login flow
- manual update requires displayed name before hold
- restores subject database through the legacy view adapter
- notification center replaces bell Snackbar and opens exam page
- period status survives notification center and exam navigation
- notification groups show only the changed schedule types
- notification center has a nonblank empty state
- notification center fits AppThemeId.classic
- notification center fits AppThemeId.minecraft
- notification center fits AppThemeId.valorant
- custom notification theme and font keep arrow card within screen
- countdown fits and remains readable in AppThemeId.minecraft
- countdown fits and remains readable in AppThemeId.valorant
- custom palette and wide custom font keep the tag within card

## APK đã xác minh

- File: `BPA-1.8-Water-Cooling-Test4-arm64.apk`, **133,983,516 bytes**.
- SHA256: `a5fb785fac31984ed4b284b48c4d0f3f983bd83936d479bd4bb3695702ba49ae`.
- Profile arm64, Flutter 3.47.2 / Dart 3.13.2; JDK17, compile SDK37, min SDK24, target SDK36.
- Package `vn.edu.phenikaa.better_phenikaa_schedule.waterrecovery`; label `BPA Water Cooling Test4`; versionName `cooc.1.8-test4`, versionCode **63**.
- `apksigner verify`: PASS. Certificate SHA256 `ab00f2d5d292d4866f66fc7ab8fc22b7016af42ac94a7a6c0a98889546bf7f2a` khớp Test3. Có thể nâng đè Test3 cùng package; giữ nguyên Test2 cài song song do khóa ký khác. Chưa thao tác cài lên máy người dùng.
- APK ZIP integrity PASS; có compiled shader, font Batman, ảnh Widget2 và arm64 `libapp.so`. Signing production/updater không sửa.

```bash
export CI=true ORG_GRADLE_PROJECT_bpaWaterRecovery=true
export COOC_VERSION_NAME=cooc.1.8-test4
flutter build apk --profile --target-platform android-arm64 \
  --build-name=1.8.0 --build-number=63 --no-pub
```

## Cần thử trên máy thật / chưa xác nhận

- Nghiêng trái/phải, xoay 180° và ngang; đặt nằm ngửa/úp, nghiêng từ phẳng sang dựng. Kiểm tra chiều nước đúng với orientation/sensor OEM, độ mượt, sự trở về cân bằng; lắc mạnh và nhẹ.
- Dùng font Batman và system với tên môn dài/cỡ chữ lớn; phòng/tag/báo thức. Mở preview Water, cuộn settings, xem toàn màn hình, lưu/hủy, quay lại Theme để kiểm tra VFX.
- Mở lại app sau nền/khóa màn hình; lịch không reset, không splash bất thường. Cài đè Test3 kiểm tra giữ cấu hình.
- Login thật/session/reload/timeout, attendance/TH-LT, lịch thi/alarm nền, Notification Center/NFC/updater và ba widget trên launcher. Test tự động không thay thế các bước này.
- Đo FPS, RAM, CPU, pin và thử cảm biến thực. Chưa có thiết bị Android thật trong phiên này; chưa bảo đảm 60 FPS hoặc kết luận không regression toàn bộ app.

## Sao lưu

`BPA-1.8-Water-Cooling-Test4-Source.zip` là cây source commit giao, `BPA-1.8-Test4.bundle` giữ lịch sử nhánh với prerequisite main nêu trên. Không chứa keystore hoặc cấu hình máy cục bộ. Với repo baseline có sẵn, fetch bundle vào `feature/1.8-water-cooling-test4` rồi checkout nhánh đó. Giữ Test3 để đối chiếu.
