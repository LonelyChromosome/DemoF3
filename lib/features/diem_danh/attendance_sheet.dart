import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/diem_danh/attendance.dart';
import 'package:better_phenikaa_schedule/features/diem_danh/user_feedback.dart';
import 'package:flutter/material.dart';

Future<void> showAttendanceSheet({
  required BuildContext context,
  required ScheduleRecord lesson,
  required AttendanceEntry? current,
  required Future<void> Function(String code) onSubmit,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _AttendanceSheet(
    lesson: lesson,
    current: current,
    onSubmit: onSubmit,
  ),
);

class _AttendanceSheet extends StatefulWidget {
  const _AttendanceSheet({
    required this.lesson,
    required this.current,
    required this.onSubmit,
  });

  final ScheduleRecord lesson;
  final AttendanceEntry? current;
  final Future<void> Function(String code) onSubmit;

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  late final TextEditingController _code =
      TextEditingController(text: widget.current?.code ?? '');
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_sending || _code.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_code.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) setState(() => _error = attendanceFailureMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.current?.status;
    final statusText = switch (status) {
      AttendanceStatus.pending => 'Chờ xác thực',
      AttendanceStatus.present => 'Có mặt',
      AttendanceStatus.absent => 'Vắng mặt',
      null => null,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22, 20, 22, MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.lesson.subjectName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Buổi học ${widget.lesson.startAt.day}/'
            '${widget.lesson.startAt.month}/${widget.lesson.startAt.year}',
          ),
          if (statusText != null) ...<Widget>[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(statusText),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            enabled: !_sending,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Code điểm danh',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            )),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : _save,
              child: Text(_sending
                  ? 'Đang lưu...'
                  : widget.current == null ? 'Lưu code' : 'Gửi lại code'),
            ),
          ),
          if (widget.current != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Gửi lại sẽ gửi một yêu cầu mới. '
                'QLĐT quyết định cách xử lý code đã gửi trước đó.',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
