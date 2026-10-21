# Find Bike NorthUp 2.1 — Motion Fusion (experimental)

Independent Android APK: \`com.lonelychromosome.tracereturn.motion21\`, NOT an update of REAL 1.5 or NorthUp 2.0; old on-device app data untouched. Does not automatically migrate imported GPX or personal trip states from old apps. Default bike coordinate **20.959630, 105.746592** came from a screenshot, not verified independently. The current user's 73-point track GPX was not supplied. Import GPX manually and confirm a point if needed.

## Heading logic
- The bike point/line is always **north-up** based on GPS coordinates. The orange parked marker does not rotate with the phone.
- **NO heading when stationary.** Device orientation does not represent body-facing or walking heading. Rotation vector is acquired but not used to infer walking course.
- Step detector (ACTIVITY_RECOGNITION permission) reports walking evidence, not heading; GPS remains usable if denied. Linear acceleration only flags device motion/shaking and NEVER assigns a direction.
- Travel heading is derived from course over ground from multiple GPS fixes over 3.5–14s with displacement greater than the combined accuracy threshold; or from two consistent GPS speed/bearing readings with adequate uncertainties and speed.
- The cyan arrow is only drawn while a recent, verified walking course exists. When standing or direction uncertain, show clear absence of a travel arrow instead of a false arrow.
- While stationary, minor GPS scatter is suppressed; confidence and staleness remain explicit. Extrapolation stops when not moving; active reliable course only, max 1.1s and speed cap.
- Target GUI refresh 10Hz; location requests 900ms but Android controls actual intervals.
- App foreground only. Straight-line guidance, not an accessible pedestrian route.
- Device field tests still required. It is not possible to know the direction a person faces while stationary using GPS displacement alone.
