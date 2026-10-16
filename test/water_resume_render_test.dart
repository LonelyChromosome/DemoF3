import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_surface.dart';

void main() {
  testWidgets(
    'Android event channel and GPU recover bottom water after background pose change',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const channel = MethodChannel('better_phenikaa/water_gravity');
      var listens = 0, cancels = 0;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'listen') listens++;
        if (call.method == 'cancel') cancels++;
        return null;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      Future<void> sensor(List<double> sample) async {
        await t.binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeSuccessEnvelope(sample),
          (_) {},
        );
      }

      await t.runAsync(WaterEngine.warmup);
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const WaterStage(
              config: WaterConfig(fill: .08),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await t.pump();
      await sensor([9.81, 0, 0, 0, 0]);
      await t.pump(const Duration(milliseconds: 20));
      final e = WaterEngine.active!;
      e.eventAge = 20;
      for (var i = 0; i < 180; i++) e.tick(1 / 60);
      expect(e.physics.centerX, greaterThan(.44));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 60));
      final stopped = e.physics.time;
      await t.pump(const Duration(seconds: 60));
      expect(e.physics.time, stopped);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      expect(e.restoring, true);
      await sensor([0, 9.81, 0, 0, 0]);
      await t.pump(const Duration(milliseconds: 20));
      e.rebuildSurface();
      expect(e.physics.centerY, greaterThan(.9));
      expect(e.surface.path.getBounds().height, lessThan(.18));
      expect(listens, 2);
      expect(cancels, 1);
      Future<void> capture(String file) async {
        await t.runAsync(() async {
          final im =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await im.toByteData(format: ui.ImageByteFormat.png);
          await File(file).writeAsBytes(png!.buffer.asUint8List());
          im.dispose();
        });
      }

      await capture('/tmp/bpa-test6r-resume.png');
      await sensor([0, 0, 0, 0, 9.81]);
      for (var i = 0; i < 600; i++) e.tick(1 / 60);
      await t.pump();
      expect(e.surface.contours, lessThanOrEqualTo(3));
      expect(e.surface.path.getBounds().height, lessThan(.5));
      await capture('/tmp/bpa-test6r-lowflat.png');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
