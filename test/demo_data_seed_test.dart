import 'package:better_phenikaa_schedule/demo/demo_data_seed.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo data loads once without replacing saved schedules', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await DemoDataSeed.seedIfEmpty();
    final semester = await CurrentSemesterStore().read();
    expect(semester, isNotNull);
    expect(semester!.subjects, hasLength(8));
    expect(
      semester.subjects.expand((subject) => subject.studySchedules),
      hasLength(14),
    );
    expect(
      semester.subjects.expand((subject) => subject.examSchedules),
      hasLength(2),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('better_phenikaa_snapshot_v1'), isNotEmpty);
    final original = preferences.getString(CurrentSemesterStore.storageKey);
    await DemoDataSeed.seedIfEmpty();
    expect(preferences.getString(CurrentSemesterStore.storageKey), original);
  });
}
