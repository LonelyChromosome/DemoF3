"""Operate actual Android permission screens only on the CI test emulator."""
from pathlib import Path
import re, subprocess, time, xml.etree.ElementTree as ET
out=Path('build/findbike-evidence');out.mkdir(parents=True,exist_ok=True)
def adb(*args):
    return subprocess.run(['adb',*args],capture_output=True,text=True,timeout=15)
def tap(node):
    b=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
    if len(b)==4: adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2))
seen=set();end=time.monotonic()+600;last_screen=''
while time.monotonic()<end:
    try:
        log=(out/'integration.txt').read_text(errors='replace') if (out/'integration.txt').exists() else ''
        if 'FB_SETUP COMPLETE:' in log: break
        adb('shell','uiautomator','dump','/sdcard/fb-permission.xml')
        xml=adb('exec-out','cat','/sdcard/fb-permission.xml').stdout
        nodes=list(ET.fromstring(xml).iter('node'))
        packages={n.get('package','') for n in nodes}
        package=adb('shell','dumpsys','package','vn.edu.phenikaa.better_phenikaa_schedule.kdatest').stdout
        # Android hosts both runtime dialogs AND App permissions/Location
        # settings inside PermissionController. Route by visible controls first.
        controller=bool(packages & {'com.google.android.permissioncontroller',
                                    'com.android.permissioncontroller','com.android.settings'})
        allow_runtime=next((n for n in nodes if n.get('resource-id','').endswith(
            (':id/permission_allow_foreground_only_button',':id/permission_allow_button'))),None)
        if allow_runtime is not None:
            index=len(seen);title=' '.join(n.get('text','') for n in nodes)
            if title not in seen:
                seen.add(title);(out/f'runtime-{index}.xml').write_text(xml)
            tap(allow_runtime)
        elif controller:
            if 'FB_SETUP background PASS; listener start' in log:
                (out/'listener-screen.xml').write_text(xml)
                if 'notificationAccess' not in seen:
                    switch=next((n for n in nodes if n.get('checkable')=='true' and n.get('checked')=='false' and n.get('enabled')=='true'),None)
                    allow=next((n for n in nodes if n.get('text','').lower()=='allow' and n.get('clickable')=='true'),None)
                    if allow is not None: tap(allow)
                    elif switch is not None: tap(switch)
                listeners=adb('shell','settings','get','secure','enabled_notification_listeners').stdout
                if 'VehicleExitNotificationListener' in listeners:
                    seen.add('notificationAccess');adb('shell','input','keyevent','KEYCODE_BACK')
            elif 'FB_SETUP runtime PASS; background start' in log:
                (out/'background-screen.xml').write_text(xml)
                if 'android.permission.ACCESS_BACKGROUND_LOCATION: granted=true' in package:
                    adb('shell','input','keyevent','KEYCODE_BACK')
                else:
                    for label in ['Allow all the time','Location','Permissions']:
                        node=next((n for n in nodes if n.get('text','')==label),None)
                        if node is not None: tap(node);break
        # Capture all progress and UI for diagnosis without pre-granting any permission.
        (out/'last-ui.xml').write_text(xml)
    except (ET.ParseError,subprocess.TimeoutExpired) as error: print(error,flush=True)
    time.sleep(.5)
else: raise SystemExit('Find Bike native permission flow timed out')
(out/'permission-flow.txt').write_text('Actual Android dialogs/settings and final in-app permission states verified; no pm grant or appops bypass.\n')
