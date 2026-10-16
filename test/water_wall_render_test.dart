import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_surface.dart';

void main() {
  testWidgets('rendered wall column falls after returning upright', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.runAsync(WaterEngine.warmup);
    final shot = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: shot,
          child: const WaterStage(
            config: WaterConfig(tilt: false),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await t.pump();
    final e = WaterEngine.active!;
    for (var i = 0; i < 180; i++) e.tick(1 / 60);
    // Hold sideways long enough to form a column, then stand upright.
    e.physics.gravity(9.81, 0);
    for (var i = 0; i < 180; i++) e.tick(1 / 60);
    e.physics.gravity(0, 9.81);
    const record = bool.fromEnvironment('WATER_RECORD_WALL');
    if (record) {
      await t.runAsync(
        () => Directory('/tmp/bpa-test6r2-wall').create(recursive: true),
      );
    }
    for (var i = 0; i < 120; i++) {
      e.tick(1 / 60);
      await t.pump();
      expect(t.takeException(), isNull);
      if (record && i % 6 == 0) {
        await t.runAsync(() async {
          final im =
              await (shot.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/bpa-test6r2-wall/${i.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          im.dispose();
        });
      }
    }
    // Falling detached drops can remain above the pool; do not mistake one
    // drop's bounding box for a continuous wall column.
    for (final x in [.015, e.physics.aspect - .015]) {
      var wet = 0;
      for (var y = .1; y <= .5; y += .02) {
        if (e.surface.path.contains(Offset(x, y))) wet++;
      }
      expect(wet, lessThanOrEqualTo(3));
    }
    for (var i = 0; i < 240; i++) e.tick(1 / 60);
    await t.pump();
    expect(e.surface.path.getBounds().top, greaterThan(.60));
    expect(e.surface.area / e.physics.aspect, inInclusiveRange(.30, .34));
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
}
