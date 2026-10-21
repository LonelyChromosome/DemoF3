# BPA 1.9 — panel kiểm thử sự kiện
Branch này lấy trực tiếp từ `feature/bpa-vehicle-demo-1.9`, không sửa main.

**Trong app:** Phương Tiện > Bật Tìm xe của bạn > PANEL TEST SỰ KIỆN (mở rộng).

- **Vào cổng:** Giả lập sự kiện geofence/đến cổng, khởi động cùng Android foreground tracking service thật; bỏ qua ràng buộc ngày giờ trường chỉ trong thử nghiệm. Cần cấp Fine Location trước.
- **Bước chân:** Giả lập 7 bước trong khoảng 8 giây qua cùng thuật toán phát hiện xe đỗ. Điểm GPS vẫn lấy thật. Nếu thiếu điểm GPS chính xác thì không tự tạo tọa độ, không tự báo đỗ.
- **Chốt xe GPS:** Đánh dấu đỗ *thủ công để kiểm thử*, bằng cụm ít nhất 2 điểm GPS thật trong 15 giây, sai số <=30m, điểm cuối mới hơn 30 giây; không quảng bá như kết quả đoán đỗ tự động. Báo notification và mở màn tìm xe.
- **Reset:** Hiện xác nhận, xóa chỉ hành trình và tọa độ xe trong app demo, tắt service; không xóa dữ liệu BPA chính.

Panel chỉ bật bởi cờ biên dịch, phương thức native chỉ hoạt động trong app id hậu tố `.vehicle.demo19.events`. Bản demo cài riêng không ghi đè ứng dụng chính hoặc bản demo cũ. APK build ARM64 profile (để nhỏ hơn debug).
