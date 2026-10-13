import 'dart:async';
import 'dart:math' as math;
import 'package:better_phenikaa_schedule/features/recap/recap_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Final memory icon: fixed calendar, perfectly centered four-point star.
/// No sweeping arcs; angular velocity slows progressively and accelerates.
class RecapMemoryButton extends StatefulWidget {
  const RecapMemoryButton({required this.onPressed, this.size = 56, super.key});
  final VoidCallback onPressed;
  final double size;
  @override
  State<RecapMemoryButton> createState() => _RecapMemoryButtonState();
}

class _RecapMemoryButtonState extends State<RecapMemoryButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Mở hồi tưởng học kỳ',
    child: InkWell(
      onTap: widget.onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _MemoryIconPainter(RecapSpin.angle(_controller.value)),
          ),
        ),
      ),
    ),
  );
}

class _MemoryIconPainter extends CustomPainter {
  const _MemoryIconPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);
    const gold = Color(0xFFF5C866);
    const highlight = Color(0xFFFFE9AC);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(7, 9, 50, 48),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()
      ..color = gold.withValues(alpha: .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF11234C));
    canvas.drawRRect(rect, Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5);
    final pins = Paint()
      ..color = highlight
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(21, 5), const Offset(21, 17), pins);
    canvas.drawLine(const Offset(43, 5), const Offset(43, 17), pins);

    // The calendar stays perfectly still; this transform is only for the
    // star, whose exact geometric center is aligned to the calendar center.
    canvas.save();
    canvas.translate(32, 33);
    canvas.rotate(angle);
    final star = Path()
      ..moveTo(0, -20)
      ..cubicTo(4, -6, 6, -4, 20, 0)
      ..cubicTo(6, 4, 4, 6, 0, 20)
      ..cubicTo(-4, 6, -6, 4, -20, 0)
      ..cubicTo(-6, -4, -4, -6, 0, -20)
      ..close();
    canvas.drawPath(star, Paint()
      ..color = highlight.withValues(alpha: .65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawPath(star, Paint()..color = highlight);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MemoryIconPainter old) => old.angle != angle;
}

class SemesterRecapPage extends StatefulWidget {
  const SemesterRecapPage({required this.load, super.key});
  /// Loading calls existing 1.7 sync without awaiting it, waits 2.8 seconds,
  /// then returns a frozen locally available semester snapshot.
  final Future<RecapFacts> Function() load;

  @override
  State<SemesterRecapPage> createState() => _SemesterRecapPageState();
}

