import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:better_phenikaa_schedule/app/bpa_pen_trace_splash.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_surface.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_fit_text.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_editor.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_page.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_routes.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/xem_truoc/theme_picker.dart';

void main() {
  testWidgets(
    'startup overlay is consumed on background and does not replay on resume',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: BpaPenTraceSplash(
            backgroundColor: Color(0xFF08040D),
            child: Scaffold(body: Text('Ứng dụng')),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(CustomPaint), findsWidgets);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BpaPenTracePainter,
        ),
        findsNothing,
      );
      expect(find.text('Ứng dụng'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real wide display font shrinks long subjects within their allocated region',
    (t) async {
      await t.runAsync(() async {
        final f = FontLoader('WideDisplayTest')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('test/fixtures/fonts/WideDisplay.otf').readAsBytes(),
              ),
            ),
          );
        await f.load();
      });
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 175,
                  child: WaterFitText(
                    'Lịch sử Đảng Cộng sản Việt Nam và Lập trình ứng dụng di động',
                    style: const TextStyle(
                      fontFamily: 'WideDisplayTest',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final text = t.widget<Text>(
        find.text(
          'Lịch sử Đảng Cộng sản Việt Nam và Lập trình ứng dụng di động',
        ),
      );
      expect(text.style!.fontSize, lessThan(16));
      expect(
        t.getSize(find.byType(WaterFitText)).height,
        lessThanOrEqualTo(42.1),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'GPU coolant is colored and inverted gravity moves it above, rounded corners reject taps',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(WaterEngine.warmup);
      final shot = GlobalKey(), block = GlobalKey();
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: shot,
            child: WaterStage(
              config: const WaterConfig(tilt: false),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: WaterBlock(
                    key: block,
                    width: 120,
                    constraints: const BoxConstraints.tightFor(height: 60),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const Text('Water'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 20));
      final e = WaterEngine.active!;
      expect(e.reservoirShader, isNotNull);
      for (final mode in LedMode.values) {
        e.update(const WaterConfig(tilt: false).patch({'mode': mode.name}));
        e.tick(1 / 60);
        await t.pump();
        expect(t.takeException(), isNull);
      }
      e.eventAge = 20;
      final rect = t.getRect(find.byKey(block));
      await t.tapAt(rect.center);
      await t.pump();
      expect(taps, 1);
      await t.tapAt(rect.topLeft + const Offset(1, 1));
      await t.pump();
      expect(taps, 1);
      e.eventAge = 20;
      e.update(const WaterConfig(tilt: false));
      e.physics.gravity(0, 9.81);
      for (var i = 0; i < 500; i++) {
        e.tick(1 / 60);
      }
      await t.pump();
      Future<List<int>> sample(String name) async {
        return t
            .runAsync(() async {
              final im =
                  await (shot.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await im.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final bytes = data!.buffer.asUint8List();
              final png = await im.toByteData(format: ui.ImageByteFormat.png);
              await File('/tmp/bpa-$name.png')
                  .writeAsBytes(png!.buffer.asUint8List());
              im.dispose();
              return bytes.toList();
            })
            .then((v) => v!);
      }

      final normal = await sample('water-recovered');
      final top = (40 * 390 + 375) * 4, bottom = (780 * 390 + 375) * 4;
      expect(
        normal[bottom] + normal[bottom + 2],
        greaterThan(normal[top] + normal[top + 2] + 30),
      );
      e.physics.gravity(0, -9.81);
      for (var i = 0; i < 500; i++) {
        e.tick(1 / 60);
      }
      await t.pump();
      final inverted = await sample('water-recovered-inverted');
      expect(
        inverted[top] + inverted[top + 2],
        greaterThan(inverted[bottom] + inverted[bottom + 2] + 30),
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Water-only route has persistent live preview, no AppBar and one Apply',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await t.runAsync(() async {
        final f = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('test/fixtures/fonts/Roboto.ttf').readAsBytes(),
              ),
            ),
          );
        await f.load();
      });
      SharedPreferences.setMockInitialValues({});
      final c = AppThemeController.instance;
      await c.applyWater(const WaterConfig(tilt: false));
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      Future<void> frames() async {
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 40));
        }
      }

      await t.pumpWidget(
        AnimatedBuilder(
          animation: c,
          builder: (context, _) => MaterialApp(
            navigatorObservers: [WaterRouteObserver.instance],
            theme: buildBetterTheme(c.palette),
            builder: (context, child) =>
                WaterStage(config: c.waterConfig, child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAppThemePicker(context),
                  child: const Text('Mở Theme'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Mở Theme'));
      await frames();
      expect(find.byType(WaterEditor), findsNothing);
      expect(find.byKey(const ValueKey('water-live-preview')), findsNothing);
      expect(find.text('Giao diện'), findsOneWidget);
      final edit = find.byKey(const ValueKey('edit-water-cooling'));
      expect(edit, findsOneWidget);
      expect(t.getRect(edit).top, lessThan(400));
      final configBefore = c.waterConfig;
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -1000));
      await frames();
      final tile = find.byKey(const ValueKey('water-cooling-theme-tile'));
      await t.ensureVisible(tile);
      await frames();
      await t.tap(tile);
      await frames();
      expect(find.byType(WaterCoolingPage), findsNothing);
      expect(identical(c.waterConfig, configBefore), true);
      await t.tap(edit);
      await frames();
      expect(find.byType(WaterCoolingPage), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Lưu & Áp dụng'), findsOneWidget);
      expect(find.byKey(const ValueKey('water-live-preview')), findsOneWidget);
      final engine = WaterEngine.active!, before = engine.physics.centerX;
      await t.drag(
        find.byKey(const ValueKey('water-live-preview')),
        const Offset(100, -45),
      );
      await frames();
      expect(engine.physics.centerX, (isNot(closeTo(before, .0001))));
      final controller = find.byType(DropdownButtonFormField<LedMode>);
      await t.ensureVisible(controller);
      await frames();
      await t.tap(controller);
      await frames();
      await t.tap(find.text('Tĩnh').last);
      await frames();
      final color = find.byTooltip('Màu LED 1');
      await t.ensureVisible(color);
      await t.tap(color);
      await frames();
      expect(find.byKey(const ValueKey('rgb-gamut-board')), findsOneWidget);
      await t.tap(find.text('Hủy'));
      await frames();
      final previewRect = t.getRect(
        find.byKey(const ValueKey('water-live-preview')),
      );
      await t.drag(
        find.byKey(const ValueKey('water-settings-scroll')),
        const Offset(0, -700),
      );
      await frames();
      expect(
        t.getRect(find.byKey(const ValueKey('water-live-preview'))),
        previewRect,
      );
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('Xem nước toàn màn hình'));
      await frames();
      expect(find.byTooltip('Đóng xem trước'), findsOneWidget);
      await t.tap(find.byTooltip('Đóng xem trước'));
      await frames();
      await t.tap(find.text('Lưu & Áp dụng'));
      await frames();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await frames();
      expect(find.byType(WaterCoolingPage), findsNothing);
      expect(c.theme, AppThemeId.waterCooling);
      await c.select(AppThemeId.classic);
      await frames();
      expect(find.byKey(const ValueKey('edit-water-cooling')), findsNothing);
      expect(find.byType(WaterEditor), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
