from pathlib import Path

base=Path("findbike-build/app/src/main")
java=base/"java/com/bpa/findbike/MainActivity.java"
s=java.read_text(encoding="utf-8")
def change(old,new):
    global s
    if old not in s:
        raise RuntimeError("v0.4 patch mismatch: "+old[:125])
    s=s.replace(old,new)

change("import android.os.SystemClock;",
"""import android.os.SystemClock;
import android.animation.ValueAnimator;
import android.view.animation.DecelerateInterpolator;""")
change("private boolean shortestMode = false;", "private boolean arrived = false;")
change('stepButton.setOnClickListener(v -> { if (navigating) { map.advanceDemoStep(); demoSteps++; refreshUi(); } else map.resetCamera(); });',
       'stepButton.setOnClickListener(v -> { if (navigating) map.advanceDemoStep(); else map.resetCamera(); });')
change('        demoSteps = 0;\n        map.navigate(true);',
       '        demoSteps = 0;\n        arrived = false;\n        map.navigate(true);')
change('        demoSteps = 0;\n        map.navigate(false);',
       '        demoSteps = 0;\n        arrived = false;\n        map.navigate(false);')
change('stepButton.setText(navigating ? "BƯỚC THỬ" : "TOÀN MAP");',
       'stepButton.setText(navigating ? (arrived ? "ĐÃ ĐẾN" : "BƯỚC THỬ") : "TOÀN MAP");')
change('title.setText(navigating ? "Đang dẫn tới vị trí để xe"',
       'title.setText(navigating ? (arrived ? "Đã tới lane gần xe nhất" : "Đang dẫn tới lane gần xe")')
change('routeModeButton.setText("ĐƯỜNG ĐI TỐI ƯU   •   CÓ THỂ ĐI QUA KHỐI VÀNG");',
       'routeModeButton.setText("QUA KHỐI VÀNG → RA LANE → TỚI GẦN XE");')
change('state.setText(navigating ? "• Track + chấm bước chân  ·  Đã đi " + demoSteps + " bước thử" : "◎ Xanh: vị trí hiện tại     ◆ Vàng: xe đỗ");',
       'state.setText(navigating ? (arrived ? "✓ Đã tới lane gần xe · xe cách lane " + Math.round(map.bikeDistance()) + " đơn vị" : "• Track + bước chân · Đã đi " + demoSteps + " bước · Còn " + Math.round(map.remaining()) + " đơn vị") : "◎ Xanh: vị trí hiện tại     ◆ Vàng: xe đỗ");')
change('private ArrayList<PointF> route = new ArrayList<>();',
       'private ArrayList<PointF> route = new ArrayList<>();\n        private WalkRouter.Result routing;\n        private ValueAnimator stepAnimator;')

a=s.index('        void advanceDemoStep() {')
b=s.index('        private PointF locationAlong(float d) {',a)
s=s[:a]+"""        float remaining() { return pathTotal; }
        float bikeDistance() { return routing == null ? 0f : routing.bikeGap; }
        void advanceDemoStep() {
            if (stepAnimator != null && stepAnimator.isRunning()) return;
            if (arrived || route.size() < 2 || pathTotal <= 1f) {
                arrived = true; refreshUi(); return;
            }
            final float travel = Math.min(pathTotal,
                         Math.max(37f, Math.min(58f,pathTotal * .24f)));
            final PointF destination = locationAlong(travel);
            stepAnimator = ValueAnimator.ofFloat(0f,1f);
            stepAnimator.setDuration(470);
            stepAnimator.setInterpolator(new DecelerateInterpolator());
            stepAnimator.addUpdateListener(animation -> {
                float progress=(Float)animation.getAnimatedValue();
                // Follow the actual polyline, including turns, not a straight chord.
                PointF moving=locationAlong(travel*progress);
                user.set(moving.x,moving.y);
                // Stop auto-centering every simulated step: the marker must visibly move.
                PointF projected=screen(user);
                if(projected.x<getWidth()*.22f || projected.x>getWidth()*.78f ||
                   projected.y<getHeight()*.29f || projected.y>getHeight()*.69f){
                    desiredX=user.x;
                    desiredY=user.y;
                }
                postInvalidateOnAnimation();
            });
            stepAnimator.addListener(new android.animation.AnimatorListenerAdapter(){
                boolean cancelled=false;
                @Override public void onAnimationCancel(android.animation.Animator a){
                    cancelled=true;
                }
                @Override public void onAnimationEnd(android.animation.Animator a){
                    if(cancelled)return;
                    user.set(destination.x,destination.y);
                    rebuildRoute();
                    demoSteps++;
                    if(dist(user,routing.laneTarget)<9f || pathTotal<9f)arrived=true;
                    refreshUi();
                }
            });
            stepAnimator.start();
        }
""" + s[b:]
change('            if (enabled) {\n                rebuildRoute();',
       '            if(stepAnimator != null && stepAnimator.isRunning())stepAnimator.cancel();\n            if (enabled) {\n                rebuildRoute();')
change('        void rebuildRoute() {\n            route = router.route(user, bike);',
       '        void rebuildRoute() {\n            routing = router.route(user,bike);\n            route = routing.points;')
change('            canvas.drawPath(track, paint);\n            paint.setStyle(Paint.Style.FILL);',
"""            canvas.drawPath(track, paint);
            // Bike is NOT the routing goal. Draw only a subtle dotted gap from lane to bike.
            if(routing!=null && routing.bikeGap>7f) {
                PointF end=routing.laneTarget;
                int count=(int)(routing.bikeGap/(dp(17)/zoom));
                paint.setColor(Color.argb(135,16,169,217));
                paint.setStyle(Paint.Style.FILL);
                for(int i=1;i<count;i++) {
                    float fraction=(float)i/count;
                    canvas.drawCircle(end.x+(bike.x-end.x)*fraction,
                        end.y+(bike.y-end.y)*fraction,dp(1.7f)/zoom,paint);
                }
            }
            paint.setStyle(Paint.Style.FILL);""")
change('                        if (navigating || selection == 0) {\n                            user.set',
       '                        if (navigating || selection == 0) {\n                            if(stepAnimator!=null && stepAnimator.isRunning())stepAnimator.cancel();\n                            user.set')
change('                        rebuildRoute(); invalidate();',
       '                        if(navigating)arrived=false;\n                        rebuildRoute(); refreshUi(); invalidate();')
java.write_text(s,encoding="utf-8")
router=Path("findbike_overrides/WalkRouterV04.java")
(base/"java/com/bpa/findbike/WalkRouter.java").write_text(
    router.read_text(encoding="utf-8"),encoding="utf-8")
build=Path("findbike-build/app/build.gradle")
g=build.read_text().replace("versionCode 3","versionCode 4").replace("0.3-test","0.4-test")
build.write_text(g)
print("FMB 0.4 patched: lane-first router, animated steps",len(s),len(g))
