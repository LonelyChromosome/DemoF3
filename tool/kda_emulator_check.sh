#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/kda-evidence
adb logcat -c
adb logcat -v threadtime > build/kda-evidence/logcat.txt &
log_pid=$!
(
  for attempt in $(seq 1 360); do
    if adb shell test -f /sdcard/Android/data/vn.edu.phenikaa.better_phenikaa_schedule.kdatest/files/kda-ready; then
      adb exec-out screencap -p > build/kda-evidence/cinematic.png
      adb shell input keyevent KEYCODE_HOME
      sleep 2
      adb shell am start -n vn.edu.phenikaa.better_phenikaa_schedule.kdatest/vn.edu.phenikaa.better_phenikaa_schedule.MainActivity
      break
    fi
    sleep 2
  done
) > build/kda-evidence/lifecycle.txt 2>&1 &
cycle_pid=$!
trap 'kill "$log_pid" "$cycle_pid" 2>/dev/null || true' EXIT
flutter test integration_test/kda_firestarter_test.dart -d emulator-5554 --reporter expanded 2>&1 | tee build/kda-evidence/integration.txt
adb shell dumpsys meminfo vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/meminfo.txt
adb shell dumpsys package vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/package.txt
python3 - <<'PY'
from pathlib import Path
s=Path('build/kda-evidence/logcat.txt').read_text(errors='replace')
assert 'FATAL EXCEPTION' not in s, 'Inspect fatal exception in logcat'
assert 'ANR in vn.edu.phenikaa.better_phenikaa_schedule.kdatest' not in s
PY
