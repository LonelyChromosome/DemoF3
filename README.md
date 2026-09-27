# Better Phenikaa

> T quá lười để ngày nào cũng mở QLĐT, đăng nhập, bấm qua vài màn hình chỉ để
> xem hôm nay học gì. Thế là t làm hẳn một app để khỏi phải làm chuyện đó nữa.

Lịch học, lịch thi và những thứ cần nhớ được kéo ra ngay màn hình chính. Mở máy
là thấy, cần thì đồng bộ, sắp thi thì được nhắc. Ý tưởng bắt đầu từ sự lười biếng;
phần còn lại được làm bằng sự khó tính với từng cái widget.

> [!IMPORTANT]
> **Better Phenikaa là dự án độc lập do sinh viên phát triển. Đây không phải ứng
> dụng chính thức của Trường Đại học Phenikaa; dự án không được nhà trường tài
> trợ, xác nhận, quản lý hoặc đại diện.**

Tên Phenikaa chỉ được dùng để mô tả đối tượng mà ứng dụng hỗ trợ. Các tên và dấu
hiệu thuộc Trường Đại học Phenikaa vẫn thuộc chủ thể quyền tương ứng.

## App làm được gì?

- Đăng nhập QLĐT/Microsoft trong WebView và đồng bộ lịch.
- Lưu snapshot cục bộ; một lần sync lỗi không được quyền xóa dữ liệu tốt đang có.
- Hiển thị lịch học, lịch thi theo ngày và tuần.
- Đưa lịch ra widget nhỏ và widget tổng quan 4×2.
- Làm mới widget khi dữ liệu, ngày hoặc trạng thái đồng bộ thay đổi.
- Giữ 10 preset theme và cho tạo theme riêng từ ảnh hoặc bảng màu.
- Cho chọn font hệ thống, font tích hợp hoặc nhập TTF/OTF từ máy.
- Nhắc lịch thi và nhắc khi dữ liệu đã lâu chưa được đồng bộ.

Nói ngắn gọn: **t lười mở QLĐT, nhưng app thì không được phép làm việc lười.**

## Cấu trúc

Code được chia theo tính năng, không chia theo tên người:

- `lib/features/dang_nhap_qldt/`
- `lib/features/dong_bo_hang_ngay/`
- `lib/features/tien_ich_lich_hoc/`
- `lib/features/giao_dien/`
- `lib/features/lich_hoc/`
- `lib/features/tro_li/`

Chi tiết kỹ thuật nằm tại [`lib/features/README.md`](lib/features/README.md).

## Dữ liệu và quyền riêng tư

- Ảnh, wallpaper, screenshot và font được xử lý trên thiết bị.
- App không có analytics, tracker hoặc backend để thu thập theme cá nhân.
- Không log mật khẩu, cookie, token hay dữ liệu đăng nhập QLĐT.
- Credential, session thật, keystore và database người dùng không được phép xuất
  hiện trong repo.
- Đồng bộ lỗi phải giữ lại dữ liệu hợp lệ gần nhất.

Đọc [`PRIVACY.md`](PRIVACY.md) và [`SECURITY.md`](SECURITY.md) trước khi gửi log,
capture hoặc báo lỗi. Đừng biến một bug nhỏ thành một vụ lộ tài khoản to.

## Build

Yêu cầu Flutter 3.47.2, Dart 3.13, JDK 17 và Android SDK phù hợp.

```bash
bash tool/bootstrap.sh
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
flutter build apk --release
```

CI chạy lại định dạng, phân tích tĩnh, Flutter test, mô phỏng TraCuu, native
Android test và build APK. Test qua là điều kiện cần; launcher ngoài đời vẫn có
quyền nghĩ ra những cách phá widget mà test chưa từng mơ tới.

## Bản chính thức và bản fork

Source được phát hành theo **GNU GPL v3.0 only**. M được quyền đọc, sửa và phân
phối theo các điều kiện trong [`LICENSE`](LICENSE). Bản sửa đổi phải được đánh
dấu rõ và khi phân phối phải cung cấp source tương ứng theo GPLv3.

Giấy phép source không cấp quyền giả làm bản chính thức. Fork công khai phải đổi
tên, package ID, icon và nhận diện để người dùng không nhầm. Xem
[`TRADEMARK.md`](TRADEMARK.md) và [`NOTICE`](NOTICE).

APK do CI tạo hiện là **bản kiểm thử**, không phải bằng chứng nhận diện bản phát
hành. Khi phát hành công khai, bản chính thức phải được repo này công bố, ký bằng
khóa phát hành riêng và đi kèm checksum. Không có đủ ba thứ đó thì cứ coi là bản
không xác minh được, dù tên file có kêu đến đâu.

Quy trình chuẩn bị khóa và release nằm tại [`RELEASING.md`](RELEASING.md).

## Đóng góp

Đọc [`CONTRIBUTING.md`](CONTRIBUTING.md). PR được hoan nghênh, miễn là giải quyết
được vấn đề thật, không mang dữ liệu thật vào repo và không sửa thứ đang chạy ổn
chỉ vì nhìn nó chưa đủ “enterprise”.

## Một câu cuối

**Sinh ra từ sự lười biếng. Vận hành bằng sự ám ảnh rằng mọi thứ phải chạy đúng.**
