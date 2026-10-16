import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/app/bpa_pen_trace_splash.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';

void main() {
  testWidgets(
    'real app restores Water, resumes cleanly and keeps schedule through theme changes',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        final loader = FontLoader('MinecraftCustom')
          ..addFont(
            rootBundle.load('assets/fonts/minecraft.ttf'),
          );
        await loader.load();
        final roboto = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('test/fixtures/fonts/Roboto.ttf').readAsBytes(),
              ),
            ),
          );
        await roboto.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        await WaterEngine.warmup();
      });
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = ImportedScheduleData(
        displayName: 'Sinh viên',
        syncedAt: now,
        records: [
          ScheduleRecord(
            id: 'long',
            isExam: false,
            subjectName: 'Lịch sử Đảng Cộng sản Việt Nam',
            room: 'ONLINE- Elearning',
            startAt: today.add(const Duration(hours: 21, minutes: 5)),
            endAt: today.add(const Duration(hours: 22)),
          ),
          ScheduleRecord(
            id: 'web',
            isExam: false,
            subjectName: 'Thiết kế web nâng cao',
            room: 'A6-205 (PC)',
            startAt: today.add(const Duration(hours: 9, minutes: 30)),
            endAt: today.add(const Duration(hours: 12, minutes: 10)),
          ),
        ],
      );
      final config = const WaterConfig(tilt: false)
          .patch({'fontId': 'minecraft', 'mode': 'rainbowLine'});
      SharedPreferences.setMockInitialValues({
        'better_phenikaa_snapshot_v1': snapshot.encode(),
        'better_phenikaa_theme_v3': 'water_cooling',
        'bpa_water_cooling_applied_v1': jsonEncode(config.toJson()),
      });
      final shot = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(key: shot, child: const BetterPhenikaaScheduleApp()),
      );
      for (var i = 0; i < 35; i++) {
        await t.pump(const Duration(milliseconds: 60));
      }
      expect(AppThemeController.instance.theme, AppThemeId.waterCooling);
      expect(WaterEngine.active, isNotNull);
      expect(find.text('Lịch sử Đảng Cộng sản Việt Nam'), findsOneWidget);
      expect(t.takeException(), isNull);
      Future<void> capture(String name) async {
        await t.runAsync(() async {
          final im =
              await (shot.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await im.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/bpa-' + name + '.png')
              .writeAsBytes(png!.buffer.asUint8List());
          im.dispose();
        });
      }

      await capture('app-test3');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 5));
      final stopped = WaterEngine.active!.seconds;
      await t.pump(const Duration(seconds: 1));
      expect(WaterEngine.active!.seconds, stopped);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BpaPenTracePainter,
        ),
        findsNothing,
      );
      expect(WaterEngine.active!.seconds, greaterThan(stopped));
      await AppThemeController.instance.select(AppThemeId.classic);
      await t.pump();
      expect(find.text('Lịch sử Đảng Cộng sản Việt Nam'), findsOneWidget);
      await AppThemeController.instance.applyWater(config);
      await t.pump();
      for (var i = 0; i < 35; i++) {
        await t.pump(const Duration(milliseconds: 60));
      }
      expect(find.text('Thiết kế web nâng cao'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Theo tuần'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull);
      await capture('app-week-test3');
      await t.tap(find.text('Theo ngày'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Lịch sử Đảng Cộng sản Việt Nam'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
