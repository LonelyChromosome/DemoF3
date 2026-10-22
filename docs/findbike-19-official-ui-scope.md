# BPA 1.9 — Xe cộ (official UI scope)

## Official clean app screen
- Menu title **Xe cộ** replaces **Phương Tiện**, retaining the same vehicle icon and existing radial theme-menu position.
- Existing status, route preview, parked bike location and live bike directions remain.
- Waiting subjects appear in a **collapsed-by-default dropdown**. The expanded list shows the name, schedule time, and a native ✓ / ✕ availability state.
- Header reset icon provides **manually confirmed recovery** when an automatically held vehicle state is wrong. It stops a stale vehicle session, removes its old parked point/route and re-evaluates future classes from the **current cached BPA timetable**. It does not affect lessons, QLĐT, attendance, or real absence counts.
- Auto gate enter + route recording + parked detection continue. The parked alert is the only application-generated event alert. Android still requires an ongoing low-importance foreground-service notification **while actively collecting location**; this cannot be removed without breaking background GPS.
- Once parked, no continuous vehicle motion/GPS; rearm on authenticated Phenikaa Uni “Xe ra cổng” notification. Notification listener permission must be granted once.
- Expired non-parked classes leave the queue, eLearning excluded. Neither implies teacher-marked absence.

## Isolation
- Clean UI branch: `feature/bpa19-vehicle-production-clean`; panel UI and fake bridge commands removed.
- Original test panel branch retained unchanged: `feature/bpa19-notification-rearm-queue`.
- Clean **preview** uses a separate Android application ID `.vehicle.preview19`, so it does not overwrite installed BPA or panel test. The profile APK is a preview; real public release must be signed with BPA's existing release certificate and reviewed before merge to main.
- Reset is *destructive to the previous saved bike parking coordinate*. A dialog must confirm it.
