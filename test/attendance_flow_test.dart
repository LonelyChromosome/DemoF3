import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_native_transport.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
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

  test('manual app sync and pull sync use same QLDT readiness requirements', () {
    final session = QldtNativeSession.fromJson(<String, dynamic>{
      'tokenJWT': 'test-token',
      'userId': 'test-user',
      'iM': 'test-im',
      'appId': '',
      'strChucNangId': '',
    });
    expect(session.isValid, isTrue);
    expect(QldtNativeSession.fromJson(<String, dynamic>{
      'tokenJWT': '',
      'userId': 'test-user',
      'iM': 'test-im',
    }).isValid, isFalse);
  });

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

  test('attendance stays scoped to one lesson, not a whole subject', () async {
    final store = AttendanceStore();
    final submitted = await store.recordSent({}, lesson, '4217');
    final otherLesson = ScheduleRecord(
      id: 'class|2026-10-09|mobile',
      isExam: false,
      subjectName: lesson.subjectName,
      room: lesson.room,
      startAt: lesson.startAt.add(const Duration(days: 1)),
      endAt: lesson.endAt.add(const Duration(days: 1)),
      attendanceListId: 'other-list',
      attendanceReview: 'present',
    );
    final next = await store.reconcile(submitted, [otherLesson]);
    expect(next[lesson.id]!.status, AttendanceStatus.pending);
    expect(next[otherLesson.id], isNull);

    final wrongList = ScheduleRecord(
      id: lesson.id,
      isExam: false,
      subjectName: lesson.subjectName,
      room: lesson.room,
      startAt: lesson.startAt,
      endAt: lesson.endAt,
      attendanceListId: 'other-list',
      attendanceReview: 'absent',
    );
    final wrong = await store.reconcile(next, [wrongList]);
    expect(wrong[lesson.id]!.status, AttendanceStatus.pending);
  });

  test('attendance labels never count as a modified timetable', () {
    CurrentSemester semester(ScheduleRecord study) => CurrentSemester(
      semesterId: 'S2026',
      semesterName: '2026-1',
      displayName: 'Test Student',
      syncedAt: DateTime(2026, 10, 8),
      subjects: [
        SemesterSubject(
          subjectId: 'S2026|mobile',
          name: lesson.subjectName,
          normalizedName: 'lap trinh thiet bi di dong',
          studySchedules: [study],
          examSchedules: const [],
        ),
      ],
    );
    final reviewed = ScheduleRecord(
      id: lesson.id,
      isExam: false,
      subjectName: lesson.subjectName,
      room: lesson.room,
      startAt: lesson.startAt,
      endAt: lesson.endAt,
      attendanceListId: 'other-list',
      attendanceReview: 'present',
    );
    final difference = const SemesterChangeDetector().compare(
      semester(lesson),
      semester(reviewed),
    );
    expect(difference.hasChanges, isFalse);
    expect(difference.study.modified, 0);
    expect(difference.exams.modified, 0);
  });

  test('real QLDT course-section ID and THONGTINCHUYENCAN are parsed', () {
    final raw = <String, dynamic>{
      'Success': true,
      'Data': [
        {
          'PHANLOAI': 'LICHHOC',
          'TENHOCPHAN': 'Phân tích và thiết kế phần mềm',
          'TENLOPHOCPHAN': 'Phân tích và thiết kế phần mềm-1-1-26(N08)<br>Có mặt<br>',
          'NGAYHOC': '08/10/2026',
          'PHONGHOC_TEN': 'A6-105 (PC)',
          'GIOBATDAU': 13, 'PHUTBATDAU': 0,
          'GIOKETTHUC': 15, 'PHUTKETTHUC': 40,
          'DANGKY_LOPHOCPHAN_ID': 'course-id-from-timetable',
          'IDLOPHOCPHAN': 'course-id-from-timetable',
          'THONGTINCHUYENCAN': 'Có mặt(3)',
        },
      ],
    };
    final result = const QldtParser()
        .parseApiResponse(raw, displayName: 'Student');
    expect(result.classes.single.attendanceListId,
        'course-id-from-timetable');
    expect(result.classes.single.attendanceReview, 'present');
    raw['Data'] = [
      {...(raw['Data'] as List).single as Map<String, dynamic>,
        'THONGTINCHUYENCAN': 'Vắng mặt(3)'},
    ];
    final absent = const QldtParser()
        .parseApiResponse(raw, displayName: 'Student');
    expect(absent.classes.single.attendanceReview, 'absent');
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
