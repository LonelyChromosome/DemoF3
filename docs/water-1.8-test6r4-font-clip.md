# Test6R4 — bỏ font SVN có sẵn, chặn chữ vẽ vào viền lịch tuần

Tiếp tục nhánh `feature/1.8-water-cooling-test6r` từ `63d10d1`. Không đổi main/publish.

- Bỏ SVN Batman Forever khỏi danh sách font có sẵn và khai báo font/asset production. Lựa chọn Water cũ tự về hệ thống; dữ liệu custom/Tiên Môn cũ chọn bundled face này cũng về hệ thống. Font do người dùng tự nhập được giữ nguyên.
- Native widget nhận family cũ dùng Typeface.DEFAULT, không tải asset đã gỡ. Các font khác và cách nạp file người dùng không đổi.
- Giữ fixture chữ rộng trong thư mục `test/fixtures` với tên kiểm thử; không khai báo trong assets/fonts và không đóng gói vào APK. Các bài kiểm tra app dùng font Minecraft có sẵn thay cho lựa chọn đã bỏ.
- Chế độ tuần Water có lớp clip nội dung phía trong viền acrylic. Đây là giới hạn paint/hit-test trong lòng chamber, không thêm padding layout: cột ngày 79, card 135 và phép cuộn vẫn giữ nguyên. Chữ của card đang cuộn qua mép không còn vẽ vào phần viền ống.
- Không sửa day card, font fitting Test6R3, physics/VFX, widget layout, dữ liệu/đồng bộ/updater hay signing production.

## Kiểm thử

- Regression dùng renderer lịch tuần thật và font Roboto thật, cuộn ngang qua 5 offset, đọc pixel vùng viền. Bản trước sửa có 9 pixel chữ sáng trong vùng viền ngay tại offset 0 và test thất bại; bản sửa không còn pixel chữ sáng tại vùng đó ở cả 5 offset, chữ bên trong vẫn hiển thị.
- Kiểm tra font cũ fallback mà giữ mode/fill, và giữ font người dùng nhập ngay cả cùng family name. Kiểm layout/font với hệ thống và Minecraft, ngày/tuần, preview/theme/lifecycle hiện có.
- Toàn bộ Flutter: **195 qua, 14 lỗi kế thừa**, tập lỗi giống Test6R3/Test5, không có lỗi mới. Suite không xanh hoàn toàn.
- Native và APK sẽ được ghi kết quả sau khi chạy và xác minh artifact. Chưa kiểm tra máy thật.

## Bản thử

Test6R4, versionCode 69; giữ package `.waterrecovery.test6r` và khóa Test6R để cài cập nhật giữ dữ liệu. Kiểm APK phải xác nhận asset và family bundled SVN không còn đóng gói.
