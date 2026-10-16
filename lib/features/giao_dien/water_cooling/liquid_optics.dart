import 'dart:math' as math;

/// Advect optical detail continuously. Velocity is a derivative, never a UV
/// position: a direction reversal must not teleport highlights across water.
class LiquidOptics {
  double offsetX = 0, offsetY = 0, energy = 0;
  double _vx = 0, _vy = 0;
  void advance(double dt, double vx, double vy, double kineticEnergy) {
    if (!dt.isFinite || dt <= 0) return;
    dt = dt.clamp(0, .05);
    final gain = 1 - math.exp(-dt / .09);
    _vx += (vx.clamp(-3.5, 3.5) - _vx) * gain;
    _vy += (vy.clamp(-3.5, 3.5) - _vy) * gain;
    offsetX += _vx * dt * .08;
    offsetY += _vy * dt * .08;
    energy += (kineticEnergy.clamp(0, 1) - energy) * gain;
  }
}
