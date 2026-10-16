# BPA 1.8 — chuẩn bị phát hành

Người dùng đã xác nhận merge main và publish. Nền đã thử là Test6R4, commit `595da6a`; main trước merge `8e6d1064f90dd9c2b252e3c5a865289c3ba25eba`.

- VersionName `cooc.1.8`, versionCode **70** (kênh chính 1.7 hiện là 57, Test6R4 riêng là 69).
- Update log trong Notification Center và release notes: **Theme Premium 2: Water Cooling**. Startup cũng dùng log 1.8 trước khi nhận PackageInfo; log cho bản cài 1.6/1.7 vẫn giữ riêng.
- Giữ package production `vn.edu.phenikaa.better_phenikaa_schedule`. Chỉ workflow protected hiện có được dùng để ký bằng khóa production cũ và ký manifest; không phát hành APK debug/profile của các bản thử lên updater.
- Workflow `build-apk.yml`, dữ liệu feed hiện tại, QLĐT/parser/session, core/sync và logic updater không bị thay đổi. Feed mới chỉ được workflow ghi sau khi APK ký, checksum, package/version/cert đã xác minh.
- Khôi phục executable bit của `tool/bootstrap.sh` và `tool/quality.sh` đúng như main, không sửa nội dung script.

## Kiểm tra trước merge

- Chạy lại toàn bộ Flutter sau khi cập nhật log: **199 qua, 10 lỗi kế thừa**, không có lỗi mới so với Test6R4 (195 qua/14 lỗi). Log ngắn 1.8 làm bốn kiểm tra Notification Center hết lỗi overflow. Các lỗi còn lại đã có trong ZIP Test5/Test6R4: empty Notification Center, Minecraft/Valorant/countdown/custom font layout, manual-update fixture và login/legacy DB fixture. Không gọi suite này là xanh hoàn toàn.
- Native của Test6R4: **72/72 qua**; chuẩn bị release không sửa native runtime ngoài fallback tên phiên bản Gradle. Bản chính thức vẫn cần workflow build/verify ký thật.
- Bốn nhóm JS sync retry, retained WebView, TraCuu (7 tình huống) và notification changelog đều qua.
- Đã chạy `bash tool/quality.sh` trên bản sao riêng để formatter không ghi đè cây source đã thử. Analyze có 20 warning và 588 info, không có error; script exit 1 vì các lint này nên không đi tới bước test. Toàn bộ test được chạy riêng như trên. Không merge thay đổi format toàn repo.
- APK Test6R4 đã kiểm thực sự tồn tại/chữ ký/CRC/shader/asset font và có bản giao cho người dùng. Main merge không tự publish; phải chạy workflow chính thức với publish=true và PUBLISH sau merge theo yêu cầu người dùng.

Sau workflow, cần đối chiếu release APK production với signed manifest, versionCode 70, signer production, và kiểm tra feed main lẫn URL tương thích cũ cùng trỏ bản 1.8.
