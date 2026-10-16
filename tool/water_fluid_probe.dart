import '../lib/features/giao_dien/water_cooling/liquid_physics.dart';

void main() {
  final p = LiquidPhysics();
  final watch = Stopwatch()..start();
  var frames = 0;
  void run(int n) {
    for (var i = 0; i < n; i++) {
      p.step(1 / 60, fill: .32, viscosity: .22, aspect: .48);
      frames++;
    }
  }

  void report(String name) {
    print(
      '$name n=${p.count} center=(${p.centerX.toStringAsFixed(3)},${p.centerY.toStringAsFixed(3)}) energy=${p.kineticEnergy.toStringAsFixed(5)}',
    );
  }

  run(240);
  report('settled');
  p.gravity(9.81, 0);
  run(240);
  report('right');
  p.gravity(0, -9.81);
  run(240);
  report('up');
  p.acceleration(-45, 40);
  run(12);
  report('shake');
  p.gravity(0, 9.81);
  run(480);
  report('re-settled');
  watch.stop();
  print(
    'host solve: ${watch.elapsedMicroseconds / frames / 1000} ms/frame ($frames frames)',
  );
  for (var i = 0; i < p.count; i++) {
    assert(
      p.x[i].isFinite &&
          p.y[i].isFinite &&
          p.x[i] >= 0 &&
          p.x[i] <= p.aspect &&
          p.y[i] >= 0 &&
          p.y[i] <= 1,
    );
  }
}
