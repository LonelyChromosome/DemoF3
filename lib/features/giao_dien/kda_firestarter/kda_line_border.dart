import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'kda_line_motion.dart';
import 'kda_runtime.dart';

/// One ticker/analyser for all visible app cards; never drives Android widgets.
class KdaLineHost extends StatefulWidget {
  const KdaLineHost({required this.child, super.key});
  final Widget child;
  @override State<KdaLineHost> createState() => _KdaLineHostState();
}
class _KdaLineHostState extends State<KdaLineHost> with SingleTickerProviderStateMixin {
  final motion = KdaLineMotion();
  final runtime = KdaRuntime.instance;
  late final Ticker ticker;
  Duration last = Duration.zero;
  bool get active => runtime.enabled && runtime.foreground && runtime.cardsVisible && runtime.config.visualizer;
  @override void initState() {
    super.initState(); ticker = createTicker(tick);
    runtime.addListener(sync); runtime.spectrum.addListener(input);
  }
  void sync() {
    if (!active) { ticker.stop(); motion.reset(); }
  }
  void input() {
    if (!active) return;
    motion.input(runtime.spectrum.value);
    if ((motion.pulses.isNotEmpty || runtime.spectrum.value.any((v) => v > .055)) && !ticker.isActive) {
      last = Duration.zero; ticker.start();
    }
  }
  void tick(Duration elapsed) {
    final dt = (elapsed - last).inMicroseconds / 1000000;
    if (dt < 1 / 32) return;
    last = elapsed;
    if (!active) { sync(); return; }
    motion.step(dt);
    if (!motion.moving) ticker.stop();
  }
  @override void dispose() {
    runtime.removeListener(sync); runtime.spectrum.removeListener(input);
    ticker.dispose(); motion.dispose(); super.dispose();
  }
  @override Widget build(BuildContext context) => KdaLineScope(motion: motion, child: widget.child);
}
class KdaLineScope extends InheritedWidget {
  const KdaLineScope({required this.motion, required super.child, super.key});
  final KdaLineMotion motion;
  static KdaLineMotion? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<KdaLineScope>()?.motion;
  @override bool updateShouldNotify(KdaLineScope oldWidget) => oldWidget.motion != motion;
}

class KdaLineBorder extends StatelessWidget {
  const KdaLineBorder({required this.child, required this.color, required this.radius, super.key});
  final Widget child;
  final Color color;
  final double radius;
  @override Widget build(BuildContext context) {
    final motion = KdaLineScope.maybeOf(context);
    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned.fill(child: IgnorePointer(child: ExcludeSemantics(child: RepaintBoundary(
        child: CustomPaint(painter: KdaLinePainter(motion, color, radius, KdaRuntime.instance.config.intensity)),
      )))),
    ]);
  }
}

class KdaLinePainter extends CustomPainter {
  KdaLinePainter(this.motion, this.color, this.radius, this.intensity) : super(repaint: motion);
  final KdaLineMotion? motion;
  final Color color;
  final double radius, intensity;
  Size? _size;
  Path? _base;
  double perimeter = 0;
  final List<Offset> _points = [], _normals = [];
  void _geometry(Size size) {
    if (_size == size) return;
    _size = size; _points.clear(); _normals.clear();
    _base = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(.6), Radius.circular(radius)));
    final metric = _base!.computeMetrics().first;
    perimeter = metric.length;
    final count = (perimeter / 7).ceil().clamp(48, 160);
    for (var i = 0; i <= count; i++) {
      final tangent = metric.getTangentForOffset(math.min(perimeter - .001, (i % count) * perimeter / count))!;
      _points.add(tangent.position); _normals.add(Offset(-tangent.vector.dy, tangent.vector.dx));
    }
  }
  @override void paint(Canvas canvas, Size size) {
    if (size.width < 2 || size.height < 2) return;
    _geometry(size);
    final m = motion;
    final core = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = .9..strokeJoin = StrokeJoin.round;
    if (m == null || !m.moving) { canvas.drawPath(_base!, core); return; }
    // A quiet centre string anchors the original geometry. Two displaced strings
    // share exactly opposite offsets, merging back into this line after a kick.
    canvas.drawPath(_base!, core..color = color.withValues(alpha: .28));
    // Evaluate displacement once; reuse it for both symmetric strands. One
    // combined path and translucent strokes avoid per-card blur-mask passes.
    final offsets = List<double>.generate(_points.length, (i) =>
        m.displacement(i / (_points.length - 1), perimeter, intensity), growable: false);
    final path = Path();
    for (final sign in const [-1.0, 1.0]) {
      for (var i = 0; i < _points.length; i++) {
        final p = _points[i] + _normals[i] * offsets[i] * sign;
        if (i == 0) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
      }
      path.close();
    }
    canvas.drawPath(path, core..strokeWidth = 5..color = color.withValues(alpha: .055 + m.energy * .035));
    canvas.drawPath(path, core..strokeWidth = 2.5..color = color.withValues(alpha: .12 + m.energy * .10));
    canvas.drawPath(path, core..strokeWidth = 1..color = color.withValues(alpha: .72 + .25 * m.energy));
  }
  @override bool shouldRepaint(KdaLinePainter oldDelegate) => oldDelegate.motion != motion || oldDelegate.color != color || oldDelegate.radius != radius || oldDelegate.intensity != intensity;
}
