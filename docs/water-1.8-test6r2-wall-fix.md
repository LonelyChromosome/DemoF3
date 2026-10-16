# Water Cooling Test6R2 — áp suất sát thành bể

Tiếp tục đúng cây Test6R từ ZIP Test5; nhánh GitHub `feature/1.8-water-cooling-test6r`, parent `636b5cc67c7e6777560a8195c8250fa72df04eff`. Commit parent này có cây source khớp Test6R đã giao (`dd61e170dbcb818b0d10ae7811e1ddaa27d6cebc`). Main không đổi, không merge/publish.

## Sửa vật lý

Solver trước chỉ chặn tọa độ ở thành. Kernel thiếu lân cận phía ngoài acrylic cho phép nước dồn quá đặc tại mép, rồi projection đẩy mẫu thành tia. Nay dùng mật độ và gradient của lớp mẫu solid ảo ở cả bốn thành để tính phản lực áp suất ngay trong các lượt giải. Bảng tích phân kernel được tạo một lần, các mảng tái sử dụng. Không thêm/xóa mẫu nước, không cắt cột bằng mask, không kéo nước về một hình dạng giả.

Thêm tiêu tán vận tốc tiếp tuyến theo khoảng cách đến thành, đồng thời giới hạn vận tốc **sau** pressure/vorticity. Giới hạn trước projection vẫn giữ; bản cũ có thể vượt giới hạn sau projection. Giữ gravity scale cũ: thử tăng gravity làm nước rút nhanh nhưng tăng rung lúc đứng yên nên không đưa vào bản này.

Giữ nguyên sensor/lifecycle Test6R, sóng/tách giọt, lượng nước/nằm phẳng, shader acrylic, ARGB/VFX, theme/font/layout, ba widget, ảnh và các chức năng nền. Không thêm Parking. Mô phỏng vẫn là xấp xỉ 2D phục vụ UI, không phải bảo đảm mô hình nước thực tuyệt đối.

## Kiểm thử host

- Toàn bộ Flutter: **190 qua, 14 lỗi**; tập tên 14 lỗi giống Test6R và ZIP Test5, không có lỗi mới. Danh sách lỗi kế thừa ở `water-1.8-test6r-recovery.md`.
- Bốn regression mới: lắc/lật rồi dựng máy ở viscosity 0.22 và 1.0, giới hạn vận tốc sau va chạm, renderer GPU thật khi nước rút khỏi thành. Kiểm cả mặt nước và thể tích thay vì chỉ đếm mẫu hữu hạn.
- Kịch bản lắc/lật tại 32%: sau một giây dựng lại, không quá ba mẫu rời ở thành phía trên nửa màn hình; sau ổn định mặt nước về đáy, diện tích 30–34%, khối lượng không đổi. Không cấm giọt rơi hay sóng dâng thoáng qua sau va chạm.
- Render và xem chuỗi frame thực của WaterStage qua nghiêng 90°, lật 180°, nằm phẳng và dựng lại. Unit test không phải chứng minh cảm giác/FPS trên Samsung.
- Benchmark host 614 mẫu, grid 61×123: solver trung vị 3.238 ms, surface 0.551 ms khi nghiêng; 3.149/0.718 ms khi phẳng. Test6R trước là 2.906/0.549 và 2.814/0.673 ms. Đây là CPU host, chưa đo frame pacing/FPS/pin trên Android.
- Native code không thay đổi; lần chạy Test6R trước đạt 71/71. Không ghi nhận đó là một lần chạy native mới cho Test6R2.

## Bản thử

VersionCode 67, versionName dự kiến `cooc.1.8-test6r2`, label `BPA Water Cooling Test6R2`. **Giữ package `.waterrecovery.test6r` và khóa Test6R**, để cập nhật đè Test6R mà giữ dữ liệu. Production signing/updater không thay đổi. Kết quả build và SHA-256 sẽ ghi sau khi kiểm tra artifact.

Cần thử máy thật: nghiêng sang từng bên rồi dựng lại, lắc nhẹ/mạnh, lật 180°, đặt ngang/phẳng ở lượng 8%/32%, khóa màn hình hoặc đổi hướng khi app ở nền rồi trở lại. Kiểm xem cột sát thành còn đứng lâu khi máy đã ổn định, đồng thời đánh giá độ mượt/nhiệt/pin.
