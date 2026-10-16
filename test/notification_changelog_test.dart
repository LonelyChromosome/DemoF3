import 'package:better_phenikaa_schedule/features/app_update/notification_changelog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1.7 notification log contains release and verified pull hotfix', () {
    final log = NotificationChangelog.forInstalledVersion('cooc.1.7');
    expect(log.versionName, 'cooc.1.7');
    expect(log.entries.join(' '), contains('Recap'));
    expect(log.entries.join(' '), contains('tag số buổi nghỉ'));
    expect(log.entries.join(' '), contains('Pull Reload timeout'));
    expect(log.entries.join(' '), contains('khôi phục phiên QLĐT'));
    expect(log.entries.join(' '), isNot(contains('Bổ sung VFX')));
  });

  test('notification log is installed-version-specific, not remote updater', () {
    final old = NotificationChangelog.forInstalledVersion('cooc.1.6');
    expect(old.versionName, 'cooc.1.6');
    expect(old.entries.join(' '), isNot(contains('Recap')));
    final future = NotificationChangelog.forInstalledVersion('cooc.1.8');
    expect(future.versionName, 'cooc.1.8');
    expect(future.entries, ['Theme Premium 2: Water Cooling']);
    expect(future.entries.join(' '), isNot(contains('Recap')));
  });

  test('app startup shows the bundled 1.8 release log', () {
    expect(NotificationChangelog.forInstalledVersion('').versionName, 'cooc.1.8');
  });
}
