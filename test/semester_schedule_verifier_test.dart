import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/registration_parser.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final html = File('test/fixtures/tracuu_latest.html').readAsStringSync();
  final response = jsonDecode(
    File('test/fixtures/schedule_latest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final registration = const QldtRegistrationParser().parse(
    html: html,
    selectedSemesterValue: 'new',
    selectedPlanValue: 'new-plan',
  );
  const scheduleParser = QldtParser();
  const verifier = SemesterScheduleVerifier();

  ImportedScheduleData parse(Map<String, dynamic> data) => scheduleParser
      .parseApiResponse(data, displayName: 'Sinh viên', strict: true);

  test(
    'links two study components and an exam through the registered class',
    () {
      final verified = verifier.verify(
        registration: registration,
        schedule: parse(response),
      );
      final semester = const SemesterDataBuilder().build(
        registration: registration,
        studySchedules: verified.studySchedules,
        examSchedules: verified.examSchedules,
        displayName: 'Sinh viên',
        syncedAt: DateTime(2026, 9, 23),
      );
      expect(semester.semesterId, '2026_2027_1');
      expect(semester.subjects.first.name, 'Thiết kế web nâng cao');
      expect(semester.subjects.first.studySchedules, hasLength(2));
      expect(semester.subjects.first.examSchedules, hasLength(1));
      expect(semester.subjects.last.studySchedules, isEmpty);
      expect(semester.subjects.last.examSchedules, isEmpty);
      expect(semester.toImportedScheduleData().records, hasLength(3));
    },
  );

  test('refuses an exam for a repeated subject from another term', () {
    final oldExam =
        Map<String, dynamic>.from(
            (response['Data'] as List<dynamic>).last as Map<String, dynamic>,
          )
          ..['TENLOPHOCPHAN'] = 'WEB-2025-LT'
          ..['PHONGTHI'] = 'C4';
    final mixed = <String, dynamic>{
      'Success': true,
      'Data': <dynamic>[...(response['Data'] as List<dynamic>), oldExam],
    };
    expect(
      () => verifier.verify(registration: registration, schedule: parse(mixed)),
      throwsFormatException,
    );
  });

  test('does not use a study date alone to match a class', () {
    final otherClass = Map<String, dynamic>.from(
      (response['Data'] as List<dynamic>).first as Map<String, dynamic>,
    )..['TENLOPHOCPHAN'] = 'WEB-2025-LT';
    expect(
      () => verifier.verify(
        registration: registration,
        schedule: parse(<String, dynamic>{
          'Success': true,
          'Data': <dynamic>[otherClass],
        }),
      ),
      throwsFormatException,
    );
  });

  test('rejects an old exam even if a repeated class name matches', () {
    final oldExam = Map<String, dynamic>.from(
      (response['Data'] as List<dynamic>).last as Map<String, dynamic>,
    )..['NGAYHOC'] = '10/12/2025';
    expect(
      () => verifier.verify(
        registration: registration,
        schedule: parse(<String, dynamic>{
          'Success': true,
          'Data': <dynamic>[oldExam],
        }),
      ),
      throwsFormatException,
    );
  });

  test('rejects partial or malformed API response before linking', () {
    final incomplete = <String, dynamic>{
      'Success': true,
      'Data': <dynamic>[
        (response['Data'] as List<dynamic>).first,
        <String, dynamic>{'TENHOCPHAN': 'Toán cao cấp'},
      ],
    };
    expect(() => parse(incomplete), throwsFormatException);
    expect(
      () => parse(<String, dynamic>{'Success': false}),
      throwsFormatException,
    );
    expect(
      () => const QldtRegistrationParser().parse(
        html: html.replaceAll('class="subject-item"', 'class="pending"'),
        selectedSemesterValue: 'new',
        selectedPlanValue: 'new-plan',
      ),
      throwsFormatException,
    );
  });
}
