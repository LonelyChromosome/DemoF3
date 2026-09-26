# DemoF3 QLĐT Schedule Diagnostic

Extension Chrome cục bộ để so sánh API lịch cá nhân trên trang QLĐT với timeout trong app. Phép thử gọi đúng hàm, action, khoảng ngày và tham số như app; chỉ đọc dữ liệu.

1. Giải nén ZIP. Mở `chrome://extensions`, bật **Developer mode**, chọn **Load unpacked** và trỏ vào thư mục có `manifest.json`.
2. Mở `https://qldtbeta.phenikaa-uni.edu.vn/`, đăng nhập, **tải lại tab** và đợi trang hiện.
3. Bấm biểu tượng **DemoF3 QLĐT Schedule Diagnostic** → **Kiểm tra và tải chẩn đoán**. Chờ tối đa 25 giây.
4. Mở file JSON được tải về, kiểm tra rồi gửi file đó.

Nút **Đo tốc độ lấy 7 ngày đầu** gửi một yêu cầu khác với cùng API, chỉ lấy
7 ngày kể từ hôm nay. Dùng nó để xem thời gian phản hồi có giảm khi hỏi ít
ngày hơn. Kết quả vẫn không chứa nội dung lịch; không dùng 7 ngày làm dữ liệu
thay thế cho lịch cả năm trong app khi chưa hoàn tất xác minh học kỳ.

Nếu `result.phase` là `success`, API hoạt động trong Chrome và cần kiểm tra WebView/bridge của app. Nếu `timeout`, cùng API không trả callback ngay trong Chrome. Nếu `not_ready`, trang chưa có phiên QLĐT đủ dùng; thử tải lại hoặc đăng nhập lại.

File chỉ chứa cờ sẵn sàng, loại kết quả, thời gian, tên trường và số phần tử. Không có nội dung lịch, ID sinh viên, cookie, token, password, URL có query, response thô hay bản chụp HTML. Không tự gửi dữ liệu ra ngoài. Do trang có thể đổi, hãy xem JSON trước khi chia sẻ.
