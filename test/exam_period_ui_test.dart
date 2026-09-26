import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_source.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppThemeController.instance.resetAfterLogout();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppThemeController.instance.resetAfterLogout();
  });

  ScheduleRecord exam(DateTime start, DateTime end) => ScheduleRecord(
    id: 'exam',
    isExam: true,
    subjectName: 'Môn thi',
    room: 'A1',
    startAt: start,
    endAt: end,
  );

  Future<void> showApp(
    WidgetTester tester,
    List<ScheduleRecord> records,
  ) async {
    final snapshot = ImportedScheduleData(
      displayName: 'Sinh viên',
      records: records,
      syncedAt: DateTime.now(),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_snapshot_v1': snapshot.encode(),
    });
    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('empty or finished exams do not show the period badge', (
    tester,
  ) async {
    await showApp(tester, <ScheduleRecord>[]);
    expect(find.byKey(const ValueKey<String>('exam-period-dot')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await showApp(
      tester,
      <ScheduleRecord>[
        exam(yesterday.subtract(const Duration(hours: 2)), yesterday),
      ],
    );
    expect(find.byKey(const ValueKey<String>('exam-period-dot')), findsNothing);
  });

  testWidgets('period badge survives bell, exam page and app restore', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(days: 2));
    await showApp(
      tester,
      <ScheduleRecord>[exam(start, start.add(const Duration(hours: 2)))],
    );
    const dot = ValueKey<String>('exam-period-dot');
    expect(find.byKey(dot), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pump();
    expect(
      find.text('Bạn đang trong kỳ thi. Hãy vào Lịch thi để kiểm tra.'),
      findsOneWidget,
    );
    expect(find.byKey(dot), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byKey(dot), findsNWidgets(2));
    await tester.tap(find.text('Lịch thi').last);
    await tester.pumpAndSettle();
    expect(find.byKey(dot), findsOneWidget);
    expect(find.text('Còn 2 ngày'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await showApp(
      tester,
      <ScheduleRecord>[exam(start, start.add(const Duration(hours: 2)))],
    );
    expect(find.byKey(dot), findsOneWidget);
  });

  for (final theme in <AppThemeId>[
    AppThemeId.classic,
    AppThemeId.minecraft,
    AppThemeId.valorant,
  ]) {
    testWidgets('countdown fits and remains readable in $theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final start = DateTime.now().add(const Duration(days: 10));
      await showApp(
        tester,
        <ScheduleRecord>[exam(start, start.add(const Duration(hours: 2)))],
      );
      final selection = AppThemeController.instance.select(theme);
      await tester.pump(const Duration(milliseconds: 650));
      await selection;
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch thi').last);
      await tester.pumpAndSettle();
      expect(find.text('Còn 10 ngày'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('custom palette and wide custom font keep the tag within card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final start = DateTime.now().add(const Duration(days: 5));
    await showApp(
      tester,
      <ScheduleRecord>[exam(start, start.add(const Duration(hours: 2)))],
    );
    final custom = CustomThemeDefinition(
      id: 'exam-test',
      name: 'Custom',
      source: const ThemeSourceData.colorMix(
        colors: <Color>[Color(0xFF101820), Color(0xFF184878)],
        weights: <double>[60, 40],
      ),
      tokens: appThemePalettes[AppThemeId.valorant]!.toTokens(),
      font: AppFontChoice.builtIns[1],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final selection = AppThemeController.instance.applyCustomTheme(custom);
    await tester.pump(const Duration(milliseconds: 650));
    await selection;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch thi').last);
    await tester.pumpAndSettle();
    expect(find.text('Còn 5 ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
