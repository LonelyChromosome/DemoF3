import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

final class ScheduleRecord {
  const new({
    required this.id,
    required this.isExam,
    required this.subjectName,
    required this.room,
    required this.startAt,
    required this.endAt,
    this.className = '',
    this.examForm = '',
    this.periodStart,
    this.periodEnd,
  });

  factory fromJson(Map<String, Object?> json) {
    return ScheduleRecord(
      id: json['id']! as String,
      isExam: json['isExam']! as bool,
      subjectName: json['subjectName']! as String,
      room: json['room']! as String,
      startAt: DateTime.parse(json['startAt']! as String),
      endAt: DateTime.parse(json['endAt']! as String),
      className: json['className'] as String? ?? '',
      examForm: json['examForm'] as String? ?? '',
      periodStart: json['periodStart'] as int?,
      periodEnd: json['periodEnd'] as int?,
    );
  }

  final String id;
  final bool isExam;
  final String subjectName;
  final String room;
  final DateTime startAt;
  final DateTime endAt;
  final String className;
  final String examForm;
  final int? periodStart;
  final int? periodEnd;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'isExam': isExam,
    'subjectName': subjectName,
    'room': room,
    'startAt': startAt.toIso8601String(),
    'endAt': endAt.toIso8601String(),
    'className': className,
    'examForm': examForm,
    'periodStart': periodStart,
    'periodEnd': periodEnd,
  };
}

final class ImportedScheduleData {
  const new({
    required this.displayName,
    required this.records,
    required this.syncedAt,
    this.source = 'qldt',
  });

  factory decode(String source) {
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final recordsRaw = raw['records'] as List<dynamic>? ?? const <dynamic>[];
    return ImportedScheduleData(
      displayName: raw['displayName'] as String? ?? '',
      records: recordsRaw
          .map(
            (item) => ScheduleRecord.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
      syncedAt: DateTime.parse(raw['syncedAt']! as String),
      source: raw['source'] as String? ?? 'qldt',
    );
  }

  final String displayName;
  final List<ScheduleRecord> records;
  final DateTime syncedAt;
  final String source;

  Iterable<ScheduleRecord> get classes =>
      records.where((record) => !record.isExam);

  Iterable<ScheduleRecord> get exams =>
      records.where((record) => record.isExam);

  Map<String, Object?> toJson() => <String, Object?>{
    'displayName': displayName,
    'records': records.map((record) => record.toJson()).toList(),
    'syncedAt': syncedAt.toIso8601String(),
    'source': source,
  };

  String encode() => jsonEncode(toJson());
}

final class QldtParser {
  const new();

  String parseDisplayName(String html) {
    final document = html_parser.parse(html);
    final preferred = document.querySelector('#lblHoTenNguoiDangNhap');
    final preferredText = preferred?.text.trim() ?? '';
    if (preferredText.isNotEmpty) {
      return preferredText;
    }

    final accountSpans = document.querySelectorAll(
      '.nav-account button > span',
    );
    for (final span in accountSpans) {
      final text = span.text.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  ImportedScheduleData parseLiveEnvelope(String envelopeJson) {
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final displayName = (envelope['name'] as String? ?? '').trim();
    final response = envelope['response'];
    if (response is! Map) {
      throw const FormatException('QLĐT response is not an object.');
    }
    return parseApiResponse(
      Map<String, dynamic>.from(response),
      displayName: displayName,
    );
  }

  ImportedScheduleData parseApiResponse(
    Map<String, dynamic> response, {
    required String displayName,
  }) {
    if (response['Success'] != true) {
      throw const FormatException('QLĐT returned Success != true.');
    }
    final rawData = response['Data'];
    if (rawData is! List) {
      throw const FormatException('QLĐT Data is not a list.');
    }

    final records = <ScheduleRecord>[];
    for (final rawItem in rawData) {
      if (rawItem is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(rawItem);
      final record = _parseRecord(item);
      if (record != null) {
        records.add(record);
      }
    }

    records.sort((a, b) => a.startAt.compareTo(b.startAt));
    return ImportedScheduleData(
      displayName: displayName,
      records: records,
      syncedAt: DateTime.now(),
    );
  }

  ScheduleRecord? _parseRecord(Map<String, dynamic> item) {
    final subjectName = _string(item['TENHOCPHAN']);
    final dateText = _string(item['NGAYHOC']);
    if (subjectName.isEmpty || dateText.isEmpty) {
      return null;
    }

    final day = _parseVietnameseDate(dateText);
    if (day == null) {
      return null;
    }

    final startHour = _int(item['GIOBATDAU']);
    final startMinute = _int(item['PHUTBATDAU']);
    final endHour = _int(item['GIOKETTHUC']);
    final endMinute = _int(item['PHUTKETTHUC']);
    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return null;
    }

    final isExam = _string(item['PHANLOAI']).toUpperCase() == 'LICHTHI';
    final room = isExam
        ? _firstNonEmpty(<Object?>[item['PHONGHOC_TEN'], item['PHONGTHI']])
        : _firstNonEmpty(<Object?>[item['PHONGHOC_TEN'], item['TENPHONGHOC']]);
    final className = _string(item['TENLOPHOCPHAN']);
    final examForm = _string(item['DANGKY_LOPHOCPHAN_TEN']);
    final startAt = DateTime(
      day.year,
      day.month,
      day.day,
      startHour,
      startMinute,
    );
    final endAt = DateTime(day.year, day.month, day.day, endHour, endMinute);
    final id = <String>[
      if (isExam) 'exam' else 'class',
      dateText,
      subjectName,
      '$startHour:$startMinute',
      room,
    ].join('|');

    return ScheduleRecord(
      id: id,
      isExam: isExam,
      subjectName: subjectName,
      room: room,
      startAt: startAt,
      endAt: endAt,
      className: className,
      examForm: examForm,
      periodStart: _int(item['TIETBATDAU']),
      periodEnd: _int(item['TIETKETTHUC']),
    );
  }

  static DateTime? _parseVietnameseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
