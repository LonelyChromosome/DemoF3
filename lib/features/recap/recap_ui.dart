import 'dart:async';
import 'dart:math' as math;
import 'package:better_phenikaa_schedule/features/recap/recap_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/material.dart';

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

  void _next(int count) {
    if (_index >= count - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
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
    return Scaffold(
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
                            color: facts.preview
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
                            Icon(facts.preview ? Icons.science_outlined :
                              Icons.verified_user_outlined,
                              color: facts.preview ? const Color(0xFFFFCCB0)
                                : const Color(0xFFA1EDD2), size: 15),
                            const SizedBox(width: 7),
                            Flexible(child: Text(
                              facts.preview ? 'GIẢ LẬP · KHÔNG PHẢI QLĐT'
                                : 'QLĐT · DỮ LIỆU THẬT',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: facts.preview
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
                const SizedBox(height: 12),
                Expanded(child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _next(stories.length),
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
                    ),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Text('${_index + 1} / ${stories.length}',
                      style: const TextStyle(color: Color(0xFFAFBCD0),
                        fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _next(stories.length),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                      label: Text(_index == stories.length - 1
                        ? 'Hoàn tất' : 'Tiếp tục'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFDEA0),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
        ])),
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
      ? const _Story('ĐIỂM DANH', 'Còn một chút chưa rõ', '—',
          'Không đủ dữ liệu chuyên cần để kết luận. Vậy nên mình sẽ không đoán.')
      : perfect
      ? const _Story('ĐIỂM DANH', 'Trọn vẹn từng buổi học', '0',
          'Tất cả buổi học đã được xác nhận. Một lời khen dành cho bạn!')
      : f.absence == 0
      ? const _Story('ĐIỂM DANH', 'Chưa ghi nhận buổi vắng', '0',
          'Đây là số buổi vắng đã ghi nhận, không phải xác nhận có mặt toàn bộ.')
      : _Story('ĐIỂM DANH', 'Có những buổi mình lỡ hẹn',
          '${f.absence}',
          'Môn ghi nhận nhiều buổi vắng nhất: ${f.mostAbsent ?? 'chưa xác định'}. Những ngày mới vẫn còn ở phía trước.');
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
    _Story('SÁNG & CHIỀU', 'Lịch học của bạn thường bắt đầu lúc nào?',
      '${f.morning} / ${f.afternoon}', 'Số buổi sáng / số buổi chiều.'),
    _Story('6 GIỜ 45', 'Những buổi sáng thật sớm',
      '${f.early}', f.early == 0
        ? 'Học kỳ này không có lớp bắt đầu đúng 6:45.'
        : 'Đôi khi ngày học bắt đầu trước cả khi phố phường thức giấc.'),
    _Story('NGÀY BẬN RỘN', 'Một ngày có rất nhiều lịch học',
      '${f.busiestCount} buổi', f.busiest == null
        ? 'Chưa có lịch học để xác định.'
        : 'Ngày ${_d(f.busiest!)} đã chứa nhiều buổi học hơn mọi ngày khác.'),
    _Story('MÔN GẮN BÓ', f.favorite,
      '${f.favoriteCount} buổi',
      'Có những môn xuất hiện trên lịch nhiều đến mức trở nên quen thuộc.'),
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
  const _StoryBody({required this.story, required this.index, super.key});
  final _Story story;
  final int index;

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
            _RecapPanel(
              highlight: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded,
                      size: 17, color: Color(0xFFFFD68C)),
                    const SizedBox(width: 9),
                    const Text('DẤU ẤN HỌC KỲ',
                      style: TextStyle(
                        color: Color(0xFFE1C996), letterSpacing: 1.25,
                        fontSize: 11, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${(index + 1).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Color(0xFFB6C8D9),
                        fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(story.number,
                        style: const TextStyle(
                          fontSize: 66, height: 1.08,
                          color: Color(0xFFFFDEA0),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(height: 1,
                    color: const Color(0xFF8096A8).withValues(alpha: .35)),
                  const SizedBox(height: 13),
                  Row(children: [
                    const Icon(Icons.stars_rounded,
                      size: 15, color: Color(0xFFCFB88A)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text(
                      'TỪ LỊCH HỌC CỦA BẠN',
                      style: TextStyle(color: Color(0xFFCCD8E6),
                        fontSize: 10, letterSpacing: 1.2,
                        fontWeight: FontWeight.w700),
                    )),
                  ]),
                ],
              ),
            ),
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

class RecapTestPanel extends StatelessWidget {
  const RecapTestPanel({
    required this.memoryVisible,
    required this.onToggleMemory,
    required this.onOpenActual,
    required this.onOpenScenario,
    super.key,
  });
  final bool memoryVisible;
  final VoidCallback onToggleMemory, onOpenActual;
  final ValueChanged<RecapScenario> onOpenScenario;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text('RECAP · PANEL KIỂM THỬ',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Các tình huống dùng dữ liệu giả, không ghi đè dữ liệu học tập.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenActual,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Recap thật + đồng bộ nền'),
          ),
          SwitchListTile(
            value: memoryVisible,
            title: const Text('Hiện nút Memory'),
            subtitle: const Text('Bật/tắt biểu tượng góc trái'),
            onChanged: (_) => onToggleMemory(),
          ),
          const Divider(),
          const Text('KỊCH BẢN THỬ NGHIỆM',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          for (final scenario in RecapScenario.values)
            ListTile(
              dense: true,
              title: Text(scenario.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpenScenario(scenario),
            ),
        ],
      ),
    ),
  );
}
