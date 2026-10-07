import 'package:better_phenikaa_schedule/features/app_update/update_controller.dart';
import 'package:better_phenikaa_schedule/features/app_update/update_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual update requires displayed name before hold', (tester) async {
    final controller = UpdateController()
      ..notice = UpdateNotice(31, 'cooc.1.2', 'Bản thử', DateTime.utc(2026))
      ..phase = UpdatePhase.available;
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UpdateFlowSheet(controller: controller, displayName: 'Nguyễn Văn A'),
      ),
    ));
    await tester.tap(find.text('Cập nhật thủ công'));
    await tester.pump();

    FilledButton holdButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Giữ để tiếp tục'),
    );
    expect(holdButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Nguyễn Văn B');
    await tester.pump();
    expect(holdButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Nguyễn Văn A');
    await tester.pump();
    expect(holdButton().onPressed, isNotNull);
  });
}
