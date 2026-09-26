# DemoF3 TraCuu Inspector

Extension Chrome cục bộ để tìm lời gọi QLĐT sau khi JavaScript của trang đã xử lý `Data.B`. Không thay đổi trang hoặc tự gửi request đăng ký.

1. Vào `chrome://extensions`, bật Developer mode và chọn **Load unpacked** với thư mục này.
2. Mở QLĐT bằng Chrome, đăng nhập như bình thường và vào TraCuu.
3. **Tải lại tab TraCuu** sau khi cài extension, đợi học kỳ/kế hoạch/môn xuất hiện, rồi bấm **Xem** một lần.
4. Bấm biểu tượng **DemoF3 TraCuu Inspector** → **Tải capture TraCuu**.
5. Kiểm tra file JSON trong Downloads rồi gửi file đó. Nếu `hookReady` là `false` hoặc `records` trống, tải lại TraCuu và thử lại.

File chỉ lưu cục bộ. Nó chứa tên hàm, action, tên trường, kiểu/cấu trúc dữ liệu, mã giả ổn định cho tên môn/lớp và mã nguồn tĩnh `tracuu.js` nếu tải được. Mật khẩu, cookie, token, Authorization và định danh sinh viên không được thu; nội dung tự do được thay bằng độ dài. Extension không đẩy dữ liệu tới máy chủ. Hãy kiểm tra file trước khi gửi vì website có thể thay đổi tên trường.

Capture có tối đa 120 lời gọi, tám phần tử mẫu mỗi danh sách, 100 trường mỗi object và 300.000 ký tự của `tracuu.js`. Nếu callback vẫn chứa `Data.B` mã hóa, file vẫn ghi nhận cấu trúc đó và mã nguồn script để xác định bước giải mã còn thiếu. Không dùng capture giả lập làm bằng chứng endpoint thực tế.
