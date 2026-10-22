# Find Bike (beta) · BPA 1.9

Giao diện Xe cộ lấy từ commit `551d830cd5f19ff78d0e453c6d1dc2f4dfd1b46f`. Không có panel giả lập trong app chính.

- `vehicle_page.dart`: trạng thái, hàng chờ thu gọn, reset có xác nhận, mở tìm xe.
- `vehicle_navigation.dart`: scan-lock và chỉ đường theo GPS thật.
- `vehicle_native.dart`: contract MethodChannel `better_phenikaa/vehicle`.
- `vehicle_schedule.dart`: chỉ chiếu lịch học sang cửa sổ thời gian; không sửa dữ liệu nguồn.
- Android `:findbike` (`android/findbike/`): thư viện riêng chứa dữ liệu xe, vòng đời, geofence, GPS/step service, notification listener và manifest riêng. Không phụ thuộc `:app`, Flutter, QLĐT, attendance, widgets hay theme.
- Adapter Flutter mỏng nằm ở `android/app/.../findbike/VehicleBridge.kt`; MainActivity chỉ nối khởi tạo/quyền/vòng đời.

Cache lịch không tự bật quyền GPS. Người dùng chọn bật Find Bike; GPS nền và quyền nhận thông báo ra cổng cần được Android cho phép. Khi đã đỗ, không tiếp tục GPS/motion polling. Reset chỉ xóa trạng thái xe/điểm đỗ/trace, không sửa lịch hoặc chuyên cần. Các key lưu trữ cũ được giữ nguyên.

Sửa lỗi native: `cd android && ./gradlew :findbike:testDebugUnitTest`; kiểm tra UI/contract: `flutter test test/vehicle_module_test.dart`. CI KDA có kiểm tra bridge native thật cùng KDA. GPS ngoài trời, thông báo từ Phenikaa Uni thật, độ chính xác và pin cần thử trên thiết bị thật; không suy ra từ emulator.
