import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_physics.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_surface.dart';

void main() {
  test(
    'density surface separates under impact and rejoins without changing mass',
    () {
      final p = LiquidPhysics(), s = LiquidSurface();
      void step() {
        p.step(1 / 60, fill: .32, viscosity: .22, aspect: .48);
      }

      for (var i = 0; i < 240; i++) {
        step();
      }
      s.rebuild(p);
      final before = s.area, mass = p.count;
      print('settled contours=${s.contours}, area=$before');
      var peak = 0, maxArea = 0.0, minArea = 10.0;
      for (var i = 0; i < 180; i++) {
        if (i < 10) p.acceleration(-45, 45);
        if (i == 25) p.gravity(9.81, 0);
        if (i == 65) {
          p.gravity(0, -9.81);
          p.acceleration(40, -40);
        }
        if (i == 100) {
          p.gravity(0, 9.81);
          p.acceleration(-45, 35);
        }
        step();
        s.rebuild(p);
        if (s.contours > peak) peak = s.contours;
        if (s.area > maxArea) maxArea = s.area;
        if (s.area < minArea) minArea = s.area;
        expect(p.count, mass);
        expect(s.path.getBounds().isFinite, true);
      }
      print('impact peak contours=$peak, area=$minArea..$maxArea');
      expect(peak, greaterThan(1));
      p.gravity(0, 9.81);
      for (var i = 0; i < 600; i++) {
        step();
      }
      s.rebuild(p);
      print('rejoined contours=${s.contours}, area=${s.area}');
      expect(s.area, closeTo(before, .02));
      expect(s.path.contains(Offset(.24, .9)), true);
      expect(s.path.contains(Offset(.24, .1)), false);
    },
  );
  test('landscape and face-up layer spread over the new surface then drain upright', () {
    final p = LiquidPhysics(), s = LiquidSurface();
    void run(int n, double aspect) {
      for (var i = 0; i < n; i++) {
        p.step(1 / 60, fill: .32, viscosity: .22, aspect: aspect);
      }
    }

    run(180, .48);
    final mass = p.count;
    run(240, 2.2);
    s.rebuild(p);
    expect(s.area / p.aspect, inInclusiveRange(.27, .38));
    expect(p.centerY, greaterThan(.78));
    expect(p.count, mass);
    p.gravity(0, 0, 9.81);
    run(360, 2.2);
    s.rebuild(p);
    print(
      'flat: coverage=${p.coverage} rendered=${s.area / p.aspect}, depth=${p.layerDepth}',
    );
    expect(p.coverage, inInclusiveRange(.59, .62));
    expect(s.area / p.aspect, inInclusiveRange(.55, .65));
    expect(p.coverage * p.layerDepth, closeTo(.32, .00001));
    expect(p.count, mass);
    p.gravity(0, 9.81);
    run(420, .48);
    s.rebuild(p);
    expect(p.centerY, greaterThan(.78));
    expect(s.area / p.aspect, inInclusiveRange(.27, .38));
    expect(p.count, mass);
  });
}
