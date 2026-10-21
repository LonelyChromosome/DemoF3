# FindBike NorthUp 2.0.1 AutoNav

**User validated NorthUp 2.0 parking position and orientation.** This is a minimally changed fork of *exactly that code*, not the separate Motion Fusion 2.1 implementation.

Changes:
- Start navigation automatically on first open and every subsequent \`onResume()\` while user enabled. \`onStop()\` releases location listeners without clearing persistent desire to navigate. Explicit STOP persists off; START persists on.
- Foreground GPS subscription watchdog retries automatically when the last accepted fix is older than 12 s, throttled to once every 18 s. No fake GPS fix is invented.
- Walking extrapolation requires multiple recent GPS points with displacement beyond accuracy plus steps (Android ACTIVITY_RECOGNITION) or stronger conservative GPS-only evidence if detector unavailable. It is disabled at rest or after 2.5 s with no confirmed motion. The original NorthUp 2.0 map/bike bearing and visual arrow (phone orientation, NOT walking direction) remain otherwise unchanged.
- This app runs foreground-only; it **automatically starts on returning to the app**, but intentionally does not track background continuously.
- The original saved bike destination, default \`20.959630,105.746592\`, comes from user screenshot. This APK has a different package ID \`com.lonelychromosome.tracereturn.northup.autofix\`, so it can be installed alongside existing NorthUp 2.0 without signature mismatch or data loss. It DOES NOT read/migrate the 2.0 private data or 73-point GPX. User can reimport GPX if needed.
- Tests required on device: app auto starts at launch; goes home then returns and starts by itself; manual STOP stays stopped; standing still 15s never triggers extrapolation; walk outdoors 20m and check confirmed walking; block GPS 20s to see auto-retry.

Build: \`gradle -p findbike-trace-return --no-daemon :app:assembleDebug\`
