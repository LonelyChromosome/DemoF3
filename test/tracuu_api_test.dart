import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const api = TracuuApi();

  Map<String, dynamic> envelope(List<Map<String, Object?>> data) =>
      <String, dynamic>{'Success': true, 'Data': data};

  Map<String, dynamic> row({
    String semester = 'new',
    String plan = 'new-plan',
    String subject = 'web',
    String name = 'Thiết kế web nâng cao',
    String section = 'web-lt',
    String className = 'WEB-2026-LT',
  }) => <String, dynamic>{
    'DAOTAO_THOIGIANDAOTAO_ID': semester,
    'DANGKY_KEHOACHDANGKY_ID': plan,
    'DAOTAO_HOCPHAN_ID': subject,
    'DAOTAO_HOCPHAN_TEN': name,
    'DANGKY_LOPHOCPHAN_ID': section,
    'DANGKY_LOPHOCPHAN_TEN': className,
    'NGAYBATDAU': '17/08/2026',
    'NGAYKETTHUC': '01/11/2026',
  };

  String sample({
    List<Map<String, Object?>>? registrations,
    List<Map<String, Object?>>? plans,
  }) => jsonEncode({
    'semesters': envelope([
      {'ID': 'old', 'THOIGIAN': '2025_2026_3'},
      {'ID': 'new', 'THOIGIAN': '2026_2027_1'},
    ]),
    'plans': envelope(
      plans ??
          [
            {
              'ID': 'new-plan',
              'DAOTAO_THOIGIANDAOTAO_ID': 'new',
              'MAKEHOACH': '2026_2027_1,1',
            },
          ],
    ),
    'registrations': envelope(
      registrations ??
          [row(), row(section: 'web-th', className: 'WEB-2026-TH')],
    ),
  });

  test('uses verified APIs and reads dropdown only for diagnostics', () {
    final script = api.scriptForAttempt(7);
    expect(script, contains('LayThoiGianDangKyCaNhan'));
    expect(script, contains('LayDSKeHoachDangKyCaNhan'));
    expect(script, contains('LayKetQuaDangKyLopHocPhan'));
    expect(script, contains('strQLSV_NguoiHoc_Id: system.userId'));
    expect(script, contains("document.querySelector('#dropSearch_KeHoach')"));
    expect(script, isNot(contains('dispatchEvent')));
  });

  test(
    'latest semester groups multiple component classes into one subject',
    () {
      final parsed = api.parse(sample());
      expect(parsed.id, '2026_2027_1');
      expect(parsed.subjectNames, ['Thiết kế web nâng cao']);
      expect(parsed.classSections['Thiết kế web nâng cao'], hasLength(2));
    },
  );

  test('programme metadata is optional and never changes registration validation', () {
    const programmeId = '5B225B4E54A647F9B066CADC7F063150';
    final first = {
      ...row(),
      'DAOTAO_TOCHUCCHUONGTRINH_ID': programmeId,
    };
    final second = {
      ...row(section: 'web-th', className: 'WEB-2026-TH'),
      'DAOTAO_TOCHUCCHUONGTRINH_ID': programmeId,
    };
    expect(api.parse(sample(registrations: [first, second])).programId,
        programmeId);
    expect(api.parse(sample()).programId, isNull);
    final other = {...second, 'DAOTAO_TOCHUCCHUONGTRINH_ID': 'other'};
    final mixed = api.parse(sample(registrations: [first, other]));
    expect(mixed.subjectNames, ['Thiết kế web nâng cao']);
    expect(mixed.programId, isNull);
  });

  test('deduplicates one plan ID despite different auxiliary metadata', () {
    final parsed = api.parse(
      sample(
        plans: [
          {'ID': 'old-plan', 'DAOTAO_THOIGIANDAOTAO_ID': 'old'},
          {
            'ID': 'new-plan',
            'DAOTAO_THOIGIANDAOTAO_ID': 'new',
            'MAKEHOACH': '2026_2027_1,1',
            'TENKEHOACH': 'label A',
          },
          {
            'ID': 'new-plan',
            'DAOTAO_THOIGIANDAOTAO_ID': 'new',
            'MAKEHOACH': '2026_2027_1,1',
            'TENKEHOACH': 'label B',
          },
        ],
      ),
    );
    expect(parsed.id, '2026_2027_1');
    expect(parsed.subjectNames, ['Thiết kế web nâng cao']);
  });

  test('accepts the scoped plan with a different internal semester ID', () {
    final parsed = api.parse(
      sample(
        plans: [
          {
            'ID': 'new-plan',
            'DAOTAO_THOIGIANDAOTAO_ID': 'plan-sem',
            'MAKEHOACH': '2026_2027_1,1',
          },
        ],
        registrations: [row(semester: 'plan-sem')],
      ),
    );
    expect(parsed.id, '2026_2027_1');
    expect(parsed.subjectNames, ['Thiết kế web nâng cao']);
  });

  test('rejects missing or distinct plans for the latest semester', () {
    expect(
      () => api.parse(
        sample(
          plans: [
            {'ID': 'old-plan', 'DAOTAO_THOIGIANDAOTAO_ID': 'old'},
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => api.parse(
        sample(
          plans: [
            {
              'ID': 'new-plan',
              'DAOTAO_THOIGIANDAOTAO_ID': 'new',
              'MAKEHOACH': '2026_2027_1,1',
            },
            {
              'ID': 'another-plan',
              'DAOTAO_THOIGIANDAOTAO_ID': 'new',
              'MAKEHOACH': '2026_2027_1,2',
            },
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects a same-name class belonging to an old semester', () {
    expect(
      () => api.parse(
        sample(
          registrations: [
            row(),
            row(semester: 'old'),
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects a plan mismatch, malformed response and unfinished results',
    () {
      expect(
        () => api.parse(sample(registrations: [row(plan: 'old-plan')])),
        throwsFormatException,
      );
      expect(api.parse(sample(registrations: [])).confirmedEmpty, isTrue);
      final malformed = jsonDecode(sample()) as Map<String, dynamic>;
      (malformed['plans'] as Map<String, dynamic>)['Data'] = null;
      expect(() => api.parse(jsonEncode(malformed)), throwsFormatException);
    },
  );
}
