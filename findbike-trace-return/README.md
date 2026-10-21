# Find Bike — Trace Return
Standalone APK: `com.lonelychromosome.tracereturn`. Does **not overwrite** REAL 1.4 or REAL 1.5 data.

Default destination is **20.959630, 105.746592** from the user's October 21 screenshot showing `Xe đỗ:`; it is NOT derived from the older Oct 17 22-point GPX. The existing 73-point trace recorded October 21 was not shared as a GPX, so app allows importing it through the system file picker or Android Share menu. Explicitly labeled parking waypoints are preferred; otherwise a stationary cluster followed by movement is only a suggestion and requires user confirmation. Any trace point can be selected and confirmed.

Foreground fused GPS high accuracy (requested 900ms, min 400ms), cached fix + concurrent getCurrentLocation, velocity dead reckoning visual only max 1.2s. Stale GPS location stays visible with age and accuracy. True bearing to parked bike relative to device heading, north-up fallback, dashed line with straight-line distance, cyan motion arrow. No map or pedestrian lanes. Stops location updates when Activity leaves foreground. Imported destinations saved persistently to independent SharedPreferences. No old app data modifications.

The GPS coordinate from screenshot can itself have measurement error. This is point-to-point guidance, not a walking route.
