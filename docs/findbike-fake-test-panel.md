# BPA 1.9 — Panel FAKE vòng chờ Find My Bike

## Hai chế độ độc lập

**FAKE 100%** tạo dữ liệu mô phỏng trong `bpa_vehicle_fake_v3`, đồng hồ ảo, ba môn học trực tiếp + một môn eLearning. Không cấp GPS cũng có thể bấm thử. Không ghi tọa độ, không đụng `VehicleStore` REAL hoặc `VehicleStore` TEST GPS và không thay đổi lịch QLĐT.

**TEST CẢM BIẾN · GPS THẬT** giữ lại panel cũ: Vào cổng → Bước chân → Chốt xe GPS → Xe ra cổng [TEST] → Reset; GPS test có không gian lưu độc lập với xe thật. Hai nhóm có nhãn rõ trong UI.

## Các nút FAKE

- **Vào phạm vi**: chỉ bấm được khi có môn khả dụng trong WAITING, tạo thông báo `[FAKE TEST] Xe vào phạm vi`.
- **Đã đỗ xe**: TRACKING → PARKED, tạo thông báo `[FAKE TEST] Đã xác định vị trí xe`. Các môn còn lại hiển thị ✕ (khóa).
- **Xe ra cổng**: chỉ khi PARKED, tạo thông báo `[FAKE TEST] Xe ra cổng`, xóa môn của lượt cũ và mở chờ môn sau.
- **Hết giờ, chưa đỗ**: giả lập thời gian kết thúc buổi đang chờ/tracking, tự loại môn chưa phát hiện đỗ, không ảnh hưởng điểm danh.
- **Môn tiếp theo**: đổi **đồng hồ ảo** để đưa giờ môn kế vào vùng chờ, không đổi giờ máy thật.
- **Đặt lại toàn bộ FAKE**: reset dữ liệu mô phỏng từ đầu, không chạm dữ liệu thật.

Hàng chờ FAKE có dấu ✓/✕ và trạng thái theo đồng hồ giả. eLearning hiển thị riêng dưới danh sách với nhãn *không vào hàng chờ*. Nhật ký ghi rõ mọi sự kiện.

## Kiểm thử

1. Reset → môn A ✓, B/C ✕, eLearning ở dòng loại trừ.
2. Vào phạm vi → TRACKING; Đã đỗ → PARKED và B/C ✕.
3. Xe ra cổng → WAITING, A biến mất; Môn tiếp theo → B khả dụng.
4. Reset → Hết giờ, chưa đỗ → A biến mất, B chờ; không sửa thông tin điểm danh.
5. Khi đang dùng FAKE, real parked/route không thay đổi; ba thông báo fake đều có tiền tố [FAKE TEST].

**Chỉ có trong bản APK test** với application ID `vn.edu.phenikaa.better_phenikaa_schedule.vehicle.demo19.events`. Bản chính thức không có nút gọi vào bộ FAKE. Đây là xác nhận luồng UI/event, không thay thế đo GPS ngoài thực địa.
