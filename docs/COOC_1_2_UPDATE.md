# Feature Updater — Better Phenikaa

## Nền phiên bản được giữ nguyên

- **cooc.1.1**, `versionCode=30`: APK đã gửi cho người dùng là bản nền.
- **cooc.1.2**, `versionCode=32`: bản đích cập nhật để kiểm chứng luồng nâng cấp 1.1 → 1.2, có thể cùng chức năng với 1.1.
- APK đã cài chỉ được cập nhật khi `versionCode` của bản đích **lớn hơn** bản trên thiết bị, package ID và APK signer phải trùng.
- Dòng ký release hiện tại sử dụng alias `cooc-release-v2`. **Không thay keystore**. APK debug cũ khác signer không thể nâng cấp tại chỗ sang dòng release này.

## Bất biến của kênh cập nhật

- Các APK 1.1 hiện hữu đã nhúng URL manifest
  `https://raw.githubusercontent.com/LonelyChromosome/DemoF3/feature/1.2-card-update/updates/latest.json`.
- Nhánh `feature/1.2-card-update` vì vậy vẫn là **kênh cung cấp metadata**, dù mã nguồn được merge vào `main`. Không đổi URL hoặc xóa nhánh này; không trỏ máy đã cài sang `main` bằng cách sửa tài liệu.
- `latest.json.sig` là chữ ký Ed25519 của **chính xác** bytes UTF-8 `latest.json`. App xác minh chữ ký trước khi đọc metadata, xác minh SHA-256 và package/signature của APK trước khi gọi trình cài đặt Android.
- Không tự kiểm tra cập nhật khi đăng nhập/đồng bộ. Người dùng mở **Tài khoản → Cập nhật ứng dụng** để kiểm tra và chủ động cập nhật bằng thẻ NFC hoặc nhập tên rồi giữ 2 giây.
- Sau khi bắt đầu tải, việc tải có thể tiếp tục ở nền; trình cài đặt Android vẫn yêu cầu người dùng xác nhận. Thành công thì thông báo.
- Khi người dùng bỏ trình cài đặt và trở về app, ReaderMode NFC thụ động tránh dispatch thẻ sang ứng dụng khác; không tự bắt đầu lượt cập nhật.

## Phát hành các bản sau (không tự động khi merge)

Workflow **Feature Updater - signed APK release** tại `.github/workflows/build-apk.yml` là `workflow_dispatch` (chạy thủ công). Merge hoặc push `main` **không build hay publish APK**.

1. Chọn commit trên `main` đã xác nhận để phát hành. Nhập `version_name` và `version_code` lớn hơn bản đã cài. Với bước 1.1 → 1.2: `cooc.1.2`, code `32`; với bản sau dùng code **lớn hơn** bản cao nhất đã phát hành.
2. Chạy với `publish=false`: build **một APK**, ký bằng đúng keystore cooc, kiểm signer/package/version, tạo metadata và chữ ký, chỉ đưa vào **Actions artifacts**, chưa công bố.
3. Kiểm tra APK thực tế. Sau khi duyệt mới chạy lại với `publish=true`, gõ `PUBLISH`. Workflow tạo một GitHub Release có tag duy nhất và cập nhật **đúng** `updates/latest.json` + `.sig` trên nhánh kênh cũ. Không ghi đè phiên bản APK trước.
4. Mỗi lần phát hành phải bảo đảm `versionCode` không giảm, signer không đổi, `minimumVersionCode=30` để máy 1.1 vẫn đủ điều kiện nâng cấp.

### Lưu ý quan trọng về 1.2 đã thử nghiệm

Manifest hiện tại vẫn trỏ tới bản `cooc.1.2` (code 32) đã phát hành trước các sửa lỗi Unicode/UI/NFC cuối cùng cho APK 1.1. **Muốn 1.2 có cùng fix với bản 1.1 đã giao**, phải build **lại target 1.2 từ commit sau fix**, thử và phát hành manifest ký mới (tag không trùng bản cũ). Merge code vào `main` **không tự thay APK 1.2 đang tải về**.

## Mốc khôi phục

- `backup/main-pre-feature-updater-20261008` giữ nguyên `main` cũ tại `a9e8d1c2281b5906eea8f980bbf31f3345de8163`.
- `feature/updater` là nhánh làm việc của tính năng; `main` là nguồn mã chính sau merge. Không force-push `main` hoặc rewrite history.
