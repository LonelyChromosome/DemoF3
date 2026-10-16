import 'dart:math' as math;

/// Sensor callbacks only publish targets; the simulation consumes them on its
/// own clock. Reset across subscription changes so old impulses cannot replay.
class WaterMotionInput {
  bool active = false;
  double gx = 0, gy = 9.81, gz = 0, ax = 0, ay = 0;
  double _gx = 0, _gy = 9.81, _gz = 0, _ax = 0, _ay = 0;

  void reset() {
    active = false;
    ax = ay = _ax = _ay = 0;
  }

  void accept(double x, double y, double z, double a, double b) {
    if (![x, y, z, a, b].every((v) => v.isFinite)) return;
    _gx = x.clamp(-15, 15);
    _gy = y.clamp(-15, 15);
    _gz = z.clamp(-15, 15);
    final magnitude = math.sqrt(a * a + b * b);
    final gain = magnitude > .18 ? (magnitude - .18) / magnitude : 0.0;
    _ax = (a * gain).clamp(-55, 55);
    _ay = (b * gain).clamp(-55, 55);
    if (!active) {
      gx = _gx;
      gy = _gy;
      gz = _gz;
      ax = ay = 0;
      active = true;
    }
  }

  void advance(double dt) {
    if (!active || !dt.isFinite || dt <= 0) return;
    final gravityGain = 1 - math.exp(-dt / .04);
    final impulseGain = 1 - math.exp(-dt / .025);
    gx += (_gx - gx) * gravityGain;
    gy += (_gy - gy) * gravityGain;
    gz += (_gz - gz) * gravityGain;
    ax += (_ax - ax) * impulseGain;
    ay += (_ay - ay) * impulseGain;
  }
}
