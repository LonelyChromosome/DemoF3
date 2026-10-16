import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';

void main() {
  test('jittering display intervals preserve the same physical trajectory', () {
    final regular = WaterEngine(const WaterConfig(tilt: false));
    final jitter = WaterEngine(const WaterConfig(tilt: false));
    addTearDown(regular.dispose);
    addTearDown(jitter.dispose);
    regular.setViewport(.48);
    jitter.setViewport(.48);
    regular.physics.gravity(9.81, 0);
    jitter.physics.gravity(9.81, 0);
    for (var i = 0; i < 120; i++) {
      regular.tick(1 / 60);
      jitter.tick(i.isEven ? .016 : 1 / 30 - .016);
    }
    expect(jitter.physics.time, closeTo(regular.physics.time, 1e-9));
    expect(jitter.physics.count, regular.physics.count);
    for (var i = 0; i < regular.physics.count; i++) {
      expect(jitter.physics.x[i], closeTo(regular.physics.x[i], 1e-9));
      expect(jitter.physics.y[i], closeTo(regular.physics.y[i], 1e-9));
    }
  });
  test(
    'a display frame between solver steps still advances the rendered water',
    () {
      final engine = WaterEngine(const WaterConfig(tilt: false));
      addTearDown(engine.dispose);
      engine.setViewport(.48);
      for (var i = 0; i < 90; i++) {
        engine.tick(1 / 60);
      }
      engine.physics.impulse(.4);
      engine.tick(1 / 120);
      engine.tick(.001);
      engine.rebuildSurface();
      final field = engine.surface.field.toList();
      final time = engine.physics.time;
      engine.tick(.001);
      engine.rebuildSurface();
      expect(engine.physics.time, time);
      var difference = 0.0;
      for (var i = 0; i < engine.surface.cols * engine.surface.rows; i++) {
        difference += (field[i] - engine.surface.field[i]).abs();
      }
      expect(difference, greaterThan(.001));
    },
  );
}
