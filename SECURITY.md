# Bảo mật

> T lười mở QLĐT mỗi ngày, chứ không lười bảo vệ tài khoản của người dùng.

Repo này chạm tới phiên đăng nhập và dữ liệu học tập cá nhân. Một dòng log tiện
tay có thể chứa thứ không bao giờ nên xuất hiện trên GitHub.

## Tuyệt đối không commit

- Mật khẩu Microsoft hoặc QLĐT.
- Access token, refresh token, cookie, Authorization header hoặc session dump.
- Keystore, signing key, `key.properties` hoặc mật khẩu ký APK.
- Database, cache, HTML hay screenshot lấy từ tài khoản thật.
- Tên, MSSV, email, lịch học, lịch thi hoặc QR có thể nhận diện người dùng.

Fixture và ảnh test phải dùng dữ liệu giả. Nếu cần tái hiện parser, phải xóa hoặc
thay toàn bộ định danh trước khi đưa file vào repo.

## Báo lỗ hổng

Không mở issue công khai nếu lỗi có thể làm lộ tài khoản, dữ liệu cá nhân, khóa
ký hoặc cho phép giả mạo bản phát hành. Hãy dùng Private vulnerability reporting trong mục Security của repository khi
tính năng đó được bật. Nếu chưa bật, chỉ mở issue đã che sạch dữ liệu để xin một
kênh liên hệ riêng. Nội dung báo cáo nên có:

- Commit hoặc phiên bản bị ảnh hưởng.
- Điều kiện và các bước tái hiện tối thiểu.
- Mức ảnh hưởng dự kiến.
- Bằng chứng đã được che dữ liệu nhạy cảm.

Đừng gửi credential thật để chứng minh rằng credential có thể bị lộ.

## Nguyên tắc xử lý

- App dùng luồng xác thực trên trang chính thức, không dựng form riêng để thu mật
  khẩu.
- Chỉ lưu lượng session tối thiểu cần thiết và xóa khi đăng xuất.
- Sync lỗi không được ghi đè snapshot hợp lệ.
- Ảnh và font của custom theme được xử lý trong vùng lưu trữ riêng của app.
- Bản chẩn đoán công khai phải tắt theo mặc định và dữ liệu xuất ra phải ẩn danh.

## Nếu dữ liệu đã lọt vào Git

Xóa file ở commit mới chưa đủ. Thu hồi credential hoặc phiên liên quan trước,
sau đó làm sạch lịch sử Git và kiểm tra lại toàn bộ nhánh/tag. Một bí mật đã
public thì cứ coi như nó đã hết bí mật.
