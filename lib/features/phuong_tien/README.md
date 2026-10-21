# BPA 1.9 · Phương Tiện DEMO

Branch-only development. **No main merge, production update feed, signed release or publish**.

UI:
- Six-item BPA theme menu (new "Phương Tiện" item) and normal page fade.
- Initial "Bật Tìm xe của bạn". Android permissions requested only when enabled.
- Four clean cards: Trạng thái; Xe đã dừng; Xem lộ trình di chuyển; Vị trí đỗ xe của tôi.
- Trace painted on a white north-up plane using actual stored local GPS points. No test/demo route injected.
- Opening the parked vehicle card starts real navigation GPS immediately, then a white 3.92-second one-at-a-time square scan/fade/hard lock VFX, then the standalone white NorthUp guidance. No manual START action.
- Navigation can fall back to cached location (age at most 20 minutes, accuracy at most 350 m) when indoors. Cache is indicated as approximate, never claimed to be fresh. Live reading continues automatically.
- Android parked point captured by separate foreground location service (gates 100 m, class window, location fixes, step detector). Only parked-success event notification; Android-mandated ongoing foreground-service notification cannot be hidden.
- Work limited to vehicle-specific classes and minimal additive menu/manifest/channel changes.
- APP_ID suffix .vehicle.demo19; its internal GPS, route and parking data are isolated from installed BPA or the old Find Bike APK.

Limitations for real-world validation before main integration:
- Android geofencing and background foreground-service launches depend on "Allow all the time" location access, which requires a one-time user action in Android application Settings on modern Android.
- 10s walking/candidate inference follows the tested intent but is a new native reimplementation, not binary-identical to Find Bike 1.5; test on real device before making it production.
- Stage notifications hidden from the app, but tracking foreground service notification remains due Android restrictions.
- For a later real update, user vehicle data would be owned by the BPA production package; this separate debug package does not import it automatically.
