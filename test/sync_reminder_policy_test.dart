import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/sync_reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SyncReminderPolicy();
  final sync = DateTime(2026, 9, 20, 15);

  test('does not remind before three days or without a successful sync', () {
    expect(
      policy.shouldRemind(
        now: sync.add(const Duration(days: 2)),
        lastSuccessfulSync: sync,
        lastReminder: null,
      ),
      isFalse,
    );
    expect(
      policy.shouldRemind(
        now: sync.add(const Duration(days: 4)),
        lastSuccessfulSync: null,
        lastReminder: null,
      ),
      isFalse,
    );
  });

  test(
    'a successful sync resets reminder age; repeated reminders are spaced',
    () {
      final due = sync.add(const Duration(days: 3));
      expect(
        policy.shouldRemind(
          now: due,
          lastSuccessfulSync: sync,
          lastReminder: sync.subtract(const Duration(days: 1)),
        ),
        isTrue,
      );
      expect(
        policy.shouldRemind(
          now: due.add(const Duration(hours: 1)),
          lastSuccessfulSync: sync,
          lastReminder: due,
        ),
        isFalse,
      );
      expect(
        policy.shouldRemind(
          now: due.add(const Duration(days: 3)),
          lastSuccessfulSync: sync,
          lastReminder: due,
        ),
        isTrue,
      );
    },
  );
}
