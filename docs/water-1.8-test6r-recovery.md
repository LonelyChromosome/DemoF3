# Water Cooling Test6R — sửa trên ZIP Test5

## Nguồn và nhánh

Bản này sửa trực tiếp `BPA-1.8-Water-Cooling-Test5-Source.zip` người dùng gửi lại, 89,300,417 bytes, SHA-256 `aa2c75f270d97e3deb70be8f045ffe1fe82b64f01a789335fb4f9bccc88e0088`. Giải nén kiểm tra CRC toàn bộ 547 mục thành công. Không dựng Water từ main.

Nhánh cục bộ `feature/1.8-water-cooling-test6r`. Vì ZIP không chứa `.git`, commit `29884bf` giữ cây source được nhập lại; không giả lập lịch sử Git cũ `ccec7c2`. Sửa runtime tại `6fdfbe9`, cấu hình bản thử tại `37a12de`, giữ wrapper tại `12d2f17`. APK được build từ cây `12d2f17`. Các commit sau đó thêm test và tài liệu, không sửa runtime APK. Main không bị sửa, không merge hoặc publish.

## Thay đổi

- Khi trở lại từ nền, dừng đồng hồ mô phỏng cũ, bỏ gia tốc còn sót và chờ trọng lực mới. Khôi phục trạng thái cân bằng theo hướng mới trước khi hiện nước; fallback sau 200 ms khi không nhận được cảm biến.
- Native bridge xóa mẫu cũ lúc pause/start/cancel và không trừ trọng lực quá cũ thành cú lắc giả. Bộ lọc đầu vào chạy theo thời gian, độc lập nhịp callback.
- Khi đặt phẳng, diện tích dựa vào lượng nước, có hysteresis thay vì kéo mọi lượng nước lên 99% màn hình. 8% tạo footprint khoảng 24%, giảm độ dày tương ứng và giữ thể tích.
- Cohesion cục bộ giữ nước ít thành một puddle thay vì tản thành sương. Pressure, trao đổi động lượng và vorticity có giới hạn năng lượng vẫn cho sóng, tách/nhập giọt, nghiêng/lật/đặt ngang.
- Chi tiết quang học dịch chuyển bằng tích phân vận tốc thay vì lấy vận tốc làm vị trí UV, tránh ánh sáng nhảy khi đảo hướng. Màng nước mỏng có alpha premultiplied theo chiều sâu.
- Bỏ nút chỉnh Water khi đang ở theme khác. Giữ nút riêng khi Water đang dùng, trang chỉnh riêng, live preview, Lưu & Áp dụng và illumination VFX.
- Giữ nguyên font/layout Test5, ba renderer widget, ảnh cá nhân, Tiên Môn, các theme khác và pipeline login/sync/attendance/TH-LT/alarm/NFC/updater. Không thêm Parking.

## Kiểm thử Flutter và JS

Chạy lại đúng ZIP Test5 nguyên trạng: **177 qua, 14 lỗi**. Bản sửa cuối: **186 qua, 14 lỗi**, tập tên 14 lỗi giống hệt baseline. Suite không xanh hoàn toàn. Các lỗi kế thừa gồm notification/exam navigation, update dialog, font/theme notification/countdown và login fixture. Không dùng chúng để tuyên bố các chức năng đã được kiểm tra trên điện thoại thật.

Test mới kiểm tra nền → resume qua EventChannel Android mô phỏng và renderer GPU thật trên host; fresh gravity/fallback, bỏ cột cũ, lượng 8%/nằm phẳng, đổi aspect, nhiễu ngưỡng, lọc cảm biến và quang học liên tục. Giữ test lật 90/180°, lắc, tách/nhập và bảo toàn thể tích, hitbox, font thực, preview/draft/save/theme switch.

Bốn nhóm JS: inline sync retry, authenticated WebView reuse, TraCuu 7 tình huống và update-log contract đều qua.

Benchmark host (614 mẫu, 61×123 grid): trung vị solver 2.906 ms và dựng mặt 0.549 ms khi nghiêng; 2.814/0.673 ms khi phẳng. Đây là CPU host, không phải FPS/battery/CPU/GPU trên Android.

Test native chạy lại `:app:testDebugUnitTest -Ptarget-platform=android-arm64`: **71/71 qua**, 20 suites, gồm ba renderer và bốn kiểm tra lifecycle/fresh sample của bridge cảm biến.

## APK thử nghiệm

- Profile arm64, versionName `cooc.1.8-test6r`, versionCode 66.
- Package `vn.edu.phenikaa.better_phenikaa_schedule.waterrecovery.test6r`, cài riêng để tránh đụng dữ liệu/gói đã ký bằng khóa Test5 đã mất.
- Chứng thư SHA-256 `f9e54276086c2920cfad8edb76498ca9bfae6fa658525cbce859b46aa96ba9a1`.
- APK 124,013,087 bytes; SHA-256 `02ea29f8c5e12a7c828e366c40299345425e7fe1e29e401448fe9a59f27e28e0`.
- Đã kiểm CRC ZIP, arm64 AOT libapp/libflutter, shader đóng gói, chữ ký v2 và zipalign 16 KB. Không thay production signing hoặc updater feed.

Build bằng Flutter 3.47.2, Dart 3.13.2, JDK17, SDK37/36, NDK28.2.13676358, Gradle9.3.1, AGP9.1.1, Kotlin2.4.0. Dependency flutter_inappwebview_android 1.1.3 cần đổi cached `proguard-android.txt` thành `proguard-android-optimize.txt` như bootstrap hiện có; buildscript plugin trên host đồng bộ AGP9.1.1/Kotlin2.4.0. Cấu hình proxy/môi trường máy không được đưa vào source.

## Cần thử máy thật

Nghiêng/lắc/lật 180°/đặt ngang/phẳng ở 8% và mặc định; khóa màn hình, đổi hướng khi app ở nền rồi trở lại nhiều lần. Đo frame pacing/FPS, nhiệt, pin trên thiết bị. Kiểm launcher của ba widget và login/session/reload/thi/attendance/TH-LT/alarm/NFC/updater bằng dữ liệu thực. Không bảo đảm hết giật hoặc 60 FPS khi chưa có phép đo máy thật.
