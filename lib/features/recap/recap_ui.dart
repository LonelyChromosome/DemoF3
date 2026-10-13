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
  bool _failed = false;
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
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facts = _facts;
    final slides = facts == null ? <_Story>[] : _stories(facts);
    const tones = <Color>[
      Color(0xFF142354), Color(0xFF14425A), Color(0xFF203968),
      Color(0xFF4A2B5F), Color(0xFF27415C), Color(0xFF39335A),
      Color(0xFF244854), Color(0xFF2C375B), Color(0xFF52324A),
      Color(0xFF2C3D5A), Color(0xFF162344),
    ];
    final tone = tones[_index.clamp(0, tones.length - 1)];
    return Scaffold(
      backgroundColor: const Color(0xFF0A193A),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tone, const Color(0xFF07132B)],
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(
              child: CustomPaint(painter: const _AmbientPainter()),
            )),
            if (facts == null && !_failed)
              const Center(child: _LoadingMemory())
            else if (_failed)
              Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chưa thể mở hồi tưởng lúc này.',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ))
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_index == slides.length - 1) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _index++);
                  }
                },
                child: SizedBox.expand(child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 74, 28, 58),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 410),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.06, .1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _StoryBody(
                      key: ValueKey<int>(_index),
                      story: slides[_index],
                    ),
                  ),
                )),
              ),
            if (facts != null)
              Positioned(
                left: 22, right: 65, top: 27,
                child: Row(
                  children: List.generate(slides.length, (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i <= _index ? const Color(0xFFFFD888)
                            : Colors.white.withValues(alpha: .2),
                      ),
                    ),
                  )),
                ),
              ),
            Positioned(
              top: 10, right: 11,
              child: IconButton(
                tooltip: 'Đóng Recap',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ),
            if (facts != null)
              Positioned(
                left: 24, right: 24, bottom: 18,
                child: Row(children: [
                  Text('${_index + 1}/${slides.length}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const Spacer(),
                  Text(_index == slides.length - 1
                      ? 'Chạm để hoàn tất' : 'Chạm để tiếp tục',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFFFDF9F).withValues(alpha: .08);
    canvas.drawCircle(Offset(size.width * .98, size.height * .22),
      size.width * .5, p);
    final q = Paint()..color = Colors.white.withValues(alpha: .025);
    canvas.drawCircle(Offset(size.width * .04, size.height * .85),
      size.width * .44, q);
  }
  @override
  bool shouldRepaint(_AmbientPainter old) => false;
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
  const _StoryBody({required this.story, super.key});
  final _Story story;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(story.eyebrow, style: const TextStyle(
        letterSpacing: 2, fontSize: 12,
        color: Color(0xFFFFD888), fontWeight: FontWeight.bold)),
      const SizedBox(height: 27),
      Text(story.heading, style: const TextStyle(
        color: Colors.white, fontSize: 33, height: 1.15,
        fontWeight: FontWeight.w800)),
      const SizedBox(height: 32),
      FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(story.number, style: const TextStyle(
          fontSize: 65, height: 1.05, fontWeight: FontWeight.w900,
          color: Color(0xFFFFDF9F))),
      ),
      const SizedBox(height: 25),
      Text(story.caption, style: const TextStyle(
        color: Colors.white70, fontSize: 17, height: 1.5)),
    ],
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
