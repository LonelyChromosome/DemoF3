from pathlib import Path
import re
main=Path("findbike-build/app/src/main/java/com/bpa/findbike/MainActivity.java")
router=Path("findbike-build/app/src/main/java/com/bpa/findbike/WalkRouter.java")
router.write_text(Path("findbike_overrides/WalkRouterV05.java").read_text(),encoding="utf-8")
s=main.read_text()
old="            routing = router.route(user, bike);\n            route = routing.points;"
assert old in s, "0.5 mismatch route init"
s=s.replace(old,"            routing = router.route(user, bike);\n            if(routing.adjustedStart)user.set(routing.safeStart.x,routing.safeStart.y);\n            route = routing.points;")
old="            if (arrived || route.size() < 2 || pathTotal <= 1f) { arrived = true; refreshUi(); return; }"
assert old in s,"0.5 mismatch step"
s=s.replace(old,"            if(route.size()<2){refreshUi();return;}\n            if(arrived || pathTotal<=1f){arrived=true;refreshUi();return;}")
old='state.setText(navigating ? (arrived ? "✓ Đã tới lối đi gần xe · còn " + Math.round(map.bikeDistance()) + " đơn vị tới xe" : "• Track + bước chân  ·  Đã đi " + demoSteps + " bước thử  ·  Còn " + Math.round(map.remaining()) + " đơn vị") : "◎ Xanh: vị trí hiện tại     ◆ Vàng: xe đỗ");'
assert old in s,"0.5 mismatch labels"
s=s.replace(old,'state.setText(navigating ? (map.routing != null && !map.routing.error.isEmpty() ? map.routing.error : arrived ? "✓ Đã tới lane gần xe · xe cách " + Math.round(map.bikeDistance()) + " đơn vị" : "• Track + chấm bước · Đã đi " + demoSteps + " bước · Còn " + Math.round(map.remaining()) + " đơn vị") : "◎ Xanh: vị trí hiện tại     ◆ Vàng: xe đỗ");')
# Avoid drawing a fictitious walking extension directly through gray buildings.
start=s.index("            // The bike itself is not a graph vertex.")
end=s.index("            paint.setStyle(Paint.Style.FILL);\n            float spacing =", start)
s=s[:start]+s[end:]
# Remove stale code/comment claiming all buildings can be traversed.
s=s.replace("     *  No buildings are marked as obstacles: users can deliberately leave the suggested lane.","     *  Legacy reference graph below is not used by the active router.")
main.write_text(s)
gradle=Path("findbike-build/app/build.gradle")
g=gradle.read_text()
assert "versionCode 4" in g and "0.4-test" in g
gradle.write_text(g.replace("versionCode 4","versionCode 5").replace("0.4-test","0.5-test"))
print("Patched 0.5 router, grey safety and status")
