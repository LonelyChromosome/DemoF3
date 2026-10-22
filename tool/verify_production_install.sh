#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/production-install
python3 - <<'PY'
import hashlib,json,urllib.request,pathlib
previous=json.loads(pathlib.Path('updates/latest.json').read_text())
assert previous['packageName']=='vn.edu.phenikaa.better_phenikaa_schedule'
assert previous['apkUrl'].startswith('https://github.com/LonelyChromosome/DemoF3/releases/download/')
with urllib.request.urlopen(previous['apkUrl']) as response:
    data=response.read()
assert hashlib.sha256(data).hexdigest()==previous['apkSha256']
pathlib.Path('build/production-install/previous.apk').write_bytes(data)
PY
pkg=vn.edu.phenikaa.better_phenikaa_schedule
adb logcat -c
adb install build/production-install/previous.apk | tee build/production-install/previous-install.txt
adb shell am start -W -n "$pkg/$pkg.MainActivity" > build/production-install/previous-launch.txt
adb shell dumpsys package "$pkg" > build/production-install/previous-package.txt
adb shell am force-stop "$pkg"
adb install -r "dist/$APK_NAME" | tee build/production-install/update-install.txt
adb shell am start -W -n "$pkg/$pkg.MainActivity" | tee build/production-install/launch.txt
sleep 6
adb shell pidof "$pkg" > build/production-install/pid.txt
adb shell dumpsys package "$pkg" > build/production-install/package.txt
adb exec-out screencap -p > build/production-install/launch.png
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -W -n "$pkg/$pkg.MainActivity" > build/production-install/resume.txt
sleep 2
adb logcat -d -v threadtime > build/production-install/logcat.txt
python3 - <<'PY'
import pathlib,os,re
p=pathlib.Path('build/production-install')
for name in ['previous-install.txt','update-install.txt']:assert 'Success' in (p/name).read_text()
for name in ['launch.txt','resume.txt']:assert 'Status: ok' in (p/name).read_text()
assert (p/'pid.txt').read_text().strip()
s=(p/'package.txt').read_text()
assert 'versionName='+os.environ['VERSION_NAME'] in s
assert 'versionCode='+os.environ['VERSION_CODE'] in s
old=(p/'previous-package.txt').read_text()
first=lambda x:re.search(r'firstInstallTime=([^\n]+)',x).group(1)
assert first(old)==first(s),'Update must retain installed package identity'
logs=(p/'logcat.txt').read_text(errors='replace')
assert 'FATAL EXCEPTION' not in logs
assert 'ANR in vn.edu.phenikaa.better_phenikaa_schedule' not in logs
print('PASS: production 1.8 -> 1.9 update install, launch and resume')
PY
# The old APK is already public; evidence needs logs, not another 147 MB copy.
rm build/production-install/previous.apk
