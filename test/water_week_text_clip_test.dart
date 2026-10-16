import 'dart:io';
import 'dart:ui' as ui;

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_surface.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'scrolling week text stays inside the acrylic rim without changing card geometry',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      t.view.physicalSize = const Size(320, 560);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        await (FontLoader('Roboto')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('test/fixtures/fonts/Roboto.ttf').readAsBytes(),
                ),
              ),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      SharedPreferences.setMockInitialValues({});
      await AppThemeController.instance.load();
      await AppThemeController.instance.applyWater(const WaterConfig());
      final date = DateTime(2026, 10, 12), shot = GlobalKey();
      final data = ImportedScheduleData(
        displayName: 'Test',
        syncedAt: date,
        records: [
          for (var i = 0; i < 4; i++)
            ScheduleRecord(
              id: 'course-$i',
              isExam: false,
              subjectName: 'Lập trình cho thiết bị di động $i',
              room: 'ONLINE- Elearning',
              startAt: date.add(Duration(hours: 7 + i * 2)),
              endAt: date.add(Duration(hours: 9 + i * 2)),
            ),
        ],
      );
      // No WaterStage/ARGB painter here: bright edge pixels can only be leaked
      // text, not a legitimate LED highlight. Use the actual weekly renderer.
      await t.pumpWidget(
        MaterialApp(
          theme: buildBetterTheme(appThemePalette),
          home: RepaintBoundary(
            key: shot,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: WeekTimetable(
                data: data,
                week: date,
                onWeekChanged: (_) {},
                onPickWeek: () {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final day = find.byType(WaterBlock).at(1);
      final rect = t.getRect(day);
      expect(rect.width, 320);
      final scroll = t.state<ScrollableState>(
        find.descendant(of: day, matching: find.byType(Scrollable)),
      );
      var interiorText = 0;
      for (final offset in [0.0, 11.0, 29.0, 57.0, 103.0]) {
        scroll.position.jumpTo(offset);
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final image =
              await (shot.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var leaked = 0;
          bool bright(int x, int y) {
            final i = (y * image.width + x) * 4;
            return rgba.getUint8(i) > 180 &&
                rgba.getUint8(i + 1) > 180 &&
                rgba.getUint8(i + 2) > 180;
          }

          for (
            var y = rect.top.ceil() + 10;
            y < rect.bottom.floor() - 10;
            y++
          ) {
            for (var x = rect.right.floor() - 3; x < rect.right.floor(); x++) {
              if (bright(x, y)) leaked++;
            }
            for (
              var x = rect.left.ceil() + 12;
              x < rect.right.floor() - 12;
              x++
            ) {
              if (bright(x, y)) interiorText++;
            }
          }
          image.dispose();
          expect(
            leaked,
            0,
            reason: 'text painted through rim at horizontal offset $offset',
          );
        });
        expect(t.takeException(), isNull);
      }
      expect(
        interiorText,
        greaterThan(50),
        reason: 'content must remain visible',
      );
      await t.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
