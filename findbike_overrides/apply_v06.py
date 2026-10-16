from pathlib import Path
import zlib,base64
src=Path('findbike-build/app/src/main')
main=src/'java/com/bpa/findbike/MainActivity.java'
router=src/'java/com/bpa/findbike/WalkRouter.java'
assets=src/'assets'
router.write_bytes(zlib.decompress(base64.b64decode(Path('findbike_overrides/WalkRouter-v06.b64').read_text())))
assets.joinpath('road_painted.bin').write_bytes(zlib.decompress(base64.b64decode(Path('findbike_overrides/roadpaint-v06.b64').read_text())))
s=main.read_text(encoding='utf8')
def replace(old,new):
 global s
 if old not in s:
  raise RuntimeError('Find My Bike v06 expected source mismatch: '+old[:120])
 s=s.replace(old,new)
replace('title.setText(navigating ? (arrived ? "Đã tới lane gần xe nhất" : "Đang dẫn tới lane gần xe")',
        'title.setText(navigating ? (arrived ? "Đã tới vị trí xe / lối gần xe" : "Đang dẫn tới vị trí để xe")')
replace('routeModeButton.setText("VÀNG: ĐƯỢC ĐI   •   XÁM: CẤM   •   LANE: ƯU TIÊN");',
        'routeModeButton.setText("TRẮNG + VÀNG: ĐI ĐƯỢC  •  XÁM: CẤM  •  LANE: ƯU TIÊN");')
replace('"✓ Đã tới lối đi gần xe · còn " + Math.round(map.bikeDistance()) + " đơn vị tới xe"',
        '"✓ Đã tới điểm gần xe · cách xe " + Math.round(map.bikeDistance()) + " đơn vị"')
replace('if (dist(user,routing.laneTarget) < 9f || pathTotal < 9f) arrived = true;',
        'if (dist(user,routing.safeFinish) < 9f || pathTotal < 9f) arrived = true;')
start=s.index('            // The bike itself is not a graph vertex. A subtle dotted connector makes the gap clear.')
end=s.index('            paint.setStyle(Paint.Style.FILL);',start)
s=s[:start]+s[end:]
start=s.index('            paint.setStyle(Paint.Style.FILL);',start)
end=s.index('            float spacing = dp(19) / zoom;',start)
s=s[:start]+'            paint.setStyle(Paint.Style.FILL);\n'+s[end:]
replace('"• Track + bước chân  ·  Đã đi " + demoSteps + " bước thử  ·  Còn " + Math.round(map.remaining()) + " đơn vị"',
        '(map.hasRoute() ? "• Track + bước chân  ·  Đã đi " + demoSteps + " bước thử  ·  Còn " + Math.round(map.remaining()) + " đơn vị" : map.routeError())')
replace('        float bikeDistance() { return routing == null ? 0f : routing.bikeGap; }',
        '        float bikeDistance() { return routing == null ? 0f : dist(routing.safeFinish,bike); }\n        boolean hasRoute() { return route != null && route.size() >= 2; }\n        String routeError() { return routing == null ? "Chưa có đường" : routing.error; }')
main.write_text(s,encoding='utf8')
config=Path('findbike-build/app/build.gradle')
c=config.read_text(encoding='utf8')
if 'versionCode 5' not in c: raise RuntimeError('Expected v05 build version')
c=c.replace('versionCode 5','versionCode 6').replace("versionName '0.5-test'","versionName '0.6-test'")
config.write_text(c,encoding='utf8')
print('v0.6 route, UI and road bitmap installed')