class _SemesterRecapPageState extends State<SemesterRecapPage> {
  RecapFacts? _facts;
  String? _failure;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final facts = await widget.load();
      if (mounted) setState(() => _facts = facts);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failure = error is StateError
            ? error.message.toString()
            : 'Không thể đọc dữ liệu QLĐT đã xác minh. Hãy đăng nhập và đồng bộ trong ứng dụng thử nghiệm.');
      }
    }
  }

  void _navigateFromTap(TapUpDetails details, double width, int count) {
    if (width <= 0 || count == 0) return;
    if (details.localPosition.dx < width / 2) {
      // First slide has no previous page. Never close on left-zone tapping.
      if (_index > 0) setState(() => _index--);
      return;
    }
    if (_index < count - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final facts = _facts;
    final stories = facts == null ? const <_Story>[] : _stories(facts);
    const colors = <Color>[
      Color(0xFF0F2949), Color(0xFF122D47), Color(0xFF18354A),
      Color(0xFF24304C), Color(0xFF17384A), Color(0xFF283650),
      Color(0xFF273247), Color(0xFF1E3B48), Color(0xFF17314A),
      Color(0xFF283549), Color(0xFF102A42),
    ];
    final base = colors[_index.clamp(0, colors.length - 1)];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: const Color(0xFF08172D),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, const Color(0xFF07142B)],
          ),
        ),
        child: SafeArea(child: Stack(children: [
          Positioned.fill(child: IgnorePointer(
            child: CustomPaint(painter: const _AmbientPainter()),
          )),
          if (facts == null && _failure == null)
            const Center(child: _LoadingMemory())
          else if (_failure != null)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _RecapPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                      color: Color(0xFFFFD58B), size: 32),
                    const SizedBox(height: 17),
                    const Text('Cần dữ liệu QLĐT thật',
                      style: TextStyle(color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(_failure!, style: const TextStyle(
                      color: Color(0xFFD4E0ED), fontSize: 15, height: 1.5)),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Trở về ứng dụng'),
                    ),
                  ],
                ),
              ),
            ))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 14, 19, 14),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: facts!.preview
                              ? const Color(0xFF5A3127)
                              : const Color(0xFF143D48),
                          border: Border.all(
                            color: facts!.preview
                                ? const Color(0xFFEFAC7F)
                                : const Color(0xFF8FE0C6),
                            width: .8,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(facts!.preview ? Icons.science_outlined :
                              Icons.verified_user_outlined,
                              color: facts!.preview ? const Color(0xFFFFCCB0)
                                : const Color(0xFFA1EDD2), size: 15),
                            const SizedBox(width: 7),
                            Flexible(child: Text(
                              facts!.preview ? 'GIẢ LẬP · KHÔNG PHẢI QLĐT'
                                : 'QLĐT · DỮ LIỆU THẬT',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: facts!.preview
                                  ? const Color(0xFFFFE1CD)
                                  : const Color(0xFFC2F2DF),
                                fontSize: 10, letterSpacing: .9,
                                fontWeight: FontWeight.w800,
                              ),
                            )),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Đóng Recap',
                    icon: const Icon(Icons.close_rounded,
                      color: Color(0xFFEAF0F6)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: List.generate(stories.length, (index) =>
                  Expanded(child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: index <= _index ? const Color(0xFFFFD68C)
                        : const Color(0xFF496078),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                )),
                const SizedBox(height: 8),
                if (!facts!.preview)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 6),
                    child: Text(
                      'Tài khoản: ${facts!.displayName}  ·  Lịch lưu: ${_d(facts!.syncedAt)} ${_hour(facts!.syncedAt)}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(color: Color(0xFFB6C9DB),
                        fontSize: 10, letterSpacing: .1),
                    ),
                  ),
                Expanded(child: LayoutBuilder(
                  builder: (context, viewport) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _navigateFromTap(
                    details, viewport.maxWidth, stories.length),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.045, .055),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _StoryBody(
                      key: ValueKey<int>(_index),
                      story: stories[_index],
                      index: _index,
                      preview: facts!.preview,
                      facts: facts,
                    ),
                  ),
                ),
                )),
                Padding(
                  padding: const EdgeInsets.only(top: 13, bottom: 4),
                  child: Row(children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('‹  TRÁI · LÙI',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFCDD9E6), fontSize: 11,
                            fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${_index + 1} / ${stories.length}',
                        style: const TextStyle(
                          color: Color(0xFFFFD28C),
                          fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _index == stories.length - 1
                            ? 'PHẢI · KẾT THÚC  ›' : 'PHẢI · TIẾN  ›',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Color(0xFFCDD9E6), fontSize: 11,
                            fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
        ])),
      ),
      ),
    );
  }
}

/// Quiet architecture lines instead of large, inexpensive-looking circles.
class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final hairline = Paint()
      ..color = const Color(0xFFB6CEE9).withValues(alpha: .035)
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hairline);
    }
    for (var i = 0; i < 15; i++) {
      final y = size.height * i / 14;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hairline);
    }
    final ornament = Paint()
      ..color = const Color(0xFFFFD68C).withValues(alpha: .38);
    for (final point in <Offset>[
      Offset(size.width * .13, size.height * .10),
      Offset(size.width * .87, size.height * .22),
      Offset(size.width * .91, size.height * .78),
    ]) {
      canvas.drawCircle(point, 1.7, ornament);
    }
  }
  @override
  bool shouldRepaint(_AmbientPainter old) => false;
}

