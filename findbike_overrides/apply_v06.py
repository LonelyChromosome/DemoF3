from pathlib import Path
import zlib,base64,re

base=Path("findbike-build/app/src/main")
main=base/"java/com/bpa/findbike/MainActivity.java"
router=base/"java/com/bpa/findbike/WalkRouter.java"
assets=base/"assets"
router.write_bytes(zlib.decompress(base64.b64decode(Path("findbike_overrides/WalkRouter-v06.b64").read_text())))
(assets/"road_painted.bin").write_bytes(zlib.decompress(base64.b64decode(Path("findbike_overrides/roadpaint-v06.b64").read_text())))

s=main.read_text(encoding="utf-8")
def change_line(pattern,replacement):
    global s
    s,count=re.subn(pattern,lambda match:replacement,s,flags=re.MULTILINE)
    if count!=1:
        raise RuntimeError(f"v0.6 expected one UI/code match for {pattern}, found {count}")

change_line(r'^        title\.setText\(navigating \?.+$',
    '        title.setText(navigating ? (arrived ? "Đã tới vị trí xe / lối gần xe" : "Đang dẫn tới vị trí để xe") : selection == 0 ? "Chọn vị trí hiện tại (giả lập)" : "Chọn vị trí xe đã đỗ (giả lập)");')
change_line(r'^        routeModeButton\.setText\(.+$',
    '        routeModeButton.setText("TRẮNG + VÀNG: ĐI ĐƯỢC  •  XÁM: CẤM  •  LANE: ƯU TIÊN");')
change_line(r'^        state\.setText\(navigating \?.+$',
    '        state.setText(navigating ? (arrived ? "✓ Đã tới điểm gần xe · cách xe " + Math.round(map.bikeDistance()) + " đơn vị" : (map.hasRoute() ? "• Track + bước chân · Đã đi " + demoSteps + " bước · Còn " + Math.round(map.remaining()) + " đơn vị" : map.routeError())) : "◎ Xanh: vị trí hiện tại     ◆ Vàng: xe đỗ");')
change_line(r'^        float bikeDistance\(\) \{.+$',
    '        float bikeDistance() { return routing == null ? 0f : dist(routing.safeFinish,bike); }\n        boolean hasRoute() { return route != null && route.size() >= 2; }\n        String routeError() { return routing == null ? "Chưa có đường" : routing.error; }')
change_line(r'^\s*if\s*\(dist\(user,routing\.laneTarget\).+arrived\s*=\s*true;$',
    '                    if (dist(user,routing.safeFinish) < 9f || pathTotal < 9f) arrived = true;')

# v0.5 CI already removed the unsafe direct lane-to-bike connector.
main.write_text(s,encoding="utf-8")
gradle=Path("findbike-build/app/build.gradle")
config=gradle.read_text()
assert "versionCode 5" in config, "v0.5 prerequisite missing"
gradle.write_text(config.replace("versionCode 5","versionCode 6").replace("versionName '0.5-test'","versionName '0.6-test'"))
print("Applied v0.6 pedestrian A*: white/yellow walkable, gray blocked, lane cost preferred")
