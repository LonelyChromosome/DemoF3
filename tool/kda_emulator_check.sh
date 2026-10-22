#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/kda-evidence
# Give the real FFT test a known, non-muted media stream on this emulator only.
adb shell cmd media_session volume --stream 3 --set 10
adb logcat -c
adb logcat -v threadtime > build/kda-evidence/logcat.txt &
log_pid=$!
(
  for attempt in $(seq 1 360); do
    if adb shell pm path vn.edu.phenikaa.better_phenikaa_schedule.kdatest | grep -q package:; then
      adb shell pm grant vn.edu.phenikaa.better_phenikaa_schedule.kdatest android.permission.RECORD_AUDIO
      break
    fi
    sleep 2
  done
) > build/kda-evidence/lifecycle.txt 2>&1 &
cycle_pid=$!
(
  while true; do
    sleep 30
    timeout 10s adb exec-out screencap -p > build/kda-evidence/latest-screen.png 2>/dev/null || true
  done
) &
screen_pid=$!
finish() {
  timeout 10s adb exec-out screencap -p > build/kda-evidence/final-screen.png 2>/dev/null || true
  kill "$log_pid" "$cycle_pid" "$screen_pid" 2>/dev/null || true
}
trap finish EXIT
timeout --kill-after=15s 720s flutter test integration_test/kda_firestarter_test.dart -d emulator-5554 --reporter expanded 2>&1 | tee build/kda-evidence/integration.txt
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
# Exercise lifecycle on the delivered normal-entrypoint APK. Keep the integration
# binding out of the background so its frame-pump cannot wait on a paused engine.
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -f 0x10200000 -n vn.edu.phenikaa.better_phenikaa_schedule.kdatest/vn.edu.phenikaa.better_phenikaa_schedule.MainActivity | tee build/kda-evidence/delivered-apk-resume.txt
sleep 3
adb exec-out screencap -p > build/kda-evidence/delivered-apk-resumed.png
adb shell pidof vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/delivered-apk-pid.txt
adb shell dumpsys meminfo vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/meminfo.txt
adb shell dumpsys package vn.edu.phenikaa.better_phenikaa_schedule.kdatest > build/kda-evidence/package.txt
python3 - <<'PY'
from pathlib import Path
import json
s=Path('build/kda-evidence/logcat.txt').read_text(errors='replace')
events=[]
for line in s.splitlines():
 if 'KdaLifecycle:' in line:
  text=line.split('KdaLifecycle:',1)[1].strip()
  kind,payload=text.split(' ',1)
  events.append((kind,json.loads(payload)))
pauses=[x for kind,x in events if kind=='pause' and x['enabled']]
resumes=[x for kind,x in events if kind=='resume' and x['enabled']]
assert pauses and resumes, 'Expected actual enabled-player pause/resume events'
assert pauses[-1]['foreground'] is False and pauses[-1]['playing'] is False
assert resumes[-1]['foreground'] is True and resumes[-1]['playing'] is True
assert abs(resumes[-1]['positionMs']-pauses[-1]['positionMs'])<1500, 'Resume must preserve position'
Path('build/kda-evidence/lifecycle-states.json').write_text(json.dumps(events,indent=2))
assert 'FATAL EXCEPTION' not in s, 'Inspect fatal exception in logcat'
assert 'ANR in vn.edu.phenikaa.better_phenikaa_schedule.kdatest' not in s
assert 'Status: ok' in Path('build/kda-evidence/delivered-apk-launch.txt').read_text()
assert Path('build/kda-evidence/delivered-apk-pid.txt').read_text().strip()
PY
