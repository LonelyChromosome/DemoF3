# Find My Bike REAL 1.5 integrated field test

**Build from source with Gradle, install APK.** Separate application id to preserve REAL 1.4 installation. Combines the two REAL 1.4 entrance reference coordinates extracted from APK, 100m Play Services geofence monitoring, gate-distance verification, vehicle-stop / step detector walking confirmation, auto-persisted bike coordinates, and the separate REAL 1.5 plain-white polling-line navigation UI.

Entrances extracted from REAL 1.4 APK:
1. `20.962668790883644, 105.74871859259113`
2. `20.959607109088672, 105.74789745697416`

Flow: tap **BẬT TỰ ĐỘNG** -> grant precise location, activity recognition and background/always location as requested -> geofences register at entrance locations 100m -> approach gate and get actual GNSS within 35m -> track movement (confirmed speed >1.3 m/s) -> stop (GPS speed <0.65 m/s >=3s) -> detect walking >=10s, >=6 step sensor detections and >4m -> save last stopped GPS coordinate and stop background GPS. Main screen **TÌM XE** displays line --------, current position and parked position with meters. GPS provider request 900ms, UI extrapolates at 10Hz; actual GNSS callbacks are not guaranteed 900ms. **DỪNG** stops navigation GPS; automatic parking tracker is separate.

**Important limitations:** This is a reconstruction of the behavioral pipeline using the REAL 1.4 APK's reference geofence coordinates, not an in-place binary patch of the original app. The original REAL 1.4 Gradle source and signing key were not available. It does not migrate prior REAL 1.4 saved parking history or its custom timetable logic. It depends on Google Play services, background location permission, and a step-detector sensor for reliable automated confirmation. GPS precision cannot guarantee 2 meters and geofence responsiveness varies by device. No field validation yet.
