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
    motion.input(runtime.spectrum.value, timestampSeconds: runtime.captureTimeUs == null ? null : runtime.captureTimeUs! / 1000000);
    if (motion.moving && !ticker.isActive) {
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
  Rect _bounds = Rect.zero;
  final List<Offset> _points = [], _normals = [];
  void _geometry(Size size) {
    if (_size == size) return;
    _size = size; _points.clear(); _normals.clear();
    final inset = math.min(3.0, (math.min(size.width, size.height) - 1) / 2);
    _bounds = (Offset.zero & size).deflate(inset);
    final r = radius.clamp(0.0, math.min(_bounds.width, _bounds.height) / 2);
    _base = Path()..addRRect(RRect.fromRectAndRadius(_bounds, Radius.circular(r)));
    // Sample one quadrant and reflect it exactly. This avoids path-metric
    // sampling drifting out of phase between the top and bottom borders.
    final points = <Offset>[], normals = <Offset>[];
    void segment(Offset a, Offset b, Offset normal) {
      final count = math.max(1, ((b - a).distance / 6).ceil());
      for (var i = 1; i <= count; i++) {
        points.add(Offset.lerp(a, b, i / count)!); normals.add(normal);
      }
    }
    points.add(Offset(_bounds.center.dx, _bounds.top));
    normals.add(const Offset(0, 1));
    segment(points.last, Offset(_bounds.right - r, _bounds.top), const Offset(0, 1));
    final arcCenter = Offset(_bounds.right - r, _bounds.top + r);
    final arcCount = math.max(1, (math.pi * r / 12).ceil());
    for (var i = 1; i <= arcCount; i++) {
      final angle = -math.pi / 2 + math.pi / 2 * i / arcCount;
      final radial = Offset(math.cos(angle), math.sin(angle));
      points.add(arcCenter + radial * r); normals.add(-radial);
    }
    segment(points.last, Offset(_bounds.right, _bounds.center.dy), const Offset(-1, 0));
    void quadrant(bool flipX, bool flipY, bool reverse, bool skipFirst) {
      for (var j = skipFirst ? 1 : 0; j < points.length; j++) {
        final i = reverse ? points.length - 1 - j : j;
        final p = points[i], n = normals[i];
        _points.add(Offset(flipX ? 2 * _bounds.center.dx - p.dx : p.dx,
            flipY ? 2 * _bounds.center.dy - p.dy : p.dy));
        _normals.add(Offset(flipX ? -n.dx : n.dx, flipY ? -n.dy : n.dy));
      }
    }
    quadrant(false, false, false, false);
    quadrant(false, true, true, true);
    quadrant(true, true, false, true);
    quadrant(true, false, true, true);
  }
  @override void paint(Canvas canvas, Size size) {
    if (size.width < 2 || size.height < 2) return;
    _geometry(size);
    final m = motion;
    final core = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = .9..strokeJoin = StrokeJoin.round;
    // Glow and displacement are confined to this card, even at maximum input.
    canvas.save(); canvas.clipRect(Offset.zero & size);
    if (m == null || !m.moving) {
      canvas.drawPath(_base!, core); canvas.restore(); return;
    }
    canvas.drawPath(_base!, core..color = color.withValues(alpha: .28));
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final offset = m.displacement((_points[i].dx - _bounds.left) / _bounds.width, _bounds.width, intensity);
      final p = _points[i] + _normals[i] * offset;
      if (i == 0) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
    }
    path.close();
    canvas.drawPath(path, core..strokeWidth = 5..color = color.withValues(alpha: .055 + m.energy * .035));
    canvas.drawPath(path, core..strokeWidth = 2.5..color = color.withValues(alpha: .12 + m.energy * .10));
    canvas.drawPath(path, core..strokeWidth = 1..color = color.withValues(alpha: .72 + .25 * m.energy));
    canvas.restore();
  }
  @override bool shouldRepaint(KdaLinePainter oldDelegate) => oldDelegate.motion != motion || oldDelegate.color != color || oldDelegate.radius != radius || oldDelegate.intensity != intensity;
}
