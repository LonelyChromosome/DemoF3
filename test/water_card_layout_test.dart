import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_engine.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/attendance_tag.dart';

void main() {
  testWidgets(
    'long Batman title leaves full room and badge beside a 44px alarm on portrait/landscape',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await t.runAsync(() async {
        final bat = FontLoader('BatmanForever')
          ..addFont(
            rootBundle.load('assets/fonts/SVN-Batman-Forever-Alternate.otf'),
          );
        await bat.load();
        final font = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('test/fixtures/fonts/Roboto.ttf').readAsBytes(),
              ),
            ),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        await WaterEngine.warmup();
      });
      const subject = 'Lập trình cho thiết bị di động',
          room = 'A6-403.404 (PC)',
          route = 'water-test-route';
      final now = DateTime.now(),
          start = DateTime.now().add(const Duration(hours: 2));
      final data = ImportedScheduleData(
        displayName: 'Sinh viên',
        syncedAt: now,
        records: [
          ScheduleRecord(
            id: 'mobile',
            isExam: false,
            subjectName: subject,
            room: room,
            startAt: start,
            endAt: start.add(const Duration(hours: 2)),
            periodStart: 1,
            periodEnd: 3,
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'better_phenikaa_snapshot_v1': data.encode(),
        'better_phenikaa_qldt_registration_route_v1': route,
        'better_phenikaa_theme_v3': 'water_cooling',
        'bpa_water_cooling_applied_v1': jsonEncode(
          const WaterConfig(tilt: false)
              .patch({'fontId': 'batman_forever'})
              .toJson(),
        ),
        'better_phenikaa_attendance_v17': jsonEncode({
          'schema': 3,
          'route': route,
          'counts': {
            normalizeSubjectName(subject): {
              'absentSessions': 2,
              'totalTheorySessions': 15,
            },
          },
        }),
      });
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final shot = GlobalKey();
      var pass = 0;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      for (final size in [
        const Size(360, 800),
        const Size(360, 800),
        const Size(800, 360),
      ]) {
        t.view.physicalSize = size;
        t.platformDispatcher.textScaleFactorTestValue = pass++ == 0 ? 1 : 1.4;
        await t.pumpWidget(
          RepaintBoundary(key: shot, child: const BetterPhenikaaScheduleApp()),
        );
        for (var i = 0; i < 35; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(find.text(subject), findsOneWidget);
        expect(find.text(room), findsOneWidget);
        final alarm = find.byKey(const ValueKey('alarm-open-mobile'));
        expect(alarm, findsOneWidget);
        expect(t.getSize(alarm), const Size(44, 44));
        final badge = find.byType(AttendanceTag).first;
        expect(
          t.getRect(find.text(room)).right,
          lessThan(t.getRect(alarm).left - 7),
        );
        expect(t.getRect(badge).right, lessThan(t.getRect(alarm).left - 7));
        final paragraph = t.renderObject<RenderParagraph>(find.text(room));
        expect(paragraph.didExceedMaxLines, false);
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final im =
              await (shot.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await im.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/bpa-test4-card-${size.width.toInt()}-$pass.png')
              .writeAsBytes(png!.buffer.asUint8List());
          im.dispose();
        });
      }
      await t.pumpWidget(const SizedBox());
      await t.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
