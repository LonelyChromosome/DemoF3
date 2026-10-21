# Find Bike — North Up, Oct 21

This build is a separate Android application: com.lonelychromosome.tracereturn.northup. It does not uninstall or overwrite REAL 1.4, REAL 1.5 or Trace Return 1.0. Import GPX manually from the original app; the Oct 21 track with 73 points has not been provided as a file.

Default bike coordinate: 20.959630, 105.746592, copied from the Oct 21 REAL 1.5 screenshot (not an independently verified parking location). The Oct 17 GPX with 22 points is historical and is NOT silently substituted for the Oct 21 parking point.

The North-up map always uses GPS bearings and geographic metre offsets. North is up, East is right, South is down and West is left. Bike position, GPS user point, line and confirmed imported GPX trace are entirely independent of handset rotation. Only the user-facing direction arrow rotates using TYPE_ROTATION_VECTOR with display axis remapping.

GPS: high-accuracy location requested about every 900 ms (delivery subject to Android/location conditions); renderer runs every 100 ms; current GPS prediction capped at 1.2 seconds; cached position older than 30s is rejected on new fetch; an existing accepted GPS fix stays visible with its age when updates drop out. Reject untrusted incoming accuracy >80m. Distances shown are straight line, not routed pedestrian paths.

GPX can be selected through system file picker, and suggested parking point (if any) must be confirmed; user may select another point. Accepted imported trace is stored in this new app private storage and shown north-up.

Build: gradle -p findbike-trace-return --no-daemon :app:assembleDebug

Field tests to complete: (1) rotate handset 90 and 180 degrees while standing still: BẠN arrow rotates, XE ĐỖ and line do not. (2) walk ~20m and check changes only when new GPS arrives. (3) compare displayed heading with real bearing outdoors. (4) open imported GPX and verify north-up polyline and selected parked coordinate.

The APK is not proof that device sensors/GPS will work accurately at the parking site. Do not treat map as pedestrian routing.