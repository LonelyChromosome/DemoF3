# BPA 1.9 Find My Bike — tự chờ, test và thực tế

- Tự đồng bộ giờ học và tên môn từ `data.classes` của BPA xuống native Android; không lấy lịch giờ cố định tự nhập.
- Trang Phương Tiện hiển thị `Các môn học đang được chờ`, dấu ✓ khi lịch đang khả dụng và chưa đỗ xe, ✕ khi chưa tới giờ/quá giờ/đã đỗ.
- Có lịch hợp lệ, native tự bật Find My Bike và xin quyền Android cần thiết. Nền Android vẫn cần người dùng cấp quyền "Vị trí mọi lúc" và "Hoạt động thể chất" và cho phép thông báo; không thể cấp hộ người dùng.
- Theo dõi thật: AlarmManager đánh thức gần lịch; geofence 100 m quanh hai cổng, nhập vùng khi lịch hợp lệ thì mở recording; thông báo số 1 vào phạm vi, dùng step detector và GPS để xác định đỗ rồi thông báo số 2. Mở vị trí xe ngay trong app dẫn bằng bản NorthUp.
- Đã đỗ thì khóa các lịch tiếp theo. RE-ARM chỉ khi Activity Recognition đủ tin cậy phát hiện IN_VEHICLE/ON_BICYCLE **và** GPS cho thấy ra khỏi cả hai geofence 100 m có tính cả sai số. Đi bộ ra khỏi khu vực không tự mở lại lịch. Android có thể trì hoãn nền.
- **TEST** dùng pref và file GPS riêng, notification có nhãn TEST; có nút Vào cổng / Bước chân / Chốt xe GPS / Reset, và dẫn tới xe TEST. Mặc định toàn bộ hệ thống dùng THỰC TẾ, test không ghi đè parked location thật. Không cho chạy test đồng thời khi tracking thật đang hoạt động.
- Xây dựng dưới ID `.vehicle.demo19.events`, không chỉnh `main`, không đè dữ liệu bản BPA chính.
- APK ARM64 PROFILE dùng kiểm thử, không phải bản phát hành chính thức.
