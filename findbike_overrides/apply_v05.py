from pathlib import Path
import re
main=Path("findbike-build/app/src/main/java/com/bpa/findbike/MainActivity.java")
router=Path("findbike-build/app/src/main/java/com/bpa/findbike/WalkRouter.java")
router.write_text(Path("findbike_overrides/WalkRouterV05.java").read_text(),encoding="utf-8")
s=main.read_text()
old="            routing = router.route(user,bike);\n            route = routing.points;"
assert old in s, "0.5 mismatch route init"
s=s.replace(old,"            routing = router.route(user, bike);\n            if(routing.adjustedStart)user.set(routing.safeStart.x,routing.safeStart.y);\n            route = routing.points;")
old="            if (arrived || route.size() < 2 || pathTotal <= 1f) {\n                arrived = true; refreshUi(); return;\n            }"
assert old in s,"0.5 mismatch step"
s=s.replace(old,"            if(route.size()<2){refreshUi();return;}\n            if(arrived || pathTotal<=1f){arrived=true;refreshUi();return;}")
# Surface the routing error, rather than drawing an unsafe straight fallback.
assert "        map.invalidate();" in s
s=s.replace("        map.invalidate();",
"""        if(navigating && map.routing!=null && !map.routing.error.isEmpty())
            state.setText(map.routing.error);
        map.invalidate();""",1)
# Avoid drawing a fictitious walking extension directly through gray buildings.
start=s.index("            // Bike is NOT the routing goal.")
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
