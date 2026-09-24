import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class TracuuApi {
  const new();

  String scriptForAttempt(int attempt) =>
      _script.replaceAll('__ATTEMPT__', '$attempt');

  String get _script => r'''
    (function () {
      const attempt = __ATTEMPT__;
      const bridge = window.flutter_inappwebview;
      const system = window.edu && edu.system;
      const send = (handler, value) => bridge.callHandler(handler, attempt, value);
      let done = false;
      const fail = code => {
        if (done) return;
        done = true;
        send('betterPhenikaaRegistrationError', code);
      };
      const stage = value => send('betterPhenikaaRegistrationStage', value);
      if (!bridge || !system || !system.userId || system.iM == null ||
          typeof system.makeRequest !== 'function') {
        fail('SESSION_EXPIRED');
        return;
      }
      const call = (action, func, data, next) => {
        const payload = Object.assign({action, func, iM: system.iM,
          strQLSV_NguoiHoc_Id: system.userId}, data);
        try {
          system.makeRequest({
            success: response => {
              if (done) return;
              if (!response || response.Success !== true || !Array.isArray(response.Data)) {
                fail('INVALID_RESPONSE');
                return;
              }
              try { next(response); } catch (_) { fail('INVALID_RESPONSE'); }
            },
            error: () => fail('NETWORK_ERROR'),
            type: 'POST', action, contentType: true, data: payload, fakedb: []
          }, false, false, false, null);
        } catch (_) { fail('REQUEST_ERROR'); }
      };
      call('DKH_ThongTin_MH/DSA4FSkuKAYoIC8FIC8mCjgCIA8pIC8P',
        'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan',
        {strDaoTao_ThoiGianDaoTao_Id: null}, semesters => {
          const choices = semesters.Data.map(row => {
            const match = /^(\d{4})_(\d{4})_(\d+)$/.exec(row.THOIGIAN);
            return match && Number(match[2]) === Number(match[1]) + 1 && row.ID
              ? {id: row.ID, name: row.THOIGIAN, year: Number(match[1]), term: Number(match[3])}
              : null;
          }).filter(Boolean).sort((a, b) => b.year - a.year || b.term - a.term);
          if (!choices.length) { fail('NO_SEMESTER'); return; }
          const latest = choices[0];
          stage('semesterPlan');
          call('DKH_ThongTin_MH/DSA4BRIKJAkuICIpBSAvJgo4AiAPKSAv',
            'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan',
            {strDaoTao_ThoiGianDaoTao_Id: latest.id}, plans => {
              const matches = plans.Data.filter(row =>
                row.DAOTAO_THOIGIANDAOTAO_ID === latest.id && row.ID &&
                (row.MAKEHOACH === latest.name ||
                  String(row.MAKEHOACH || '').startsWith(latest.name + ',')));
              if (matches.length !== 1) { fail('PLAN_AMBIGUOUS'); return; }
              stage('subjects');
              call('DKH_Chung_MH/DSA4CiQ1EDQgBSAvJgo4DS4xCS4iESkgLwPP',
                'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan',
                {strDaoTao_ChuongTrinh_Id: '',
                  strDangKy_KeHoachDangKy_Id: matches[0].ID,
                  strNguoiThucHien_Id: system.userId,
                  strDaoTao_ThoiGianDaoTao_Id: latest.id}, registrations => {
                  stage('verification');
                  done = true;
                  send('betterPhenikaaRegistrationResult',
                    JSON.stringify({semesters, plans, registrations}));
                });
            });
        });
    })();
  ''';

  RegisteredSemester parse(String raw) {
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final semesters = _data(payload['semesters']);
    final candidates = <(String, String, int, int)>[];
    for (final item in semesters) {
      final name = _string(item['THOIGIAN']);
      final match = RegExp(r'^(\d{4})_(\d{4})_(\d+)$').firstMatch(name);
      if (match == null ||
          int.parse(match[2]!) != int.parse(match[1]!) + 1 ||
          _string(item['ID']).isEmpty) {
        continue;
      }
      candidates.add((
        _string(item['ID']),
        name,
        int.parse(match[1]!),
        int.parse(match[3]!),
      ));
    }
    if (candidates.isEmpty) {
      throw const FormatException('TraCuu không trả học kỳ hợp lệ.');
    }
    candidates.sort((a, b) {
      final year = b.$3.compareTo(a.$3);
      return year != 0 ? year : b.$4.compareTo(a.$4);
    });
    final latest = candidates.first;
    final plans = _data(payload['plans'])
        .where(
          (row) =>
              _string(row['DAOTAO_THOIGIANDAOTAO_ID']) == latest.$1 &&
              (_string(row['MAKEHOACH']) == latest.$2 ||
                  _string(row['MAKEHOACH']).startsWith('${latest.$2},')),
        )
        .toList();
    if (plans.length != 1 || _string(plans.single['ID']).isEmpty) {
      throw const FormatException('Không xác định được một kế hoạch đăng ký.');
    }
    final planId = _string(plans.single['ID']);
    final rows = _data(payload['registrations']);
    final subjects = <String, String>{};
    final sections = <String, Map<String, RegisteredClassSection>>{};
    for (final row in rows) {
      if (_string(row['DANGKY_KEHOACHDANGKY_ID']) != planId ||
          _string(row['DAOTAO_THOIGIANDAOTAO_ID']) != latest.$1) {
        throw const FormatException(
          'TraCuu trả lớp khác học kỳ hoặc kế hoạch.',
        );
      }
      final subjectId = _string(row['DAOTAO_HOCPHAN_ID']);
      final name = _string(row['DAOTAO_HOCPHAN_TEN']);
      final classId = _string(row['DANGKY_LOPHOCPHAN_ID']);
      final className = _string(row['DANGKY_LOPHOCPHAN_TEN']);
      final start = _date(row['NGAYBATDAU']);
      final end = _date(row['NGAYKETTHUC']);
      if (subjectId.isEmpty ||
          name.isEmpty ||
          classId.isEmpty ||
          className.isEmpty ||
          start == null ||
          end == null ||
          end.isBefore(start)) {
        throw const FormatException(
          'TraCuu trả môn hoặc lớp thiếu trường bắt buộc.',
        );
      }
      final previous = subjects[subjectId];
      if (previous != null &&
          normalizeSubjectName(previous) != normalizeSubjectName(name)) {
        throw const FormatException(
          'TraCuu trả ID môn với nhiều tên khác nhau.',
        );
      }
      subjects[subjectId] = name;
      final byClass = sections.putIfAbsent(subjectId, () => {});
      final existing = byClass[classId];
      final section = RegisteredClassSection(
        name: className,
        startsOn: start,
        endsOn: end,
      );
      if (existing != null &&
          (existing.name != className ||
              existing.startsOn != start ||
              existing.endsOn != end)) {
        throw const FormatException('TraCuu trả ID lớp với dữ liệu khác nhau.');
      }
      byClass[classId] = section;
    }
    return RegisteredSemester(
      id: latest.$2,
      name: latest.$2,
      subjectNames: subjects.values.toList(),
      classSections: {
        for (final entry in subjects.entries)
          entry.value: sections[entry.key]!.values.toList(),
      },
      confirmedEmpty: rows.isEmpty,
    );
  }

  List<Map<String, dynamic>> _data(Object? value) {
    if (value is! Map || value['Success'] != true || value['Data'] is! List) {
      throw const FormatException('TraCuu chưa trả Data hợp lệ.');
    }
    return (value['Data'] as List).map((row) {
      if (row is! Map) {
        throw const FormatException('TraCuu có dòng không hợp lệ.');
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  DateTime? _date(Object? value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$')
        .firstMatch(_string(value));
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month && date.year == year
        ? date
        : null;
  }
}
