# Find My Bike — Polling Line Test 1.5
A dedicated test application with its own package `com.lonelychromosome.findbikepollingtest`. Does not overwrite REAL 1.4.

**Test flow:** Install -> allow precise location -> stand at parked bike -> press **LƯU XE** (wait for fresh GPS fix) -> walk away -> press **TÌM XE**. Shows one dashed line and meters to parked coordinates on a plain white background. **DỪNG** removes all location listeners and frame callbacks. Long press **LƯU XE** to delete test bike position.

Real Android LocationManager GPS_PROVIDER requests 900ms location callback and network fallback at 1500ms; these are requested intervals, not guarantees. Display position interpolates between real fixes at 10Hz for up to 1.2s. The saved bike location is always a real accepted GPS fix. GPS intervals and accuracy are shown for real-world verification. No map tiles, lanes, routing, simulated coords or background tracking.

This is an isolated **polling + line UI test**, not a recompiled REAL 1.4/1.5. Parking confirmation after 10 seconds of walking remains in the separate REAL app; it is not part of this test. The original 1.4 APK has no matching Gradle source in the inspected repo.
