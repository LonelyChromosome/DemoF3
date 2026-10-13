/// In-app history for the *installed* BPA version. This is independent from
/// the signed updater feed, whose notes describe a FUTURE available version.
/// Keep it visible in Notification Center even when the app is up to date.
final class NotificationChangelog {
  const NotificationChangelog({
    required this.versionName,
    required this.entries,
  });

  final String versionName;
  final List<String> entries;

  static NotificationChangelog forInstalledVersion(String installed) {
    final version = installed.trim();
    if (version == 'cooc.1.6') {
      return const NotificationChangelog(
        versionName: 'cooc.1.6',
        entries: [
          'Bổ sung VFX',
          'Báo thức',
          'Sửa lỗi',
        ],
      );
    }
    // Before Android returns PackageInfo, the bundled release is still 1.7.
    // The published 1.7 hotfix retains versionName but increments versionCode.
    if (version.isEmpty || version == 'cooc.1.7') {
      return const NotificationChangelog(
        versionName: 'cooc.1.7',
        entries: [
          'Bổ sung Recap nhìn lại học kỳ.',
          'Thống kê lịch học, ngày bận nhất và chuyên cần.',
          'Hiển thị tag số buổi nghỉ và Thực Hành trên lịch.',
          'Sửa lỗi Pull Reload timeout và cải thiện khôi phục phiên QLĐT.',
          'Hoàn thiện giao diện và sửa lỗi.',
        ],
      );
    }
    // Do not mislabel a future installed release with the old 1.7 log.
    return NotificationChangelog(
      versionName: version,
      entries: const ['Ứng dụng đã được cập nhật.'],
    );
  }
}
