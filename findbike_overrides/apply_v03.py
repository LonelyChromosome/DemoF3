from pathlib import Path
source=Path("findbike-build/app/src/main/java/com/bpa/findbike/MainActivity.java")
s=source.read_text()
def replace(old,new):
    global s
    assert old in s, "Missing expected code fragment: "+old[:100]
    s=s.replace(old,new)
replace("private final LaneGraph lanes;", "private final WalkRouter router;")
replace("lanes = new LaneGraph(getAssets());", "router = new WalkRouter(getAssets());")
replace("routeModeButton.setOnClickListener(v -> { shortestMode = !shortestMode; map.rebuildRoute(); map.invalidate(); refreshUi(); });", "routeModeButton.setOnClickListener(null);")
replace('routeModeButton.setText(shortestMode ? "NGẮN NHẤT · ĐƯỢC ĐI XUYÊN TÒA NHÀ   ↔" : "ƯU TIÊN LANE · RẼ KHI LỆCH TUYẾN   ↔");', 'routeModeButton.setText("ĐƯỜNG ĐI TỐI ƯU   •   CÓ THỂ ĐI QUA KHỐI VÀNG");')
replace('''            Route result = lanes.route(user, bike, shortestMode);
            route = result.points;
            firstRoadSegment = result.firstRoadSegment;
            lastRoadSegment = result.lastRoadSegment;
            routeOnLane = result.onLane;''','''            route = router.route(user, bike);''')
head=s.index("        private void drawRoute(Canvas canvas) {")
end=s.index("        private void drawMarker(Canvas c, PointF p,",head)
new='''        private void drawRoute(Canvas canvas) {
            if (route.size() < 2) return;
            paint.setPathEffect(null);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeJoin(Paint.Join.ROUND);
            paint.setStrokeWidth(dp(1.65f) / zoom);
            paint.setColor(Color.rgb(16, 169, 217));
            Path track = new Path();
            track.moveTo(route.get(0).x, route.get(0).y);
            for (int i = 1; i < route.size(); i++) track.lineTo(route.get(i).x, route.get(i).y);
            canvas.drawPath(track, paint);
            paint.setStyle(Paint.Style.FILL);
            float spacing = dp(19) / zoom;
            for (float d = spacing; d < pathTotal; d += spacing) {
                PointF p = locationAlong(d);
                PointF p0 = locationAlong(Math.max(0, d - 4 / zoom));
                PointF p1 = locationAlong(Math.min(pathTotal, d + 4 / zoom));
                float theta = (float)Math.atan2(p1.y - p0.y, p1.x - p0.x);
                float side = (((int)(d / spacing) & 1) == 0 ? -1f : 1f) * dp(3.1f) / zoom;
                paint.setColor(Color.rgb(16, 169, 217));
                canvas.drawCircle(p.x - (float)Math.sin(theta)*side,
                    p.y + (float)Math.cos(theta)*side,dp(2.5f)/zoom,paint);
                paint.setColor(Color.WHITE);
                canvas.drawCircle(p.x - (float)Math.sin(theta)*side,
                    p.y + (float)Math.cos(theta)*side,dp(.7f)/zoom,paint);
            }
        }
'''
s=s[:head]+new+s[end:]
source.write_text(s)
router=Path("findbike_overrides/WalkRouter.java")
assert router.is_file()
target=source.with_name("WalkRouter.java")
target.write_bytes(router.read_bytes())
print("v0.3 soft-lane router inserted",len(s),len(target.read_bytes()))
