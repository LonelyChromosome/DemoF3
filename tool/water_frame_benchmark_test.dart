// Host CPU comparison only; this is not an Android FPS measurement.
import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_physics.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_surface.dart';

void main() {
  test('measure solver and density reconstruction at equal quality', () {
    for (final flat in [false, true]) {
      final p = LiquidPhysics(), s = LiquidSurface();
      for (var i = 0; i < 90; i++)
        p.step(1 / 60, fill: .32, viscosity: .22, aspect: .48);
      if (flat) p.gravity(0, 0, 9.81);
      final solver = <int>[], surface = <int>[];
      final w = Stopwatch();
      for (var i = 0; i < 180; i++) {
        if (!flat && i % 45 == 0) {
          p.gravity(i % 90 == 0 ? 9.81 : -9.81, 0);
          p.acceleration(-25, 30);
        }
        w
          ..reset()
          ..start();
        p.step(1 / 60, fill: .32, viscosity: .22, aspect: .48);
        w.stop();
        solver.add(w.elapsedMicroseconds);
        w
          ..reset()
          ..start();
        s.rebuild(p);
        w.stop();
        surface.add(w.elapsedMicroseconds);
      }
      String stats(List<int> v) {
        v.sort();
        return 'median=${v[v.length ~/ 2]}us p95=${v[(v.length * .95).floor()]}us mean=${v.reduce((a, b) => a + b) / v.length}us';
      }

      print(
        'BENCH ${flat ? 'flat' : 'tilt'} particles=${p.count} grid=${s.cols}x${s.rows} solver ${stats(solver)} surface ${stats(surface)}',
      );
    }
  });
}