class _RecapPanel extends StatelessWidget {
  const _RecapPanel({required this.child, this.highlight = false});
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(23, 24, 23, 25),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: highlight
          ? const [Color(0xFF254865), Color(0xFF172B49)]
          : const [Color(0xED1B3451), Color(0xF214253F)],
      ),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(
        color: highlight ? const Color(0xFFAD9365)
          : const Color(0xFF486077),
        width: highlight ? 1.3 : 1,
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x66040C1A),
          blurRadius: 22, offset: Offset(0, 14)),
      ],
    ),
    child: child,
  );
}

class _LoadingMemory extends StatelessWidget {
  const _LoadingMemory();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IgnorePointer(child: RecapMemoryButton(
        onPressed: () {}, size: 130,
      )),
      const SizedBox(height: 28),
      const Text('Đợi chút nhé...',
        style: TextStyle(color: Color(0xFFFFDF9F),
          fontSize: 27, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      const Text('Một học kỳ, thật nhiều điều để nhớ.',
        style: TextStyle(color: Colors.white70, fontSize: 14)),
    ],
  );
}

class _Story {
  const _Story(this.eyebrow, this.heading, this.number, this.caption);
  final String eyebrow, heading, number, caption;
}

String _d(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _hour(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

List<_Story> _stories(RecapFacts f) {
  final last = f.lastClass;
  final perfect = f.attendanceConfirmed && f.absence == 0;
  final attendanceSlide = f.absence == null
      ? const _Story('ĐIỂM DANH', 'Chưa đủ thông tin chuyên cần', '—',
          'QLĐT chưa cung cấp số buổi vắng. Không suy ra đã có mặt.')
      : perfect
      ? const _Story('ĐIỂM DANH', 'Một học kỳ trọn vẹn', '0',
          'Các buổi đã được xác nhận có mặt.')
      : f.mostAbsentCount == null
      ? const _Story('ĐIỂM DANH', 'Chưa ghi nhận buổi vắng', '0',
          'Chỉ tính những môn có dữ liệu chuyên cần, không phải xác nhận đã có mặt đầy đủ.')
      : _Story('ĐIỂM DANH', 'Từng môn, từng buổi', '${f.mostAbsentCount}',
          'Riêng ${f.mostAbsent ?? 'môn chưa xác định'} ghi nhận ${f.mostAbsentCount} buổi vắng. Các môn khác nằm trong bảng phía dưới.');
  final encouragement = perfect
      ? const _Story('ĐÁNG TỰ HÀO', 'Một lời khen dành cho bạn', '✦',
          'Không phải ngày nào cũng dễ dàng. Bạn đã có mặt trong từng buổi học.')
      : f.clearSubjects.isNotEmpty
      ? _Story('NHỮNG MÔN ĐÁNG NHỚ', 'Những cố gắng âm thầm',
          '${f.clearSubjects.length}',
          'Có ${f.clearSubjects.length} môn chưa ghi nhận buổi vắng. Đó cũng là một dấu ấn đáng nhớ.')
      : const _Story('MỘT GÓC NHÌN KHÁC', 'Điều quan trọng là bạn vẫn tiếp tục', '✧',
          'Không một con số riêng lẻ nào nói hết được cả học kỳ của bạn.');
  return [
    _Story('BETTER PHENIKAA · FLASHBACK',
      f.finished ? 'Một học kỳ nữa đã qua rồi.' :
          'Vậy là sắp hết một học kỳ rồi nhỉ...',
      '✦', 'Cùng nhìn lại một chút nhé.'),
    _Story('MỘT KỲ HỌC', 'Những con số biết kể chuyện',
      '${f.days} ngày',
      '${f.subjects} môn · ${f.periods} tiết có dữ liệu${f.unknownPeriods > 0 ? ' · ${f.unknownPeriods} buổi chưa rõ số tiết' : ''}.'),
    _Story('SÁNG & CHIỀU', 'Hai nhịp học khác nhau',
      '${f.morning + f.afternoon} buổi', 'Tách ca học theo giờ bắt đầu của lịch QLĐT.'),
    _Story('6 GIỜ 45', 'Những buổi sáng thật sớm',
      '${f.early}', f.early == 0
        ? 'Học kỳ này không có lớp bắt đầu đúng 6:45.'
        : 'Đôi khi ngày học bắt đầu trước cả khi phố phường thức giấc.'),
    _Story('NGÀY BẬN RỘN', 'Một ngày có rất nhiều lịch học',
      '${f.busiestCount} buổi', f.busiest == null
        ? 'Chưa có lịch học để xác định.'
        : 'Ngày ${_d(f.busiest!)} đã chứa nhiều buổi học hơn mọi ngày khác.'),
    _Story('THEO TỪNG MÔN', 'Mỗi môn có một lịch trình riêng',
      '${f.favoriteCount} buổi', 'Đếm riêng bản ghi QLĐT từng môn, không tự gán hai môn bằng nhau.'),
    attendanceSlide,
    encouragement,
    _Story('BUỔI HỌC CUỐI',
      f.finished ? 'Buổi học cuối đã khép lại' : 'Buổi cuối đang ở phía trước',
      last == null ? '—' : _d(last.startAt),
      last == null ? 'Chưa có lịch học.' :
          '${subjectDisplayName(last.subjectName)} · ${_hour(last.startAt)}.'),
    _Story('MỘT TẤM BƯU THIẾP', 'Học kỳ này là của bạn',
      '${f.days} ngày',
      '${f.subjects} môn học · ${f.early} buổi 6:45 · ${f.favoriteCount} buổi với môn gắn bó nhất.'),
    const _Story('HẸN GẶP LẠI', 'Dù sao, cũng đã là một hành trình', '✦',
      'Những ngày tháng ấy sẽ ở lại như một phần ký ức. Hẹn gặp ở một học kỳ mới.'),
  ];
}

class _StoryBody extends StatelessWidget {
  const _StoryBody({required this.story, required this.index,
    required this.preview, required this.facts, super.key});
  final _Story story;
  final int index;
  final bool preview;
  final RecapFacts facts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 5, height: 31,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD68C),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(child: Text(story.eyebrow,
                style: const TextStyle(
                  color: Color(0xFFFFD68C),
                  fontSize: 12, letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              )),
            ]),
            const SizedBox(height: 18),
            Text(story.heading, style: const TextStyle(
              color: Color(0xFFF5F8FC), fontSize: 28,
              height: 1.16, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 24),
            if (index == 2)
              _DayPartBento(facts: facts)
            else if (index == 5)
              _SubjectBento(facts: facts)
            else if (index == 6)
              _AttendanceBento(facts: facts)
            else _RecapSectionCard(facts: facts, story: story, index: index),
            const SizedBox(height: 13),
            _RecapPanel(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_rounded,
                    color: Color(0xFFE6C17F), size: 21),
                  const SizedBox(width: 14),
                  Expanded(child: Text(story.caption, style: const TextStyle(
                    color: Color(0xFFDCE7EF), fontSize: 15,
                    height: 1.55, fontWeight: FontWeight.w400,
                  ))),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Distinct metric panel for each chapter, rather than the same generic card.
class _RecapSectionCard extends StatelessWidget {
  const _RecapSectionCard({
    required this.facts, required this.story, required this.index,
  });
  final RecapFacts facts;
  final _Story story;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (icon, header, accent) = switch (index) {
      0 => (Icons.auto_awesome_rounded, 'MỞ LẠI KÝ ỨC',
        const Color(0xFFFFD998)),
      1 => (Icons.menu_book_outlined, 'HỌC KỲ QUA NHỮNG CON SỐ',
        const Color(0xFF8CCADB)),
      3 => (Icons.alarm_rounded, 'BÌNH MINH TRÊN GIẢNG ĐƯỜNG',
        const Color(0xFFFFCC89)),
      4 => (Icons.event_note_rounded, 'NGÀY ĐÁNG NHỚ NHẤT',
        const Color(0xFFC2A9FF)),
      7 => (Icons.favorite_border_rounded, 'MỘT ĐIỀU ĐÁNG GIỮ LẠI',
        const Color(0xFFB9E6C8)),
      8 => (Icons.flag_outlined, 'DẤU MỐC CUỐI CÙNG',
        const Color(0xFFFFCDA6)),
      9 => (Icons.mark_email_unread_outlined, 'BƯU THIẾP HỌC KỲ',
        const Color(0xFFB4D1FA)),
      _ => (Icons.auto_awesome_outlined, 'HẸN MỘT NGÀY GẶP LẠI',
        const Color(0xFFFFD998)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 21, 21, 23),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF294866), accent, .11)!,
            const Color(0xFF14283F),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: .48),
          width: 1.2),
        boxShadow: const [BoxShadow(
          color: Color(0x66040C1A), blurRadius: 20, offset: Offset(0, 13))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 19, color: accent),
            const SizedBox(width: 10),
            Expanded(child: Text(header, style: TextStyle(
              color: accent, fontSize: 11, letterSpacing: 1.0,
              fontWeight: FontWeight.w900))),
            Text('${(index + 1).toString().padLeft(2, '0')}',
              style: const TextStyle(color: Color(0xFFBDCAD8),
                fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          if (index == 1)
            Row(children: [
              Expanded(child: _MiniStatistic(
                label: 'NGÀY ĐẾN TRƯỜNG', number: '${facts.days}', accent: accent)),
              const SizedBox(width: 9),
              Expanded(child: _MiniStatistic(
                label: 'MÔN HỌC', number: '${facts.subjects}', accent: accent)),
            ])
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(story.number, style: TextStyle(
                  color: accent, fontWeight: FontWeight.w900,
                  fontSize: index == 0 || index == 10 ? 77 : 66,
                  height: 1.06,
                )),
              ),
            ),
          const SizedBox(height: 19),
          Divider(height: 1, color: accent.withValues(alpha: .24)),
          const SizedBox(height: 13),
          Text(switch (index) {
            1 => 'DỮ LIỆU LỊCH HỌC QLĐT',
            3 => 'BUỔI BẮT ĐẦU LÚC 06:45',
            4 => 'ĐẾM THEO NGÀY HỌC',
            8 => 'THỜI ĐIỂM BUỔI HỌC CUỐI',
            9 => 'GÓI GHÉM LẠI MỘT HỌC KỲ',
            _ => 'DẤU ẤN TỪ NHỮNG NGÀY ĐÃ QUA',
          }, style: const TextStyle(
            color: Color(0xFFC5D6E5), letterSpacing: .9,
            fontWeight: FontWeight.w700, fontSize: 10,
          )),
        ],
      ),
    );
  }
}

