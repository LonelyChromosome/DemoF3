# Test6R3 — giữ bố cục card, co chữ theo font được chọn

Yêu cầu: chỉ tối ưu chữ, không thay bố cục card và không ép mọi font về cùng một cỡ nhỏ.

- Bỏ `_WaterStudyContent` đã đưa tên môn lên toàn chiều ngang và tag vắng xuống một dòng riêng. Trở về cấu trúc card cũ: giờ bên trái; tên môn và thông tin bên phải; tag TH/vắng cùng dòng phòng. Giữ nguyên vị trí và hitbox báo thức 44×44 (right 21, top 43), không sửa điều kiện mở/đặt/hủy.
- Bỏ ép metadata của Water sang Roboto. Mọi chữ trong card kế thừa font đang chọn.
- Bỏ trần 14 áp chung trong `WaterFitText`. Lấy cỡ gốc của từng label và đo glyph, line height, text scaler thực của font đó. Nếu vừa thì giữ đúng cỡ gốc; chỉ label tràn mới được giảm. Chọn phương án một/hai dòng có cỡ đọc lớn nhất trong vùng được cấp.
- Vùng tên môn trong card cũ kết thúc trước hitbox báo thức. Một tên dài hoặc font rộng tự thu trong vùng đó; không đẩy cấu trúc xuống hoặc sang cột khác để lấy thêm chỗ.
- Tag chỉ giới hạn glyph khi font rộng/cỡ hệ thống lớn; padding/viền và dòng phòng giữ nguyên. Các caller/theme khác không truyền giới hạn nên giữ hành vi cũ.
- Giữ nguyên engine nước Test6R2, các VFX, theme/settings, ba widget, ảnh, đăng nhập/đồng bộ/updater/signing production. Không đụng main.

## Kiểm tra

Chạy renderer app với font Roboto thật và font Batman thật, portrait 360×800/landscape 800×360, text scaler 1× và 1.4×. Assert vị trí tên môn phía phải giờ, tag cùng dòng phòng, chữ không đè hitbox báo thức; kiểm font thực trong RenderParagraph, không chỉ tên cấu hình. Đã xem ảnh render cả hai font. Room dài có thể ellipsis trong dòng cũ thay vì đổi bố cục để giữ toàn chuỗi.

Regression riêng đo cùng nhãn bằng hai font: khi Roboto vừa vùng thì giữ đúng 16; Batman rộng hơn mới giảm; cả hai đều giữ 16 khi vùng đủ rộng. Giữ nguyên family đã chọn.

Toàn bộ Flutter: **192 qua, 14 lỗi kế thừa**, tập tên lỗi giống Test6R2/Test5, không có lỗi mới. Lần chạy native Test6R trước đạt 71/71; không coi đó là native test mới cho bản này. Chưa kiểm tra font/launcher trên điện thoại thật.

## APK thử nghiệm

Đã build profile arm64, versionCode 68, versionName `cooc.1.8-test6r3`, label `BPA Water Cooling Test6R3`; giữ package `.waterrecovery.test6r` và khóa Test6R để cài cập nhật giữ dữ liệu.

- Runtime commit GitHub `71b58437ebded28e6190dbfc16ab7e869bdf5d64`, tree `21169e26af6e3561b6b7d3e0089eb155f30b3fa6`. Local build commit `2bc8e83` có cùng tree.
- APK `BPA-1.8-Water-Cooling-Test6R3-arm64.apk`, 124,013,087 bytes.
- SHA-256 `1cff3d16f61e2caaf536d0d41a600ebc8a667db9571986480f092d49e0b2de83`.
- Chữ ký SHA-256 `f9e54276086c2920cfad8edb76498ca9bfae6fa658525cbce859b46aa96ba9a1`, khớp Test6R/6R2.
- Đã kiểm CRC mọi entry, arm64 AOT/shader, chữ ký v2, zipalign 16 KB và package/version thực bằng aapt. Không đổi production signing hoặc feed updater.
