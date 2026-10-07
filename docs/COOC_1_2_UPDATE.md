# cooc.1.1 → cooc.1.2

## Phạm vi

cooc.1.1 hiện tại (`versionCode 27`) chưa có updater. APK Public đã kiểm tra
(`SHA-256 50117bf7507a339bfdd9789171701aedf3c335e7214bcd7b7a6f0f759016f517`)
được ký bằng chứng chỉ **Android Debug** (`SHA-256 ad3b3b92c1376f2a2026b7fcdd6da41a7319d334c9dbf5a5378c58408382ab58`).
Vì vậy bản này **không thể** được cập nhật tại chỗ bằng APK ký bằng khóa release.
Nếu chưa có khóa release trước đây, tạo khóa release mới với alias
`cooc-release-v1`. Người đang cài APK debug code 27 cần gỡ/cài bản mới một lần;
việc này xóa dữ liệu cục bộ, bao gồm bind thẻ NFC. Không được hứa giữ nguyên dữ
liệu qua bước chuyển signer. **Bootstrap cooc.1.1 (`versionCode 28`)** là mốc
đầu của dòng ký release mới. Từ bootstrap,
Sync chỉ kiểm tra metadata; quét thẻ hoặc giữ nút thủ công 2 giây mới tải APK.
**cooc.1.2 (`versionCode 29`)** là APK riêng, ký cùng chứng chỉ Android.

## Chuỗi tin cậy

- App chứa khóa **công khai Ed25519** 32 byte dưới dạng base64, được đưa vào lúc
  build. `latest.json.sig` là base64 của chữ ký Ed25519 64 byte trên **chính xác
  các byte UTF-8** của `latest.json`, bao gồm dấu xuống dòng cuối. Không ký lại
  JSON sau khi đã thay đổi khoảng trắng, thứ tự khóa hoặc URL.
- `latest.json` chỉ có các trường `schema`, `packageName`, `versionCode`,
  `versionName`, `minimumVersionCode`, `apkUrl`, `apkSha256`, `apkSize`,
  `publishedAt`, `notes`. Công cụ phát hành xuất JSON UTF-8, sort key, compact,
  newline cuối. URL và notes chỉ được dùng sau xác minh chữ ký.
- APK tải qua HTTPS vào `cacheDir/app_update/candidate.apk`, không vào Downloads.
  Giới hạn kích thước từ manifest, kiểm SHA-256 của toàn bộ file. Android đọc
  archive package: phải đúng package ID, đúng versionCode đã ký và cao hơn bản
  đang cài, cùng tập chứng chỉ signer hiện tại với bản đang chạy. Sau đó mới
  commit PackageInstaller session. Android tự đưa ra xác nhận cài đặt.
- Sửa trang GitHub Pages hoặc thay APK khi không có **cả** khóa riêng Ed25519 và
  khóa ký APK chỉ có thể làm cập nhật lỗi/bị chặn. Không chấp nhận hash từ một
  trang chưa ký. Khóa riêng manifest và keystore Android có vai trò tách biệt.

## Thẻ và đường thủ công

Reader mode chỉ bật sau khi chọn “Cập nhật bằng thẻ”. UID lấy từ `Tag.id` theo
thứ tự byte Android trả về, viết hex in hoa không dấu phân cách. UID đầu tiên
được mã hóa AES-GCM bằng khóa không xuất được của Android Keystore, lưu trong
private SharedPreferences `update_bound_card`. UID không đi qua Flutter channel,
không nằm trong HTTP, manifest, log hay export. Thẻ sai báo “Không đúng thẻ”,
reader vẫn chờ thẻ đúng; không tải APK. Không có chức năng đổi/xóa UID trong app.
Android Clear data tương đương cài mới. `allowBackup=false` giữ dữ liệu này ngoài
backup. Đường thủ công yêu cầu giữ 2 giây rồi dùng nguyên luồng kiểm tra APK.

Nếu thiếu quyền “Cho phép từ nguồn này”, chỉ một lần **người dùng chủ động cập
nhật** mới mở màn hình cài đặt của Android. Từ chối quyền thì dừng; Sync/lần mở
app kế tiếp không nhắc. Lần chủ động cập nhật sau có thể mở lại cài đặt.

## Phát hành

1. Trên máy tin cậy, chạy `bash tool/create_release_keys.sh /đường/dẫn/riêng`
   với thư mục **ngoài repo**. Script tạo keystore Android alias
   `cooc-release-v1` và cặp Ed25519 độc lập, in ra fingerprint chứng chỉ và
   khóa công khai. Chọn mật khẩu ngẫu nhiên dài trong trình quản lý mật khẩu;
   không dùng alias làm mật khẩu. Sao lưu hai khóa riêng an toàn ở hai nơi.
   Đặt fingerprint release **mới** vào `EXPECTED_APK_CERT_SHA256`. Không dùng
   fingerprint debug của APK code 27.
2. Lưu PEM Ed25519 riêng dưới dạng base64 vào secret
   `UPDATE_MANIFEST_PRIVATE_KEY_BASE64` của GitHub Environment `cooc-release`.
   Lưu base64 của 32 byte khóa công khai vào variable `UPDATE_PUBLIC_KEY_BASE64`.
   Công việc build đối chiếu hai giá trị. Không gửi khóa riêng qua chat, không
   in giá trị secret vào log và không đưa khóa vào repo/artifact.
3. Đặt `COOC_KEYSTORE_BASE64`, `COOC_KEYSTORE_PASSWORD` trong Environment đó.
   Bật required reviewers và chỉ cho nhánh/tag phát hành được truy cập. Workflow
   chỉ chạy thủ công; push thông thường không nhận khóa. Không bật environment
   secrets trước khi cấu hình bảo vệ này.
4. Chạy workflow từ nhánh phát hành đã kiểm. Nó chạy test, build hai APK public
   tên riêng và code 28/29, xác minh hai fingerprint bằng nhau và bằng
   fingerprint release mới ở bước 1, tạo `dist/update-host/updates/latest.json`,
   `.sig` và APK 1.2. Không
   upload keystore hay private key làm artifact.
5. Công bố ba file trong `updates/` dưới
   `https://lonelychromosome.github.io/DemoF3/updates/` **sau** khi kiểm thử trên
   thiết bị thật. Giữ nguyên byte JSON đã ký. Không ghi đè APK 1.1 bằng 1.2.
6. Kiểm thử signed bootstrap 1.1 → 1.2, NFC đúng/sai, thủ công, từ chối quyền,
   sửa byte manifest và thay APK trên host. Xác nhận `versionCode 29`, fingerprint
   signer giữ nguyên, `cacheDir/app_update` được dọn sau khi cài.

Release phải thất bại nếu thiếu khóa, fingerprint release mới hoặc dùng chứng
chỉ debug. Mốc code 27 ký debug không thể cập nhật trực tiếp sang code 28 ký
release; hãy thông báo rõ bước cài mới trước khi phân phối.
