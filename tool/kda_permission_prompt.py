"""Accept the actual first-entry Android audio dialog on the test emulator."""
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

def adb(*args):
    return subprocess.run(['adb', *args], capture_output=True, text=True, timeout=20)

def tap(node):
    bounds = list(map(int, re.findall(r'\d+', node.attrib['bounds'])))
    result = adb('shell', 'input', 'tap', str((bounds[0]+bounds[2])//2), str((bounds[1]+bounds[3])//2))
    assert result.returncode == 0, result.stderr

evidence = Path('build/kda-evidence')
end = time.monotonic() + 720
accepted = False
while time.monotonic() < end:
    try:
        log = evidence / 'logcat.txt'
        # Avoid launching UIAutomator while the Flutter engine is booting.
        if not log.exists() or 'act=android.content.pm.action.REQUEST_PERMISSIONS' not in log.read_text(errors='replace'):
            time.sleep(1)
            continue
        dump = adb('shell', 'uiautomator', 'dump', '/sdcard/kda-permission.xml')
        print('UI dump:', dump.returncode, dump.stdout.strip(), dump.stderr.strip(), flush=True)
        xml = adb('exec-out', 'cat', '/sdcard/kda-permission.xml').stdout
        evidence.joinpath('permission-last-ui.xml').write_text(xml)
        root = ET.fromstring(xml)
        nodes = list(root.iter('node'))
        if any('Quickstep' in n.get('text', '') for n in nodes):
            # Only dismiss the CI launcher's unrelated ANR, never an app ANR.
            close = next((n for n in nodes if n.get('resource-id', '').endswith(':id/aerr_close')), None)
            if close is not None:
                tap(close)
                time.sleep(1)
                continue
        for node in nodes:
            resource = node.get('resource-id', '')
            if resource.endswith((':id/permission_allow_foreground_only_button', ':id/permission_allow_button')):
                evidence.joinpath('permission-dialog.xml').write_text(xml)
                tap(node)
                evidence.joinpath('permission-dialog.txt').write_text('First KDA entry displayed native RECORD_AUDIO dialog; accepted using Android permission button.\n')
                print('KDA native first-entry audio permission dialog accepted', flush=True)
                accepted = True
                break
        if accepted:
            break
    except (ET.ParseError, subprocess.TimeoutExpired) as error:
        print(type(error).__name__, str(error), flush=True)
    time.sleep(1)
if not accepted:
    raise SystemExit('Expected first-entry audio permission dialog did not appear')
while time.monotonic() < end:
    log = evidence / 'integration.txt'
    if log.exists() and 'KDA FFT started' in log.read_text(errors='replace'):
        adb('shell', 'cmd', 'media_session', 'volume', '--stream', '3', '--set', '10')
        raise SystemExit(0)
    time.sleep(.5)
raise SystemExit('FFT probe did not start after permission dialog')
