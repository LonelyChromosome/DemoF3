import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/liquid_physics.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_field.dart';

void main() {
  test(
    'equal-mass fluid moves through 90/180 degrees without losing samples',
    () {
      final p = LiquidPhysics();
      void run(int n) {
        for (var i = 0; i < n; i++) {
          p.step(1 / 60, fill: .32, viscosity: .22, aspect: .48);
        }
      }

      run(240);
      final mass = p.count;
      expect(p.centerY, greaterThan(.78));
      p.gravity(9.81, 0);
      run(240);
      expect(p.centerX, greaterThan(.37));
      expect(p.count, mass);
      p.gravity(0, -9.81);
      run(300);
      expect(p.centerY, lessThan(.23));
      expect(p.count, mass);
      for (var i = 0; i < p.count; i++) {
        expect(p.x[i].isFinite && p.y[i].isFinite, true);
        expect(p.x[i], inInclusiveRange(0, p.aspect));
        expect(p.y[i], inInclusiveRange(0, 1));
      }
    },
  );
  test(
    'shake adds momentum and water dissipates it instead of rotating a slab',
    () {
      final p = LiquidPhysics();
      void run(int n) {
        for (var i = 0; i < n; i++) {
          p.step(1 / 60, fill: .32, viscosity: 1, aspect: .48);
        }
      }

      run(240);
      final initial = p.kineticEnergy, mass = p.count;
      p.acceleration(-45, 35);
      run(10);
      final shaken = p.kineticEnergy;
      expect(shaken, greaterThan(initial + .05));
      expect(p.count, mass);
      run(600);
      expect(p.kineticEnergy, lessThan(shaken * .25));
      p.gravity(-9.81, 0);
      run(240);
      expect(
        p.centerX,
        lessThan(.14),
        reason: 'highest viscosity must still flow',
      );
      expect(p.count, mass);
    },
  );
  test('test2 configuration and photos roundtrip without halving quantity', () {
    final c = const WaterConfig().patch({
      'mode': 'rainbowLine',
      'fontId': 'batman_forever',
      'widgets': {'widget2ImagePath': '/private/user-photo.jpg'},
    });
    final result = WaterConfig.fromJson(Map<String, dynamic>.from(c.toJson()));
    expect(result.toJson(), c.toJson());
    expect(result.fill, .32);
    expect(result.widgets.widget2ImagePath, '/private/user-photo.jpg');
    final old = Map<String, dynamic>.from(c.toJson())
      ..['schema'] = 1
      ..['fill'] = .64;
    expect(WaterConfig.fromJson(old).fill, .32);
  });
  test('all eleven modes share world position and obey brightness', () {
    for (final mode in LedMode.values) {
      final c = const WaterConfig().patch({'mode': mode.name});
      expect(
        MasterRgbField.sample(c, .3, .4, 2),
        MasterRgbField.sample(c, 300 / 1000, 400 / 1000, 2),
      );
      expect(
        MasterRgbField.sample(c.patch({'brightness': 0}), .3, .4, 2),
        Colors.black,
      );
    }
    final c = const WaterConfig().patch({'mode': 'rainbowLine'});
    expect(
      MasterRgbField.sample(c, .1, .2, 0),
      isNot(MasterRgbField.sample(c, .3, .2, 0)),
    );
  });
}
