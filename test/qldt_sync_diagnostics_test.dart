import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_sync_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records only stage, time, and fixed result code', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var now = DateTime.utc(2026, 9, 24, 1);
    final trail = QldtSyncDiagnostics(clock: () => now);
    trail.start(QldtSyncPhase.schedule);
    now = now.add(const Duration(seconds: 2));
    trail.start(QldtSyncPhase.navigation);
    now = now.add(const Duration(seconds: 20));
    trail.finish('NAVIGATION_TIMEOUT');
    await trail.flushed;

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(
      prefs.getString(QldtSyncDiagnostics.storageKey)!,
    ) as List<dynamic>;
    expect(stored, hasLength(2));
    expect(stored[0], containsPair('code', 'OK'));
    expect(stored[1], containsPair('code', 'NAVIGATION_TIMEOUT'));
    expect(stored[1], containsPair('startedAt', '2026-09-24T01:00:02.000Z'));
    expect(stored[1], containsPair('endedAt', '2026-09-24T01:00:22.000Z'));
    expect(
      stored[1].keys,
      containsAll(<String>['phase', 'startedAt', 'endedAt', 'code']),
    );
  });
}
