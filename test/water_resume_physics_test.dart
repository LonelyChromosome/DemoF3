import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_physics.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_surface.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_optics.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_motion_input.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';

void main() {
  test('resume waits for new gravity, discards stale column and shake', () {
    final e = WaterEngine(const WaterConfig(fill: .08));
    addTearDown(e.dispose);
    e.setViewport(.48);
    e.physics.gravity(9.81, 0);
    for (var i = 0; i < 180; i++) e.tick(1 / 60);
    e.physics.acceleration(-55, 55);
    e.suspend();
    final time = e.physics.time;
    e.tick(30);
    expect(e.physics.time, time);
    e.resume();
    e.tick(.05);
    expect(e.restoring, true);
    expect(e.physics.time, time);
    e.motion.accept(0, 9.81, 0, 0, 0);
    e.tick(1 / 60);
    e.rebuildSurface();
    expect(e.restoring, false);
    expect(e.physics.centerY, greaterThan(.9));
    expect(e.surface.path.getBounds().height, lessThan(.18));
    expect(e.physics.kineticEnergy, lessThan(.01));
  });

  test('no sensor fallback is bounded and suspension never catches up', () {
    final e = WaterEngine(const WaterConfig());
    addTearDown(e.dispose);
    e.setViewport(.48);
    e.tick(1 / 60);
    e.suspend();
    e.resume();
    for (var i = 0; i < 5; i++) e.tick(.05);
    expect(e.restoring, false);
    expect(e.physics.centerY, greaterThan(.8));
    expect(e.physics.time, lessThan(.15));
  });

  test(
    'repeated resume uses upright inverted and landscape hydrostatic poses',
    () {
      final e = WaterEngine(const WaterConfig(fill: .08));
      addTearDown(e.dispose);
      e.setViewport(.48);
      final mass = e.physics.count;
      for (final g in [(0.0, 9.81), (9.81, 0.0), (0.0, -9.81), (-9.81, 0.0)]) {
        e.suspend();
        e.resume();
        e.motion.accept(g.$1, g.$2, 0, 0, 0);
        e.tick(1 / 120);
        expect(e.physics.count, mass);
        if (g.$2 > 0) expect(e.physics.centerY, greaterThan(.9));
        if (g.$2 < 0) expect(e.physics.centerY, lessThan(.1));
        if (g.$1 > 0) expect(e.physics.centerX, greaterThan(.44));
        if (g.$1 < 0) expect(e.physics.centerX, lessThan(.04));
      }
    },
  );

  test('eight percent flat water remains one finite puddle, not screen-wide mist', () {
    final p = LiquidPhysics(), s = LiquidSurface();
    void run(int n) {
      for (var i = 0; i < n; i++)
        p.step(1 / 60, fill: .08, viscosity: .22, aspect: .48);
    }

    run(180);
    final mass = p.count;
    p.gravity(0, 0, 9.81);
    run(600);
    s.rebuild(p);
    print(
      '8% puddle: area=${s.area / p.aspect} bounds=${s.path.getBounds()} contours=${s.contours} energy=${p.kineticEnergy}',
    );
    expect(p.coverage, inInclusiveRange(.23, .25));
    expect(s.area / p.aspect, inInclusiveRange(.20, .28));
    expect(s.path.getBounds().height, lessThan(.5));
    expect(s.contours, lessThanOrEqualTo(3));
    expect(p.layerDepth * p.coverage, closeTo(.08, 1e-9));
    expect(p.count, mass);
    p.gravity(0, 9.81);
    run(420);
    s.rebuild(p);
    expect(p.centerY, greaterThan(.92));
    expect(s.area / p.aspect, inInclusiveRange(.06, .10));
  });

  test('resuming face-up restores finite puddle at the same volume', () {
    final p = LiquidPhysics(), s = LiquidSurface();
    p.configure(.08, .48);
    p.gravity(0, 0, 9.81);
    p.settleAfterSuspension();
    s.rebuild(p);
    expect(p.coverage, inInclusiveRange(.23, .25));
    expect(s.path.getBounds().height, lessThan(.5));
    expect(p.layerDepth * p.coverage, closeTo(.08, 1e-9));
    expect(p.kineticEnergy, 0);
  });

  test(
    'flat hysteresis rejects threshold noise and preserves coverage on resize',
    () {
      final p = LiquidPhysics();
      p.configure(.08, .48);
      for (var i = 0; i < 100; i++) {
        p.gravity(i.isEven ? 1 : 3, 0, 9.5);
        p.step(1 / 60, fill: .08, viscosity: .22, aspect: .48);
      }
      expect(p.coverage, closeTo(.08, 1e-9));
      p.gravity(0, 0, 9.81);
      for (var i = 0; i < 300; i++)
        p.step(1 / 60, fill: .08, viscosity: .22, aspect: .48);
      final coverage = p.coverage, count = p.count;
      p.configure(.08, 2.1);
      expect(p.coverage, coverage);
      expect(p.count, count);
    },
  );

  test('gravity filter rejects noise without stopping deliberate tilt', () {
    final motion = WaterMotionInput();
    motion.accept(0, 9.81, 0, .01, -.02);
    for (var i = 0; i < 100; i++) {
      motion.accept(i.isEven ? .04 : -.04, 9.81, 0, .01, -.02);
      motion.advance(1 / 120);
    }
    expect(motion.gx.abs(), lessThan(.01));
    expect(motion.ax, 0);
    motion.accept(9.81, 0, 0, 0, 0);
    for (var i = 0; i < 24; i++) motion.advance(1 / 120);
    expect(motion.gx, greaterThan(9.7));
    motion.reset();
    motion.accept(0, -9.81, 0, 0, 0);
    expect(motion.gy, -9.81);
    expect(motion.ax, 0);
  });

  test(
    'optics stay continuous through reversal and integrate by elapsed time',
    () {
      final o = LiquidOptics();
      for (var i = 0; i < 60; i++) o.advance(1 / 60, 2, 0, .2);
      final before = o.offsetX;
      o.advance(1 / 60, -2, 0, .2);
      expect((o.offsetX - before).abs(), lessThan(.003));
      for (var i = 0; i < 60; i++) o.advance(1 / 60, -2, 0, .2);
      expect(o.offsetX, lessThan(before));
      final previous = o.offsetX;
      o.advance(double.nan, 0, 0, 0);
      expect(o.offsetX, previous);
    },
  );
}