class _MiniStatistic extends StatelessWidget {
  const _MiniStatistic({
    required this.label, required this.number, required this.accent,
  });
  final String label, number;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 10, 13),
    decoration: BoxDecoration(
      color: const Color(0xFF12263E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withValues(alpha: .26)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(number,
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900,
            color: accent, height: 1.08))),
        const SizedBox(height: 9),
        Text(label, maxLines: 2, style: const TextStyle(
          fontSize: 10, color: Color(0xFFD2E0EA),
          fontWeight: FontWeight.w800, letterSpacing: .25)),
      ],
    ),
  );
}

class _DayPartBento extends StatelessWidget {
  const _DayPartBento({required this.facts});
  final RecapFacts facts;
  @override
  Widget build(BuildContext context) {
    final total = facts.morning + facts.afternoon;
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _DayTile(
          title: 'BUỔI SÁNG', value: facts.morning,
          icon: Icons.wb_sunny_outlined,
          accent: const Color(0xFFFFCE83),
          top: const Color(0xFF69492C), bottom: const Color(0xFF293E52),
          ratio: total == 0 ? 0 : facts.morning / total,
        )),
        const SizedBox(width: 12),
        Expanded(child: _DayTile(
          title: 'BUỔI CHIỀU', value: facts.afternoon,
          icon: Icons.nights_stay_outlined,
          accent: const Color(0xFFB1D3FF),
          top: const Color(0xFF31476E), bottom: const Color(0xFF1A2B4A),
          ratio: total == 0 ? 0 : facts.afternoon / total,
        )),
      ]),
      const SizedBox(height: 13),
      _RecapPanel(child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CÁCH PHÂN LOẠI', style: TextStyle(
            color: Color(0xFFFFD58B), fontWeight: FontWeight.w900,
            fontSize: 11, letterSpacing: 1.3)),
          SizedBox(height: 8),
          Text('Mỗi ca học QLĐT được đếm một lần. Trước 12:00 là sáng; từ 12:00 là chiều.',
            style: TextStyle(color: Color(0xFFD7E4F2), fontSize: 13, height: 1.5)),
        ],
      )),
    ]);
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.title, required this.value,
    required this.icon, required this.accent, required this.top,
    required this.bottom, required this.ratio});
  final String title;
  final int value;
  final IconData icon;
  final Color accent, top, bottom;
  final double ratio;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 215),
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft,
        end: Alignment.bottomRight, colors: [top, bottom]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .65), width: 1.2),
      boxShadow: const [BoxShadow(
        color: Color(0x66091429), blurRadius: 18, offset: Offset(0, 10))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 25, color: accent),
      const SizedBox(height: 13),
      Text(title, style: TextStyle(color: accent, fontSize: 10,
        letterSpacing: .6, fontWeight: FontWeight.w900)),
      const SizedBox(height: 13),
      FittedBox(fit: BoxFit.scaleDown, child: Text('$value',
        style: const TextStyle(fontSize: 58, height: 1,
          fontWeight: FontWeight.w900, color: Colors.white))),
      const SizedBox(height: 5),
      const Text('buổi học', style: TextStyle(
        color: Color(0xFFDCE7F1), fontSize: 12)),
      const SizedBox(height: 19),
      ClipRRect(borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: ratio, minHeight: 6, color: accent,
          backgroundColor: Colors.white.withValues(alpha: .16),
        )),
      const SizedBox(height: 8),
      Text('${(ratio * 100).round()}% lịch học', style: const TextStyle(
        color: Color(0xFFD6E2EE), fontSize: 11)),
    ]),
  );
}

