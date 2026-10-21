# BPA Find Bike VFX - Pixel Scan / Coordinate Lock

Stand-alone **native animated VFX APK**, not the real Find My Bike GPS app. Fullscreen cinematic animation: BPA theme portal -> moving grid map -> pixel squares searching several candidates -> disqualifies decoys -> converges onto bike position -> lock-on -> quick square wipe to clean Find Bike screen. Tap the completed preview to replay.

The displayed coordinate is the **sample** bike location from an older user screenshot. No location permission, tracking, networking or live GPS involved; never claim location is known from the VFX. Integration into BPA Flutter should follow user approval of visual, and loading animation must not block GPS initialization.

Build: `gradle -p findbike-vfx-demo :app:assembleDebug`.
