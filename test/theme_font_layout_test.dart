import 'package:better_phenikaa_schedule/features/giao_dien/xem_truoc/custom_theme_editor.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('font rộng giữ được bố cục tạo theme trên màn hình hẹp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final palette = appThemePalettes[AppThemeId.minecraft]!;
    final theme = buildBetterTheme(palette);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const CustomThemeEditor(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
