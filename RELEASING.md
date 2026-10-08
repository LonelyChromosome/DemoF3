# Phát hành Better Phenikaa — Feature Updater

## Hiện tại

- APK **cooc.1.1 / versionCode 30** đã giao là bản nền.
- Bản đích nâng cấp thử nghiệm là **cooc.1.2 / versionCode 32**, kể cả khi không đổi tính năng.
- Các APK này chỉ cập nhật tại chỗ nếu **package ID** và **chứng chỉ ký APK** trùng nhau, versionCode tăng.
- Bản debug cũ không cùng khóa release sẽ **không thể** cập nhật tại chỗ; phải xử lý riêng, không hứa giữ dữ liệu.

## Cách phát hành từ nay

Workflow `.github/workflows/build-apk.yml` (**Feature Updater - signed APK release**) chỉ chạy **thủ công**:

1. Chọn commit phát hành trên `main`, nhập `cooc.X.Y` và versionCode mới.
2. Giữ `publish=false` để build **một APK ký release** và metadata ký Ed25519, chỉ lưu Actions artifact. Không có bước publish ngầm.
3. Sau khi kiểm tra trên máy, chạy lại cùng commit, bật `publish=true` và nhập `PUBLISH`. Job mới được phép đưa APK lên GitHub Releases và cập nhật signed manifest.
4. Duy trì `minimumVersionCode=30` và versionCode tăng để các máy cooc.1.1 có đường nâng cấp.

**Không đổi URL kênh** `feature/1.2-card-update/updates/latest.json`: đường dẫn này đã nhúng trong APK 1.1. Mã nguồn thuộc `main` và `feature/updater`, còn nhánh trên giữ vai trò update feed tương thích ngược.

Không tự cập nhật khi login/sync. Người dùng tự mở trang cập nhật bằng NFC hoặc tên hiển thị; cài đặt cuối vẫn do Android xác nhận.

Quy trình cụ thể và ghi chú về 1.2 đang được host: [docs/COOC_1_2_UPDATE.md](docs/COOC_1_2_UPDATE.md).

## Bảo mật và an toàn

- Không bao giờ commit/upload keystore, private Ed25519 key hoặc mật khẩu vào source/artifact/log.
- GitHub Environment `cooc-release` giữ các secrets ký. Thiếu khóa phải lỗi chứ không fallback debug.
- Kiểm SHA-256 APK, certificate fingerprint, package ID, versionCode và manifest signature trước khi publish.
- Không ghi đè GitHub Release tag đã phát hành, không hạ versionCode, không force push `main`.
- Đặt branch protection và manual approval cho phát hành nếu có thể.
- Mốc `backup/main-pre-feature-updater-20261008` là bản bảo toàn trước khi merge.
