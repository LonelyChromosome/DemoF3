"""Accept the actual first-entry Android audio dialog on the test emulator."""
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

def adb(*args):
    return subprocess.run(['adb', *args], capture_output=True, text=True, timeout=15)

evidence = Path('build/kda-evidence')
end = time.monotonic() + 720
while time.monotonic() < end:
    try:
        if 'package:' not in adb('shell', 'pm', 'path', 'vn.edu.phenikaa.better_phenikaa_schedule.kdatest').stdout:
            time.sleep(1)
            continue
        adb('shell', 'uiautomator', 'dump', '/sdcard/kda-permission.xml')
        xml = adb('exec-out', 'cat', '/sdcard/kda-permission.xml').stdout
        root = ET.fromstring(xml)
        for node in root.iter('node'):
            resource = node.get('resource-id', '')
            if resource.endswith((':id/permission_allow_foreground_only_button', ':id/permission_allow_button')):
                bounds = list(map(int, re.findall(r'\d+', node.attrib['bounds'])))
                evidence.joinpath('permission-dialog.xml').write_text(xml)
                result = adb('shell', 'input', 'tap', str((bounds[0]+bounds[2])//2), str((bounds[1]+bounds[3])//2))
                assert result.returncode == 0, result.stderr
                evidence.joinpath('permission-dialog.txt').write_text('First KDA entry displayed native RECORD_AUDIO dialog; accepted using Android permission button.\n')
                print('KDA native first-entry audio permission dialog accepted', flush=True)
                # Restore a non-muted test stream when the FFT probe starts.
                while time.monotonic() < end:
                    log = evidence / 'integration.txt'
                    if log.exists() and 'KDA FFT started' in log.read_text(errors='replace'):
                        adb('shell', 'cmd', 'media_session', 'volume', '--stream', '3', '--set', '10')
                        raise SystemExit(0)
                    time.sleep(.5)
                raise SystemExit('FFT probe did not start after permission dialog')
    except (ET.ParseError, subprocess.TimeoutExpired):
        pass
    time.sleep(1)
raise SystemExit('Expected first-entry audio permission dialog did not appear')
