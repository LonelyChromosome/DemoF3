import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/diem_danh/attendance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final lesson = ScheduleRecord(
    id: 'class|2026-10-08|mobile',
    isExam: false,
    subjectName: 'Lập trình thiết bị di động',
    room: 'A101',
    startAt: DateTime(2026, 10, 8, 13),
    endAt: DateTime(2026, 10, 8, 15),
    attendanceListId: 'attendance-list-from-QLDT',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no code means no attendance status', () async {
    final entries = await AttendanceStore().read();
    expect(entries[lesson.id], isNull);
  });

  test('submitted code is pending; repeated submission replaces only local code',
      () async {
    final store = AttendanceStore();
    final sent = await store.recordSent({}, lesson, '123');
    expect(sent[lesson.id]!.status, AttendanceStatus.pending);
    expect((await store.read())[lesson.id]!.code, '123');

    final resent = await store.recordSent(sent, lesson, '81026');
    expect(resent[lesson.id]!.code, '81026');
    expect(resent[lesson.id]!.status, AttendanceStatus.pending);
  });

  test('manual reconcile only changes explicit reviewed status', () async {
    final store = AttendanceStore();
    final sent = await store.recordSent({}, lesson, '81026');
    final waiting = await store.reconcile(sent, [lesson]);
    expect(waiting[lesson.id]!.status, AttendanceStatus.pending);

    final markedPresent = ScheduleRecord(
      id: lesson.id,
      isExam: false,
      subjectName: lesson.subjectName,
      room: lesson.room,
      startAt: lesson.startAt,
      endAt: lesson.endAt,
      attendanceListId: lesson.attendanceListId,
      attendanceReview: 'present',
    );
    final updated = await store.reconcile(waiting, [markedPresent]);
    expect(updated[lesson.id]!.status, AttendanceStatus.present);

    final markedAbsent = ScheduleRecord(
      id: lesson.id,
      isExam: false,
      subjectName: lesson.subjectName,
      room: lesson.room,
      startAt: lesson.startAt,
      endAt: lesson.endAt,
      attendanceListId: lesson.attendanceListId,
      attendanceReview: 'absent',
    );
    final absent = await store.reconcile(updated, [markedAbsent]);
    expect(absent[lesson.id]!.status, AttendanceStatus.absent);
  });

  test('schedule parser keeps server attendance id and explicit label', () {
    final response = <String, dynamic>{
      'Success': true,
      'Data': <Map<String, dynamic>>[
        {
          'PHANLOAI': 'LICHHOC',
          'TENHOCPHAN': 'Lập trình thiết bị di động',
          'NGAYHOC': '08/10/2026',
          'GIOBATDAU': 13,
          'PHUTBATDAU': 0,
          'GIOKETTHUC': 15,
          'PHUTKETTHUC': 0,
          'DIEM_DANHSACH_ID': 'real-server-id',
          'KETQUADIEMDANH': 'Có mặt',
        }
      ],
    };
    final imported = const QldtParser().parseApiResponse(
      response, displayName: 'Test',
    );
    expect(imported.classes.single.attendanceListId, 'real-server-id');
    expect(imported.classes.single.attendanceReview, 'present');
    expect(ImportedScheduleData.decode(imported.encode())
        .classes.single.attendanceReview, 'present');
  });
}