class _SubjectBento extends StatelessWidget {
  const _SubjectBento({required this.facts});
  final RecapFacts facts;
  @override
  Widget build(BuildContext context) {
    final rows = facts.subjectCounts;
    final maximum = rows.isEmpty ? 1 : rows.first.scheduleCount;
    return _RecapPanel(highlight: true, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TẦN SUẤT THEO TỪNG MÔN', style: TextStyle(
          color: Color(0xFFFFD58B), fontSize: 11,
          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 9),
        const Text('Một hàng tương ứng một môn học. Không đếm lịch thi.',
          style: TextStyle(color: Color(0xFFD9E6F3),
            fontSize: 12, height: 1.5)),
        const SizedBox(height: 18),
        for (final item in rows) ...[
          Row(children: [
            Expanded(child: Text(item.name, maxLines: 2,
              overflow: TextOverflow.ellipsis, style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600))),
            const SizedBox(width: 9),
            Text('${item.scheduleCount} buổi', style: const TextStyle(
              color: Color(0xFFFFD58B), fontSize: 13,
              fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: item.scheduleCount / maximum, minHeight: 5,
              color: const Color(0xFFFFCE83),
              backgroundColor: const Color(0xFF3B526F),
            )),
          const SizedBox(height: 15),
        ],
        if (rows.isEmpty) const Text('Chưa có dữ liệu môn học.',
            style: TextStyle(color: Colors.white70)),
        if (facts.mostFrequentSubjects.length > 1)
          Text('Có ${facts.mostFrequentSubjects.length} môn cùng có ${facts.favoriteCount} buổi. Recap không tự chọn một môn đứng đầu.',
            style: const TextStyle(color: Color(0xFFF0D9AC),
              fontSize: 12, height: 1.5)),
      ],
    ));
  }
}

