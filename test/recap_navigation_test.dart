import 'package:better_phenikaa_schedule/features/recap/recap_data.dart';
import 'package:better_phenikaa_schedule/features/recap/recap_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Recap navigates right forward, left backward, without next button',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final facts = RecapFixtures.build(
      RecapScenario.afterEnd, DateTime(2026, 10, 13),
    );
    await tester.pumpWidget(MaterialApp(
      home: SemesterRecapPage(load: () async => facts),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('BETTER PHENIKAA · FLASHBACK'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsNothing);
    expect(find.text('‹  TRÁI · LÙI'), findsOneWidget);

    // Tapping left on the first page is a no-op, not a dismiss.
    await tester.tapAt(const Offset(45, 540));
    await tester.pumpAndSettle();
    expect(find.text('BETTER PHENIKAA · FLASHBACK'), findsOneWidget);

    await tester.tapAt(const Offset(355, 540));
    await tester.pumpAndSettle();
    expect(find.text('MỘT KỲ HỌC'), findsOneWidget);
    expect(find.text('NGÀY ĐẾN TRƯỜNG'), findsOneWidget);
    expect(find.text('MÔN HỌC'), findsOneWidget);

    await tester.tapAt(const Offset(355, 540));
    await tester.pumpAndSettle();
    expect(find.text('BUỔI SÁNG'), findsOneWidget);
    expect(find.text('BUỔI CHIỀU'), findsOneWidget);

    await tester.tapAt(const Offset(45, 540));
    await tester.pumpAndSettle();
    expect(find.text('MỘT KỲ HỌC'), findsOneWidget);
  });
}
