import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pull gesture is presentation-only until the distance reaches the threshold.
/// No route, loading screen, or WebView is created here.
class PullSyncSurface extends StatefulWidget {
  const PullSyncSurface({
    super.key,
    required this.child,
    required this.onReload,
    required this.color,
    this.enabled = true,
  });

  final Widget child;
  final Future<void> Function() onReload;
  final Color color;
  final bool enabled;

  @override
  State<PullSyncSurface> createState() => _PullSyncSurfaceState();
}

class _PullSyncSurfaceState extends State<PullSyncSurface>
    with SingleTickerProviderStateMixin {
  // v1.3: double the drag travel and the icon's visual path.
  static const double _threshold = 184;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _top = true;
  bool _eligible = false;
  bool _busy = false;
  double? _pointerStart;
  double _distance = 0;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    // Never swallow scroll notifications: existing day/week navigators work.
    _top = notification.metrics.extentBefore <= .5;
    return false;
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _busy) return;
    _pointerStart = event.position.dy;
    _eligible = _top;
  }

  void _move(PointerMoveEvent event) {
    if (!widget.enabled || _busy || !_eligible || _pointerStart == null) return;
    final delta = event.position.dy - _pointerStart!;
    final next = delta <= 0 ? 0.0 : math.min(delta * .66, _threshold);
    if (next != _distance) setState(() => _distance = next);
    if (next >= _threshold) _startReload();
  }

  void _up(PointerEvent event) {
    _pointerStart = null;
    _eligible = false;
    if (!_busy && _distance > 0) setState(() => _distance = 0);
  }

  Future<void> _startReload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _distance = _threshold;
    });
    _spin.repeat();
    try {
      await widget.onReload();
    } finally {
      _spin.stop();
      _spin.reset();
      if (mounted) {
        setState(() {
          _busy = false;
          _distance = 0;
          _pointerStart = null;
          _eligible = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _distance > 0 || _busy;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            widget.child,
            if (show)
              Positioned(
                top: _distance * .55 - 34,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x25000000),
                            blurRadius: 9,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: AnimatedBuilder(
                          animation: _spin,
                          builder: (context, child) => Transform.rotate(
                            angle: 2 * math.pi *
                                (_distance / _threshold + (_busy ? _spin.value : 0)),
                            child: child,
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 24,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