class _AttendanceBento extends StatelessWidget {
  const _AttendanceBento({required this.facts});
  final RecapFacts facts;
  @override
  Widget build(BuildContext context) {
    final rows = facts.subjectCounts
        .where((e) => e.absentSessions != null).toList();
    return _RecapPanel(highlight: true, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ĐIỂM DANH TỪNG MÔN', style: TextStyle(
          color: Color(0xFFFFD58B),
          fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        const Text('Số buổi vắng ghi nhận từ QLĐT theo từng môn LT. Không lấy tổng toàn kỳ gán cho một môn.',
          style: TextStyle(color: Color(0xFFD9E6F3), fontSize: 12, height: 1.5)),
        const SizedBox(height: 17),
        for (final item in rows) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(item.name, style: const TextStyle(
              color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600), maxLines: 2)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${item.absentSessions} buổi vắng',
                style: TextStyle(color: item.absentSessions == 0
                  ? const Color(0xFFB6E5D0) : const Color(0xFFFFCF91),
                  fontSize: 12, fontWeight: FontWeight.w900)),
              Text('${item.theorySessionCount} buổi LT có dữ liệu',
                style: const TextStyle(color: Color(0xFFB7C8D8), fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: .13), height: 1),
          const SizedBox(height: 14),
        ],
        if (rows.isEmpty) const Text('QLĐT chưa cung cấp số buổi vắng của môn nào.',
          style: TextStyle(color: Colors.white70, fontSize: 13)),
        Text('Môn có dữ liệu điểm danh: ${facts.attendanceCoveredSubjects}/${facts.subjectCounts.length}.',
          style: const TextStyle(color: Color(0xFFC7D5E4), fontSize: 11)),
      ],
    ));
  }
}

