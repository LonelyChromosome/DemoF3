final class SyncReminderPolicy {
  const new();

  bool shouldRemind({
    required DateTime now,
    required DateTime? lastSuccessfulSync,
    required DateTime? lastReminder,
  }) {
    if (lastSuccessfulSync == null) return false;
    final dueAt = lastSuccessfulSync.add(const Duration(days: 3));
    if (now.isBefore(dueAt)) return false;
    return lastReminder == null ||
        lastReminder.isBefore(lastSuccessfulSync) ||
        now.difference(lastReminder) >= const Duration(days: 3);
  }
}
