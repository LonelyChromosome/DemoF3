import 'package:shared_preferences/shared_preferences.dart';

enum AssistantPack {
  normal._('Bình thường'),
  serious._('Nghiêm túc'),
  playful._('Nhí nhảnh'),
  affectionate._('Tình cảm'),
  flirtatious._('Lẳng lơ'),
  academic._('Học thuật');

  AssistantPack._(this.label);
  final String label;
}

enum AssistantEvent {
  syncInitial,
  syncStale,
  syncSuccessNoChange,
  studyChanged,
  examChanged,
  studyAndExamChanged,
  examInDays,
  examTomorrow,
  examPeriodActive,
  examCountdownMultiple,
}

/// One pack governs all in-app messages and Android notifications.
abstract final class AssistantSelection {
  static const storageKey = 'better_phenikaa_assistant_pack_v1';

  static Future<AssistantPack> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AssistantPack.values.firstWhere(
      (pack) => pack.name == prefs.getString(storageKey),
      orElse: () => AssistantPack.normal,
    );
  }

  static Future<void> save(AssistantPack pack) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, pack.name);
  }
}

abstract final class AssistantText {
  static String titleOf(AssistantEvent event, AssistantPack pack) =>
      switch (event) {
        AssistantEvent.syncStale => 'Nhắc đồng bộ',
        AssistantEvent.syncInitial ||
        AssistantEvent.syncSuccessNoChange ||
        AssistantEvent.studyChanged ||
        AssistantEvent.examChanged ||
        AssistantEvent.studyAndExamChanged => 'Đồng bộ QLĐT',
        AssistantEvent.examInDays ||
        AssistantEvent.examTomorrow ||
        AssistantEvent.examCountdownMultiple ||
        AssistantEvent.examPeriodActive => 'Lịch thi',
      };

  static String of(
    AssistantEvent event,
    AssistantPack pack, {
    int days = 0,
    int examCount = 1,
  }) {
    // Packs without a localized entry use the normal wording.
    return switch (event) {
      AssistantEvent.syncInitial => 'Đã lưu dữ liệu học kỳ đầu tiên.',
      AssistantEvent.syncStale =>
        'Bạn nên đồng bộ lại để đảm bảo tính chính xác của dữ liệu.',
      AssistantEvent.syncSuccessNoChange =>
        'Đồng bộ thành công. Lịch không đổi.',
      AssistantEvent.studyChanged =>
        'Lịch học đã thay đổi. Chạm chuông để xem chi tiết.',
      AssistantEvent.examChanged =>
        'Lịch thi đã thay đổi. Chạm chuông để xem chi tiết.',
      AssistantEvent.studyAndExamChanged =>
        'Lịch học và lịch thi đã thay đổi. Chạm chuông để xem chi tiết.',
      AssistantEvent.examInDays when examCount > 1 =>
        '$days ngày nữa bạn có $examCount môn thi.',
      AssistantEvent.examInDays => '$days ngày nữa bạn có một môn thi.',
      AssistantEvent.examTomorrow when examCount > 1 =>
        'Ngày mai bạn có $examCount môn thi.',
      AssistantEvent.examTomorrow => 'Ngày mai bạn có một môn thi.',
      AssistantEvent.examPeriodActive =>
        'Bạn đang trong kỳ thi. Hãy vào Lịch thi để kiểm tra.',
      AssistantEvent.examCountdownMultiple =>
        'Bạn có $examCount môn thi sắp tới.',
    };
  }
}
