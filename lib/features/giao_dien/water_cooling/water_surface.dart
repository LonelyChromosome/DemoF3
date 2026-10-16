import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'water_config.dart';
import 'water_engine.dart';
import 'water_field.dart';
import 'water_routes.dart';

class WaterScope extends InheritedWidget {
  const WaterScope({required this.engine, required super.child, super.key});
  final WaterEngine engine;
  static WaterEngine? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<WaterScope>()?.engine;
  @override
  bool updateShouldNotify(WaterScope old) => engine != old.engine;
}

class WaterStage extends StatefulWidget {
  const WaterStage({
    required this.config,
    required this.child,
    this.enabled = true,
    super.key,
  });
  final WaterConfig config;
  final Widget child;
  final bool enabled;
  @override
  State<WaterStage> createState() => _WaterStageState();
}

class _WaterStageState extends State<WaterStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final engine = WaterEngine(widget.config);
  late final ticker = createTicker(_frame);
  Duration? _last;
  bool _foreground = true, _visible = true, _running = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WaterRouteObserver.visible.addListener(_lifecycle);
    if (widget.enabled) _activate();
  }

  void _activate() {
    WaterEngine.active = engine;
    engine.prepareShaders();
    engine.trigger(WaterEvent.activation);
    unawaited(
      WaterEngine.warmup()
          .then((_) {
            if (mounted) {
              engine.prepareShaders();
              setState(() => _error = null);
            }
          })
          .catchError((Object e) {
            if (mounted) setState(() => _error = 'Không nạp được bể nước');
          }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.of(context);
    _lifecycle();
  }

  @override
  void didUpdateWidget(WaterStage old) {
    super.didUpdateWidget(old);
    engine.update(widget.config);
    if (widget.enabled && !old.enabled) _activate();
    if (!widget.enabled && WaterEngine.active == engine)
      WaterEngine.active = null;
    if (old.enabled != widget.enabled ||
        old.config.tilt != widget.config.tilt ||
        old.config.reduced != widget.config.reduced)
      _lifecycle(forceSensors: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      engine.eventAge = 20;
    }
    _lifecycle();
  }

  void _lifecycle({bool forceSensors = false}) {
    final run =
        widget.enabled &&
        _foreground &&
        _visible &&
        WaterRouteObserver.visible.value;
    if (run == _running && !forceSensors) return;
    final changed = run != _running;
    _running = run;
    _last = null;
    if (changed) {
      if (run) {
        engine.resume();
      } else {
        engine.suspend();
      }
    }
    if (run && !ticker.isActive) ticker.start();
    if (!run && ticker.isActive) ticker.stop();
    unawaited(engine.sensors(run));
  }

  void _frame(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (engine.config.reduced && dt < 1 / 31) {
      _last = last;
      return;
    }
    engine.tick(dt.clamp(0, .05));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WaterRouteObserver.visible.removeListener(_lifecycle);
    ticker.dispose();
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WaterScope(
    engine: engine,
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (widget.enabled) {
          engine.tapPosition = e.localPosition;
          engine.trigger(WaterEvent.tap);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: widget.enabled ? _ReservoirPainter(engine) : null,
            ),
          ),
          AnimatedBuilder(
            animation: engine,
            child: widget.child,
            builder: (context, child) {
              final age = engine.eventAge;
              final shift =
                  widget.enabled &&
                      !engine.config.reduced &&
                      engine.event == WaterEvent.mechanical &&
                      age < .4
                  ? math.sin(age * 35) * math.exp(-age * 12) * 1.5
                  : 0.0;
              return Transform.translate(
                offset: Offset(shift, 0),
                child: child,
              );
            },
          ),
          if (_error != null)
            Positioned(
              bottom: 4,
              left: 16,
              child: IgnorePointer(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: widget.enabled
                      ? _BootPainter(engine, MediaQuery.paddingOf(context))
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void setRgbUniforms(
  ui.FragmentShader s,
  WaterEngine e,
  Size size,
  Offset origin,
  Size world,
) {
  final c = e.config;
  s
    ..setFloat(0, size.width)
    ..setFloat(1, size.height)
    ..setFloat(2, origin.dx)
    ..setFloat(3, origin.dy)
    ..setFloat(4, math.max(1, world.width))
    ..setFloat(5, math.max(1, world.height))
    ..setFloat(6, e.seconds)
    ..setFloat(7, c.mode.index.toDouble())
    ..setFloat(8, c.speed)
    ..setFloat(9, c.brightness)
    ..setFloat(10, c.intensity)
    ..setFloat(11, c.direction)
    ..setFloat(12, c.waveWidth)
    ..setFloat(13, c.beamWidth)
    ..setFloat(14, c.colors.length.toDouble());
  for (var i = 0; i < 4; i++) {
    final color = c.colors[i % c.colors.length];
    s
      ..setFloat(15 + i * 3, color.r)
      ..setFloat(16 + i * 3, color.g)
      ..setFloat(17 + i * 3, color.b);
  }
  final a = e.eventAge;
  final gain =
      (e.event == WaterEvent.success || e.event == WaterEvent.illumination)
      ? math.exp(-a * 3)
      : e.event == WaterEvent.day
      ? .4 * math.exp(-a * 5)
      : e.pumping
      ? .2
      : 0.0;
  s
    ..setFloat(27, gain)
    ..setFloat(
      28,
      e.event == WaterEvent.warning && a < 1.2
          ? (.5 + .5 * math.sin(a * 22)) * math.exp(-a * 2)
          : 0,
    );
}

/// The same fluid geometry/material pipeline is used in the app and preview.
class WaterReservoirViewport extends StatelessWidget {
  const WaterReservoirViewport({super.key});
  @override
  Widget build(BuildContext context) {
    final engine = WaterScope.of(context);
    return engine == null
        ? const SizedBox()
        : RepaintBoundary(
            child: CustomPaint(
              painter: _ReservoirPainter(engine, preview: true),
              child: const SizedBox.expand(),
            ),
          );
  }
}

class _ReservoirPainter extends CustomPainter {
  _ReservoirPainter(this.e, {this.preview = false}) : super(repaint: e);
  final WaterEngine e;
  final bool preview;
  final pen = Paint()..isAntiAlias = true;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (!preview) e.setViewport(size.width / math.max(1, size.height));
    final p = e.physics, c = e.config;
    p.configure(c.fill, e.aspect, reduced: c.reduced);
    canvas.drawColor(const Color(0xFF08050E), BlendMode.src);
    if (e.restoring) return;
    e.rebuildSurface();
    final shader = e.reservoirShader;
    if (shader == null) return;
    setRgbUniforms(shader, e, size, Offset.zero, size);
    shader
      ..setFloat(29, c.coolant.r)
      ..setFloat(30, c.coolant.g)
      ..setFloat(31, c.coolant.b)
      ..setFloat(32, c.refraction)
      ..setFloat(33, e.optics.offsetX)
      ..setFloat(34, e.optics.offsetY)
      ..setFloat(35, e.optics.energy)
      ..setFloat(36, p.layerDepth);
    final path = e.surface.scaled(size, p.aspect, preview: preview);
    final depthGain = math.sqrt(p.layerDepth.clamp(0.0, 1.0));
    pen
      ..style = PaintingStyle.fill
      ..color = Colors.white
      ..shader = shader;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, pen);
    pen
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * depthGain
      ..color = Color.lerp(
        const Color(0xFFA4B8D3),
        c.coolant,
        .4,
      )!.withValues(alpha: .5 * depthGain);
    canvas.drawPath(path, pen);
    canvas.save();
    canvas.clipPath(path);
    pen
      ..strokeWidth = .7
      ..color = const Color(0x80DEE7F2);
    // Sparse air bubbles inside the liquid, never a texture of particle dots.
    for (var i = 0; i < (c.bubbles * 7).round(); i++) {
      final x = (.13 + i * .137) % 1,
          y = 1 - ((e.seconds * .045 + i * .19) % 1);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        1 + i % 2.toDouble(),
        pen,
      );
    }
    canvas.restore();
    pen
      ..style = PaintingStyle.fill
      ..color = const Color(0x103E314B);
    canvas.drawRect(Rect.fromLTWH(1, 0, 1, size.height), pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReservoirPainter old) =>
      old.e != e || old.preview != preview;
}

class WaterBlock extends StatefulWidget {
  const WaterBlock({
    required this.child,
    this.padding,
    this.width,
    this.constraints,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BoxConstraints? constraints;
  @override
  State<WaterBlock> createState() => _WaterBlockState();
}

class _WaterBlockState extends State<WaterBlock> {
  WaterEngine? engine;
  final registration = Object();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = WaterScope.of(context);
    if (engine != next) engine?.blocks.remove(registration);
    engine = next;
  }

  @override
  void dispose() {
    engine?.blocks.remove(registration);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      constraints: widget.constraints,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: const Color(0xB5150C20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
    return ClipRRect(
      clipper: const _ChamberClipper(),
      child: RepaintBoundary(
        child: Builder(
          builder: (c) => CustomPaint(
            foregroundPainter: engine == null
                ? null
                : _TubePainter(engine!, c, registration),
            child: box,
          ),
        ),
      ),
    );
  }
}

class _ChamberClipper extends CustomClipper<RRect> {
  const _ChamberClipper();
  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
  @override
  bool shouldReclip(_ChamberClipper old) => false;
}

class _TubePainter extends CustomPainter {
  _TubePainter(this.e, this.context, this.registration) : super(repaint: e);
  final WaterEngine e;
  final BuildContext context;
  final Object registration;
  final pen = Paint()..isAntiAlias = true;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !e.config.border) return;
    final render = context.findRenderObject();
    final origin = render is RenderBox && render.hasSize
        ? render.localToGlobal(Offset.zero)
        : Offset.zero;
    final world = MediaQuery.sizeOf(context), c = e.config;
    e.blocks[registration] = (origin & size, e.frame);
    final tube = math.min(c.tubeWidth, math.max(.8, size.height * .04));
    final rect = (Offset.zero & size).deflate(tube + 1.5),
        r = RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(tube + 1.5),
          const Radius.circular(12),
        );
    pen
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = tube + 1.8
      ..color = const Color(0xFF39303F);
    canvas.drawRRect(r, pen);
    pen
      ..strokeWidth = tube + 1
      ..color = const Color(0xFF060B0E);
    canvas.drawRRect(r, pen);
    final s = e.rgbShader;
    if (s != null) {
      setRgbUniforms(s, e, size, origin, world);
      pen.shader = s;
    } else {
      pen.color = MasterRgbField.sample(
        c,
        origin.dx / world.width,
        origin.dy / world.height,
        e.seconds,
      );
    }
    pen.strokeWidth = tube;
    canvas.drawRRect(r, pen);
    if (c.glow > 0) {
      pen
        ..strokeWidth = tube + 4 * c.glow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * c.glow);
      canvas.drawRRect(r, pen);
      pen.maskFilter = null;
    }
    pen
      ..shader = null
      ..color = const Color(0x42ECDDF4)
      ..strokeWidth = .65;
    canvas.drawRRect(r.shift(const Offset(0, -.65)), pen);
    for (final y in [rect.top + 14, rect.bottom - 14]) {
      if (rect.height < 42) break;
      final fit = Rect.fromLTWH(rect.left - 3, y - 3.5, 7, 7);
      pen
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          const Color(0xFF182027),
          const Color(0xFF6B777F),
          c.metal,
        )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(fit, const Radius.circular(1.5)),
        pen,
      );
      pen
        ..color = const Color(0xFF0B1115)
        ..strokeWidth = 1;
      canvas.drawLine(fit.topCenter, fit.bottomCenter, pen);
    }
  }

  @override
  bool shouldRepaint(_TubePainter old) => true;
}

