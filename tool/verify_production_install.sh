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
print('PASS: production 1.8 -> 2.0 update install, launch and resume')
PY
# Verify the new feed against the public key embedded in the actually shipped
# previous APK, so an old BPA client can accept this signed update.
python3 - <<'PY_VERIFY'
import base64,json,os,pathlib,re,subprocess,zipfile
p=pathlib.Path('build/production-install')
oldbytes=pathlib.Path('updates/latest.json').read_bytes()
oldsig=base64.b64decode(pathlib.Path('updates/latest.json.sig').read_bytes())
newbytes=pathlib.Path('dist/latest.json').read_bytes()
newsig=base64.b64decode(pathlib.Path('dist/latest.json.sig').read_bytes())
(p/'old.sig').write_bytes(oldsig);(p/'new.sig').write_bytes(newsig)
(p/'new-latest.json').write_bytes(newbytes)
with zipfile.ZipFile(p/'previous.apk') as z:
    binary=z.read('lib/arm64-v8a/libapp.so')
candidates=set(re.findall(rb'(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{43}=(?![A-Za-z0-9+/])',binary))
def verify(key,message,signature):
    (p/'candidate.der').write_bytes(bytes.fromhex('302a300506032b6570032100')+base64.b64decode(key))
    return subprocess.run(['openssl','pkeyutl','-verify','-rawin','-pubin','-keyform','DER',
        '-inkey',str(p/'candidate.der'),'-in',str(message),'-sigfile',str(signature)],
        stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
matches=[key for key in candidates if verify(key,'updates/latest.json',p/'old.sig')]
assert len(matches)==1,'Cannot uniquely verify updater public key from shipped 1.8 APK'
key=matches[0]
assert verify(key,p/'new-latest.json',p/'new.sig'),'New feed signature is incompatible with existing BPA'
(p/'candidate.der').rename(p/'updater-public-key.der')
with zipfile.ZipFile(pathlib.Path('dist')/os.environ['APK_NAME']) as z:
    assert key in z.read('lib/arm64-v8a/libapp.so'),'New client must retain the existing updater public key'
manifest=json.loads(newbytes)
assert manifest['versionName']==os.environ['VERSION_NAME']
assert manifest['versionCode']==int(os.environ['VERSION_CODE'])
assert 0<manifest['apkSize']<=300_000_000
assert manifest['notes']==os.environ['NOTES']
(p/'feed-compatibility.txt').write_text('PASS: new Ed25519 feed verifies with public key embedded in production 1.8; public key retained in 2.0; manifest fits existing client limits.\n')
print((p/'feed-compatibility.txt').read_text())
PY_VERIFY
# The old APK is already public; evidence needs logs, not another 147 MB copy.
rm build/production-install/previous.apk
