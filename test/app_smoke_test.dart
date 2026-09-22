import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots into the official QLDT login flow', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const BetterPhenikaaScheduleApp());

    expect(find.text('Better Phenikaa App'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng bạn!'), findsOneWidget);
    expect(find.textContaining('Đăng nhập QLĐT'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('mockup'), findsNothing);
  });
}
