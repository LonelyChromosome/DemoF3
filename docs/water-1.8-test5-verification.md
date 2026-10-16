# BPA 1.8 Water Cooling — Test5

## Phạm vi và nhánh

- Nhánh: `feature/1.8-water-cooling-test5`, từ Test4 `2133d14182d65540685e4d7a31377e5214533129`.
- Commit code APK: `f78ca9d`; tối ưu engine: `d501076`.
- Main vẫn `8e6d1064f90dd9c2b252e3c5a865289c3ba25eba`, không merge/push/publish chính thức.
- Giữ source phục dựng và giới hạn nền đã ghi ở `water-1.8-test3-recovery.md`; giữ nguyên các thay đổi font, preview và fluid của Test4.

## Đã sửa

1. Nút **Chỉnh Water Cooling** riêng: khi đang dùng Water, nút nằm ngay phần đầu sheet Giao diện và luôn thấy trước vùng preset cuộn. Khi dùng theme khác, nút nằm ngay dưới preset Water. Bấm ô preset là chọn theme, không mở editor nữa. Bấm ô Water đang dùng không reset cấu hình. Editor vẫn là trang riêng có preview nước trực tiếp, RGB/settings/draft và một Lưu & Áp dụng.
2. Pressure solver xử lý mỗi cặp hạt một lần, dùng lại gradient/kernel cho hai phía và bước sửa vị trí. Buffer tái sử dụng; chỉ mở rộng cache nếu gặp mật độ va chạm cao hơn dung lượng hiện tại. Không giảm số hạt, số vòng pressure hay chuyển sang giảm hiệu ứng mặc định.
3. Dựng mặt nước dùng histogram có trọng số thay cho 8 lần quét lưới tìm ngưỡng thể tích. Giữ độ phân giải lưới, topology tách/nhập, diện tích mục tiêu và shader coolant. Histogram có độ phân giải ngưỡng cao hơn phép tìm cũ.
4. Đồng hồ mô phỏng cố định **120 Hz**, nội suy vị trí cho từng khung hình hiển thị. Tránh Test4 cứ dt hơi lớn hơn 16,67 ms lại nhảy từ 2 sang 3 bước tính. Khung nằm giữa hai bước mô phỏng vẫn có vị trí render mới. 120 Hz ở đây là bước tính vật lý, **không phải tuyên bố FPS Android**. Catch-up được giới hạn, lifecycle nền/route che vẫn dừng như cũ.

Giữ nguyên số lượng/logic ba widget, Tiên Môn, theme khác, login/reload/session, attendance/TH-LT, alarm, NFC, Notification Center và updater. Không thêm Parking, không đổi production signing/updater feed. Widget vẫn RGB tĩnh theo cơ chế trước.

## Hiệu năng đã đo

Probe Dart AOT, cùng máy build, cùng 614 mẫu/1212 khung/pressure iterations. Ba lượt xen kẽ Test4 và Test5:

| Bản | Lượt 1 | Lượt 2 | Lượt 3 | Trung vị |
| --- | ---: | ---: | ---: | ---: |
| Test4 | 4.064 ms | 3.939 ms | 4.067 ms | 4.064 ms |
| Test5 | 2.605 ms | 2.740 ms | 2.671 ms | 2.671 ms |

Thời gian **solver CPU** trung vị giảm **34.3%**. Không bao gồm GPU/surface/layout. Đây là số đo host, không quy đổi thành FPS điện thoại hoặc kết luận hết giật trên thiết bị của người dùng.

Benchmark surface+solver có thể chạy lại bằng `flutter test tool/water_frame_benchmark_test.dart`; probe AOT tại `tool/water_fluid_probe.dart`. Không dùng FPS của video xuất offline để chứng minh độ mượt.

## Kiểm thử

- Flutter toàn bộ: **177 PASS, 14 FAIL**. So với main nguyên trạng (162 PASS/14 FAIL): tập 14 tên lỗi giống hệt, không thêm tên lỗi mới. Danh sách lỗi kế thừa xem báo cáo Test4. Không tuyên bố suite xanh hay mọi chức năng thực tế đã xác nhận.
- Hai kiểm tra cadence mới: cùng quỹ đạo khi vsync dao động quanh 60 Hz; khi chưa đến bước solver tiếp theo, density render vẫn thay đổi nhờ nội suy.
- Kiểm tra nút chỉnh riêng, preset không mở editor/reset config hiện tại, page có preview ghim, màu RGB, cuộn, fullscreen và Save: PASS.
- Fluid impact/inversion/flat-phone/landscape, thể tích và tách/nhập, font/hitbox/lifecycle/render GPU thật: PASS trong suite.
- JS inline sync, retained authenticated WebView, TraCuu 7 scenarios, Notification changelog: PASS.
- Scoped Dart analyze: không có `error`; còn lint và một unused import Tiên Môn có sẵn. Không báo lint-clean.
- Native 67/67 PASS kế thừa lần chạy Test4, **không chạy lại riêng native unit suite trong Test5**; Test5 không sửa native logic, chỉ label. Build APK đã compile/package phần native.

## APK đã xác minh

- File: `BPA-1.8-Water-Cooling-Test5-arm64.apk`, 124,013,119 bytes.
- SHA256: `74195724433a8e455a1f47188627d7215d578431a925800fba85a61510f560e5`.
- Profile arm64, versionName `cooc.1.8-test5`, versionCode **64**, label `BPA Water Cooling Test5`.
- Package `vn.edu.phenikaa.better_phenikaa_schedule.waterrecovery`; min SDK24, target36, compile37.
- APK ZIP integrity PASS; compiled shader và arm64 libapp tồn tại.
- Signature verify PASS; certificate SHA256 `ab00f2d5d292d4866f66fc7ab8fc22b7016af42ac94a7a6c0a98889546bf7f2a` khớp Test3/Test4, có thể cài nâng đè giữ sandbox dữ liệu. Chưa cài lên điện thoại của người dùng.

```bash
export CI=true ORG_GRADLE_PROJECT_bpaWaterRecovery=true
export COOC_VERSION_NAME=cooc.1.8-test5
flutter build apk --profile --target-platform android-arm64 \
  --build-name=1.8.0 --build-number=64 --no-pub
```

## Chưa xác minh / cần thử điện thoại

- FPS/frame pacing trên thiết bị của người dùng; thời gian CPU/GPU, nhiệt và pin. Chưa có máy Android thật trong phiên này; không bảo đảm 60 FPS.
- Cùng màu/mode/mực nước của Test4, so sánh nghiêng/lắc/xoay và nằm phẳng, nhất là khi nhiều card/viền RGB và mở preview.
- Mở Giao diện → Chỉnh Water Cooling; sửa/hủy/lưu, bảo toàn ảnh widget/font/settings, quay Custom → Theme giữ illumination VFX.
- Nền/khóa màn hình/quay lại, các widget trên launcher, login/session/reload/attendance/TH-LT/thi/alarm/NFC/updater thực tế. Không có thay đổi pipeline nhưng test tự động không thay bước xác nhận này.

## Sao lưu

ZIP source chứa toàn bộ cây source commit giao. Bundle giữ lịch sử nhánh Test5 với prerequisite baseline main nêu trên. Không có keystore hoặc cấu hình môi trường máy build. Không merge main khi chưa được người dùng xác nhận.
