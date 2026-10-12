import 'package:flutter/material.dart';

enum PullSyncPhase { idle, running, cancellable, success, failure }

/// Small, self-contained indicator. It never navigates to QLĐT.
class PullSyncIndicator extends StatefulWidget {
  const PullSyncIndicator({
    required this.phase,
    required this.distance,
    required this.threshold,
    required this.onCancel,
    super.key,
  });

  final PullSyncPhase phase;
  final double distance;
  final double threshold;
  final VoidCallback onCancel;

  @override
  State<PullSyncIndicator> createState() => _PullSyncIndicatorState();
}

class _PullSyncIndicatorState extends State<PullSyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _updateRotation();
  }

  @override
  void didUpdateWidget(covariant PullSyncIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _updateRotation();
  }

  void _updateRotation() {
    if (widget.phase == PullSyncPhase.running ||
        widget.phase == PullSyncPhase.cancellable) {
      _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    if (phase == PullSyncPhase.idle && widget.distance <= 0) {
      return const SizedBox.shrink();
    }

    final success = phase == PullSyncPhase.success;
    final failure = phase == PullSyncPhase.failure;
    final canCancel = phase == PullSyncPhase.cancellable;
    final spinning = phase == PullSyncPhase.running;
    final color = success
        ? const Color(0xFF22C55E)
        : failure
            ? const Color(0xFFEF4444)
            : Theme.of(context).colorScheme.primary;
    return Transform.translate(
      offset: Offset(0, phase == PullSyncPhase.idle
          ? widget.distance * .3 : 0),
      child: SizedBox(
        width: 45,
        height: 45,
        child: Material(
          elevation: 3,
          color: Theme.of(context).colorScheme.surface,
          shadowColor: Colors.black.withValues(alpha: .17),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: canCancel ? widget.onCancel : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (canCancel)
                  RotationTransition(
                    turns: _rotation,
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        value: .30,
                        strokeWidth: 2.4,
                        color: color,
                        backgroundColor: color.withValues(alpha: .12),
                      ),
                    ),
                  ),
                if (spinning)
                  RotationTransition(
                    turns: _rotation,
                    child: Icon(Icons.refresh_rounded, color: color, size: 25),
                  ),
                if (phase == PullSyncPhase.idle)
                  Transform.rotate(
                    angle: (widget.distance / widget.threshold) * 6.2831853,
                    child: Icon(Icons.refresh_rounded, color: color, size: 25),
                  ),
                if (canCancel)
                  Icon(Icons.close_rounded, color: color, size: 25),
                if (success)
                  const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 28),
                if (failure)
                  const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