class _BootPainter extends CustomPainter {
  _BootPainter(this.e, this.padding) : super(repaint: e);
  final WaterEngine e;
  final EdgeInsets padding;
  final pen = Paint()..isAntiAlias = true;
  @override
  void paint(Canvas canvas, Size size) {
    final safe = Rect.fromLTRB(
      12,
      padding.top + 8,
      size.width - 12,
      size.height - padding.bottom - 8,
    );
    canvas.clipRect(safe);
    if (e.event == WaterEvent.tap && e.eventAge < .32) {
      final p = e.eventAge / .32;
      pen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = e.config.colors.first.withValues(alpha: (1 - p) * .45);
      canvas.drawCircle(e.tapPosition, 5 + 22 * p, pen);
      pen.style = PaintingStyle.fill;
    }
    if (e.event == WaterEvent.activation && e.eventAge < 1.8) {
      final p = (e.eventAge / 1.8).clamp(0.0, 1.0);
      pen.color = Colors.black.withValues(alpha: (1 - p) * .65);
      canvas.drawRect(safe, pen);
      var index = 0;
      for (final entry in e.blocks.values) {
        if (e.frame - entry.$2 > 2 || !entry.$1.overlaps(safe)) continue;
        final a = ((p - index * .12) * 3).clamp(0.0, 1.0) * (1 - p);
        pen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = e.config.colors.first.withValues(alpha: a);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            entry.$1.deflate(3),
            const Radius.circular(12),
          ),
          pen,
        );
        index++;
      }
      pen
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          Offset(size.width * (p * 1.4 - .2), 0),
          Offset(size.width * p * 1.4, 0),
          [
            Colors.transparent,
            e.config.colors.first.withValues(alpha: (1 - p) * .25),
          ],
        );
      canvas.drawRect(safe, pen);
      pen.shader = null;
    } else if (e.eventAge < .9 && e.event != WaterEvent.tap) {
      pen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color =
            (e.event == WaterEvent.warning
                    ? const Color(0xFFFF6244)
                    : e.config.colors.first)
                .withValues(alpha: (1 - e.eventAge / .9) * .5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(safe.deflate(2), const Radius.circular(16)),
        pen,
      );
      pen.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(_BootPainter old) => true;
}

class WaterDivider extends StatelessWidget {
  const WaterDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final e = WaterScope.of(context);
    return SizedBox(
      height: 1.6,
      width: double.infinity,
      child: e == null
          ? const SizedBox()
          : Builder(builder: (c) => CustomPaint(painter: _LinePainter(e, c))),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.e, this.context) : super(repaint: e);
  final WaterEngine e;
  final BuildContext context;
  final pen = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    final r = context.findRenderObject();
    if (r is! RenderBox || !r.hasSize) return;
    final s = e.rgbShader;
    if (s != null) {
      setRgbUniforms(
        s,
        e,
        size,
        r.localToGlobal(Offset.zero),
        MediaQuery.sizeOf(context),
      );
      pen.shader = s;
    } else {
      pen.color = e.config.colors.first;
    }
    canvas.drawRect(Offset.zero & size, pen);
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}
