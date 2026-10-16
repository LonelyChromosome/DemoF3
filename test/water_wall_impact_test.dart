import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_physics.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_surface.dart';

void main() {
  for (final viscosity in [.22, 1.0]) {
    test('wall splashes drain after inversion at viscosity $viscosity', () {
      final p = LiquidPhysics(), surface = LiquidSurface();
      void run(int steps) {
        for (var i = 0; i < steps; i++) {
          p.step(1 / 120, fill: .32, viscosity: viscosity, aspect: .48);
        }
      }

      run(480);
      final mass = p.count;
      expect(p.kineticEnergy, lessThan(.015));
      for (var i = 0; i < 120; i++) {
        if (i < 15) p.acceleration(-45, 45);
        if (i == 30) p.gravity(9.81, 0);
        if (i == 60) p.gravity(0, -9.81);
        if (i == 90) p.gravity(0, 9.81);
        run(1);
      }
      run(120);
      var highAtWall = 0;
      for (var i = 0; i < p.count; i++) {
        if (math.min(p.x[i], p.aspect - p.x[i]) < p.spacing * 2 &&
            p.y[i] < .5) {
          highAtWall++;
        }
      }
      expect(
        highAtWall,
        lessThanOrEqualTo(3),
        reason: 'isolated drops may fall; a wall column must drain',
      );
      run(600);
      surface.rebuild(p);
      expect(p.count, mass);
      expect(p.kineticEnergy, lessThan(.02));
      expect(surface.path.getBounds().top, greaterThan(.60));
      expect(surface.area / p.aspect, inInclusiveRange(.30, .34));
    });
  }

  test('pressure corrections cannot create unbounded impact speed', () {
    final p = LiquidPhysics();
    p.configure(.32, .48);
    for (var frame = 0; frame < 240; frame++) {
      if (frame % 30 == 0) {
        p.gravity((frame ~/ 30).isEven ? 9.81 : -9.81, 0);
        p.acceleration(-55, 55);
      }
      p.step(1 / 120, fill: .32, viscosity: .22, aspect: .48);
      for (var i = 0; i < p.count; i++) {
        expect(
          p.vx[i] * p.vx[i] + p.vy[i] * p.vy[i],
          lessThanOrEqualTo(3.5 * 3.5 + 1e-9),
        );
      }
    }
  });
}
