# Better Phenikaa DemoF3

Ứng dụng Flutter hiển thị lịch học, lịch thi và widget Android cho sinh viên
Phenikaa. DemoF3 kế thừa giao diện, chức năng, animation và toàn bộ preset theme
của DemoF; các fix sync/widget phù hợp từ demoD được tích hợp có chọn lọc.

## Tính năng chính

- Đăng nhập QLĐT/Microsoft trong WebView và đồng bộ thủ công.
- Lưu snapshot lịch cục bộ; dữ liệu hợp lệ cũ không bị ghi đè khi sync lỗi.
- Đồng bộ nền bằng một WorkManager hữu hạn cho lần 06:00 địa phương tiếp theo.
- Widget dùng kích thước launcher thực tế, hiển thị lịch ngày hiện tại và tự làm
  mới khi đổi ngày, reboot, sync thành công hoặc dữ liệu thay đổi.
- Giữ nguyên 10 preset: Classic, League of Legends, Valorant, Minecraft,
  Facebook, Shopee, TikTok, Ben 10, YouTube và Steam.
- Theme Engine sinh token có kiểm tra contrast từ ảnh hoặc 2–3 màu theo tỷ lệ.
- Preview trước khi áp dụng; lưu, sửa, xóa nhiều custom theme.
- Font hệ thống, font tích hợp và import TTF/OTF vào private app storage.
- Widget giữ palette custom nhưng dùng font hệ thống an toàn khi RemoteViews không
  hỗ trợ font đã nhập.

## Cấu trúc feature

Tên thư mục feature dùng tiếng Việt không dấu:

- `lib/features/dang_nhap_qldt/`
- `lib/features/dong_bo_hang_ngay/`
- `lib/features/tien_ich_lich_hoc/`
- `lib/features/giao_dien/`

Chi tiết nằm tại `lib/features/README.md`.

## Quyền riêng tư và bảo mật

- Ảnh, screenshot, wallpaper và font chỉ được xử lý trên thiết bị.
- File được chọn qua Android Storage Access Framework rồi sao chép vào vùng
  private của ứng dụng; không upload lên server.
- Ứng dụng không thêm analytics, tracker hay backend thu thập custom theme.
- Không log mật khẩu, cookie, token hoặc dữ liệu đăng nhập QLĐT.
- Không commit credential, session thật, keystore hoặc database người dùng.

## Kiểm tra và build

Yêu cầu Flutter 3.47.2, Dart 3.13, JDK 17 và Android SDK phù hợp.

```bash
bash tool/bootstrap.sh
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
flutter build apk --debug
flutter build apk --release
```

GitHub Actions chạy lại analyze, Flutter test, native Android test và build APK.
WorkManager có thể chạy sau 06:00 tùy tối ưu pin/hạn chế nền của Android; ứng dụng
không dùng exact alarm để ép giờ và không tự mở Activity/WebView lên màn hình.
