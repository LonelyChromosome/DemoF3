#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/kda-evidence
adb logcat -c
adb logcat -v threadtime > build/kda-evidence/logcat.txt &
log_pid=$!
(
  granted=false
  for attempt in $(seq 1 360); do
    if [[ "$granted" == false ]] && adb shell pm path vn.edu.phenikaa.better_phenikaa_schedule.kdatest | grep -q package:; then
      adb shell pm grant vn.edu.phenikaa.better_phenikaa_schedule.kdatest android.permission.RECORD_AUDIO
      granted=true
    fi
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
# Install the exact normal-entrypoint profile APK delivered to the user.
mkdir -p build/kda-delivered-apk
for attempt in $(seq 1 60); do
  if gh run download "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY" -n KDA-build-input -D build/kda-delivered-apk; then break; fi
  sleep 5
done
apk=$(find build/kda-delivered-apk -name BPA-KDA-FIRESTARTER-Test.apk -type f | head -1)
test -n "$apk"
# Use the emulator job's generated debug signer so the tested debug app and
# delivered profile APK share one valid test certificate; no key is uploaded.
signer=$(find "$ANDROID_HOME/build-tools" -maxdepth 2 -name apksigner | sort -V | tail -1)
mkdir -p dist
"$signer" sign --ks "$HOME/.android/debug.keystore" --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out dist/BPA-KDA-FIRESTARTER-Test.apk "$apk"
"$signer" verify --verbose --print-certs dist/BPA-KDA-FIRESTARTER-Test.apk > dist/signature.txt
(cd dist && sha256sum BPA-KDA-FIRESTARTER-Test.apk > SHA256SUMS)
printf '%s\n' "$GITHUB_SHA" > dist/COMMIT_SHA
apk=dist/BPA-KDA-FIRESTARTER-Test.apk
adb install -r "$apk" | tee build/kda-evidence/delivered-apk-install.txt
adb shell am force-stop vn.edu.phenikaa.better_phenikaa_schedule.kdatest
adb shell am start -W -n vn.edu.phenikaa.better_phenikaa_schedule.kdatest/vn.edu.phenikaa.better_phenikaa_schedule.MainActivity | tee build/kda-evidence/delivered-apk-launch.txt
sleep 8
adb exec-out screencap -p > build/kda-evidence/delivered-apk.png
adb shell pidof vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/delivered-apk-pid.txt
adb shell dumpsys meminfo vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/meminfo.txt
adb shell dumpsys package vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/package.txt
python3 - <<'PY'
from pathlib import Path
s=Path('build/kda-evidence/logcat.txt').read_text(errors='replace')
assert 'FATAL EXCEPTION' not in s, 'Inspect fatal exception in logcat'
assert 'ANR in vn.edu.phenikaa.better_phenikaa_schedule.kdatest' not in s
assert 'Status: ok' in Path('build/kda-evidence/delivered-apk-launch.txt').read_text()
assert Path('build/kda-evidence/delivered-apk-pid.txt').read_text().strip()
PY
