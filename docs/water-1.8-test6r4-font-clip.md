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
- Native chạy lại: **72/72 qua, 21 suites**, gồm widget renderer và fallback family cũ không tải asset đã gỡ. Chưa kiểm tra máy thật.

## Bản thử

Đã build profile arm64 Test6R4, versionCode 69, versionName `cooc.1.8-test6r4`; giữ package `.waterrecovery.test6r` và khóa Test6R để cài cập nhật giữ dữ liệu.

- Runtime commit GitHub `c2772142550dcb60018af1f95da2b39f5ccf76dc`, tree `df09c38736a72a69d4a3bc99d29d1a546632c3d5`. Local build commit `f601b08` có cùng tree.
- APK `BPA-1.8-Water-Cooling-Test6R4-arm64.apk`, 123,982,462 bytes.
- SHA-256 `58bd97a90d9036ac81e2f3b910c8b1dc45d79db1231f6403dc85dc05cc740e47`.
- Signer SHA-256 `f9e54276086c2920cfad8edb76498ca9bfae6fa658525cbce859b46aa96ba9a1`, khớp Test6R/6R2/6R3.
- Đã kiểm CRC mọi entry, libapp/libflutter arm64, shader, chữ ký v2, zipalign 16 KB và package/version thực bằng aapt.
- Kiểm trực tiếp ZIP APK: không có asset SVN Batman hoặc fixture WideDisplay; FontManifest không có family BatmanForever. Tên family chỉ còn dùng trong migration/fallback cấu hình cũ.