class RecapTestPanel extends StatelessWidget {
  const RecapTestPanel({
    required this.memoryVisible,
    required this.hasRealAccount,
    required this.onToggleMemory,
    required this.onOpenActual,
    required this.onTestPull,
    required this.onOpenScenario,
    super.key,
  });
  final bool memoryVisible;
  final bool hasRealAccount;
  final VoidCallback onToggleMemory, onOpenActual, onTestPull;
  final ValueChanged<RecapScenario> onOpenScenario;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text('RECAP · BỘ ĐIỀU KHIỂN',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Chế độ thật và giả lập hoàn toàn tách biệt.'),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.verified_user_rounded, size: 21),
                  SizedBox(width: 9),
                  Text('01  ·  DỮ LIỆU QLĐT THẬT',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                Text(hasRealAccount
                  ? 'Đọc học kỳ đã xác minh của tài khoản trên thiết bị này. Gọi Sync 1.7 trong lúc chạy VFX 2,8 giây.'
                  : 'Chưa có học kỳ QLĐT đã xác minh trong bản APK thử nghiệm. Cần đăng nhập và đồng bộ tại đây trước.'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: hasRealAccount ? onOpenActual : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Mở Recap thật'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: hasRealAccount ? onTestPull : null,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử Pull Reload 1.7'),
                  ),
                ),
                const SizedBox(height: 5),
                const Text('Cùng một lệnh Reload được dùng khi kéo lịch và khi mở Recap. Nếu không có phiên QLĐT trên APK này, hãy đăng nhập trước.',
                  style: TextStyle(fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Hiện nút Memory'),
            subtitle: const Text('Chỉ ép hiển thị icon; không giả dữ liệu Recap thật'),
            value: memoryVisible,
            onChanged: (_) => onToggleMemory(),
          ),
          const SizedBox(height: 10),
          const Divider(),
          ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.science_outlined),
            title: const Text('02  ·  KỊCH BẢN GIẢ LẬP',
              style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Chỉ để kiểm thử thiết kế và lời dẫn. Không lấy QLĐT.'),
            children: [
              for (final scenario in RecapScenario.values)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.bug_report_outlined, size: 18),
                  title: Text(scenario.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenScenario(scenario),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
