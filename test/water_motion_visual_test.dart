import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_surface.dart';

void main() {
  testWidgets(
    'actual GPU fluid stays finite through wall impacts, inversion, flat spread and draining',
    (t) async {
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
      e.eventAge = 20;
      for (var i = 0; i < 180; i++) {
        e.tick(1 / 60);
      }
      await t.pump();
      const record = bool.fromEnvironment('WATER_RECORD_MOTION');
      if (record)
        await t.runAsync(
          () => Directory('/tmp/bpa-test4-motion').create(recursive: true),
        );
      var separate = 0;
      for (var i = 0; i < 180; i++) {
        if (i == 0) {
          e.physics.gravity(9.81, 0);
          e.physics.acceleration(-35, 25);
        }
        if (i == 30) {
          e.physics.gravity(0, -9.81);
          e.physics.acceleration(30, 35);
        }
        if (i == 60) e.physics.gravity(0, 0, 9.81);
        if (i == 120) e.physics.gravity(0, 9.81);
        e.tick(1 / 30);
        await t.pump();
        if (e.surface.contours > separate) separate = e.surface.contours;
        expect(e.surface.path.getBounds().isFinite, true);
        expect(t.takeException(), isNull);
        if (record) {
          await t.runAsync(() async {
            final im =
                await (shot.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await im.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/tmp/bpa-test4-motion/${i.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            im.dispose();
          });
        }
      }
      expect(separate, greaterThan(1));
      expect(e.physics.centerY, greaterThan(.7));
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
}
