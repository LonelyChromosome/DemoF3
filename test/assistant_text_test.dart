import 'package:better_phenikaa_schedule/features/tro_li/assistant_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normal is default; one persisted choice survives reload', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AssistantSelection.load(), AssistantPack.normal);
    await AssistantSelection.save(AssistantPack.academic);
    expect(await AssistantSelection.load(), AssistantPack.academic);
  });

  test('missing pack copy falls back without changing event logic', () {
    for (final pack in AssistantPack.values) {
      expect(AssistantText.of(AssistantEvent.syncStale, pack), isNotEmpty);
      expect(AssistantText.of(AssistantEvent.examInDays, pack,
        days: 5, examCount: 2), contains('5 ngày'));
    }
  });
}
