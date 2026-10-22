# BPA 1.9 — Notification-based RE-ARM + waiting queue

## Distinct roles
- BPA supplies class name, start/end, and authoritative `lessonKind`.
- Find My Bike handles waiting, geofence tracking, parking, exit notification and session lifecycle.
- `ELEARNING` is categorically excluded from the waiting queue. The lesson classification is preserved through optional `lessonKind` serialization, without persisting attendance results.
- When a scheduled class ends and no vehicle has been confirmed parked, it disappears from the waiting list and an unparked real GPS tracking session stops. This means **no vehicle was parked by the detector**, not an authoritative absence.
- Never alter absence count or class attendance. Lecturer's attendance record is independent.

## Real exit
- When PARKED, disable activity recognition and continuous GPS; Android NotificationListenerService listens for a genuine `Xe ra cổng` notification from **only** `phx.smartschool.phenikaauniversity` (Phenikaa Uni).
- Accept only notices posted after the saved parking timestamp; if an entry plate was learned from Phenikaa Uni, require matching exit plate. Process delayed notifications up to 6 hours old.
- After valid exit, clear real parked point, mark the previous lesson window consumed and re-evaluate future classes.
- The listener requires the user to grant Android's **Notification access** permission explicitly. Phenikaa Uni needs notifications enabled.
- The listener depends on delivery; if the official notification never arrives, the parked session remains locked (no guessed reset).

## TEST vs REAL
- Test: `testExit` simulates exit on **test-only prefs and route**, not production session. Existing test buttons remain.
- Real: only official sender notifications unlock the real state. No test action mutates the real parked position.
- TEST notifications retain their own labels.

## Background behavior
- Local scheduling uses AlarmManager and passive geofence callbacks. Alarm timing can be deferred by Android.
- No production deployment, no merge to main. Verify on-device notification permissions, incoming events and background restrictions before calling the feature production-ready.
