import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Shared, audio-driven string motion. Silence never generates a travelling wave.
class KdaLineMotion extends ChangeNotifier {
  double energy = 0, bass = 0, treble = 0, sustained = 0;
  double _energy = 0, _bass = 0, _treble = 0, _meanBass = 0;
  double _age = 10, _sinceBeat = 10;
  double flow = 0, phase = 0, density = 0;
  double _beatDensity = 0;
  /// Continuous displacement is fed only by a fresh, non-silent audio source.
  bool get hasFlow => flow > .008;
  final List<KdaLinePulse> pulses = [];
  int beatCount = 0;
  bool get moving => energy > .001 || hasFlow || pulses.isNotEmpty;
  double get climax => ((sustained - .28) / .35).clamp(0.0, 1.0);

  void input(List<double> bands) {
    double rms(int start, int end) {
      var sum = 0.0, count = 0;
      for (var i = start; i < end && i < bands.length; i++) {
        final v = bands[i].isFinite ? bands[i].clamp(0.0, 1.0) : 0.0;
        sum += v * v; count++;
      }
      return count == 0 ? 0 : math.sqrt(sum / count);
    }
    _energy = rms(0, 44); _bass = rms(0, 14); _treble = rms(28, 48);
    _age = 0;
    // Adaptive onset plus a refractory period: individual kicks, not every FFT.
    if (_bass > .12 && _bass > _meanBass * 1.22 + .035 && _sinceBeat > .18) {
      final strength = ((_bass - _meanBass) * 2.2 + _bass * .55).clamp(0.0, 1.0);
      pulses.add(KdaLinePulse(strength, beatCount.isEven ? .125 : .625));
      if (pulses.length > 4) pulses.removeAt(0);
      _beatDensity = math.min(1.0, _beatDensity + .28);
      beatCount++; _sinceBeat = 0;
    }
  }

  void step(double dt) {
    dt = dt.clamp(0.0, .1);
    _age += dt; _sinceBeat += dt;
    final live = _age < .35;
    double smooth(double from, double to, double attack, double release) =>
        from + (to - from) * (1 - math.exp(-dt / (to > from ? attack : release)));
    double gate(double v) => v < .055 ? 0 : ((v - .055) / .945).clamp(0.0, 1.0);
    energy = smooth(energy, live ? gate(_energy) : 0, .055, .24);
    bass = smooth(bass, live ? gate(_bass) : 0, .04, .20);
    treble = smooth(treble, live ? gate(_treble) : 0, .07, .22);
    sustained = smooth(sustained, live ? gate(_energy) : 0, 1.2, .5);
    _meanBass = smooth(_meanBass, live ? _bass : 0, .30, .6);
    // Unlike onset-only impulses, a held musical passage keeps driving strings.
    // Bass controls excursion; transient density controls the number/speed of ripples.
    final wasMoving = hasFlow || pulses.isNotEmpty;
    final drive = live ? ((energy - .045) / .65).clamp(0.0, 1.0) : 0.0;
    flow = smooth(flow, drive, .07, .30);
    if (flow < .008) flow = 0;
    _beatDensity *= math.exp(-dt / 1.1);
    density = smooth(density, (_beatDensity + treble * .45).clamp(0.0, 1.0), .14, .65);
    if (hasFlow) phase += dt * (.45 + bass * .50 + density * 1.1 + climax * .30);
    final repaint = wasMoving || hasFlow || pulses.isNotEmpty;
    for (final pulse in pulses) { pulse.age += dt; }
    pulses.removeWhere((p) => p.age >= p.duration);
    if (energy < .001) energy = 0;
    if (bass < .001) bass = 0;
    if (treble < .001) treble = 0;
    if (repaint) notifyListeners();
  }

  /// Normal displacement along a closed perimeter, in logical pixels.
  double displacement(double u, double perimeter, double intensity) {
    var value = 0.0;
    if (hasFlow) {
      final center = (.12 + phase * .13) % 1;
      final width = ((100 + 70 * energy) / math.max(1, perimeter)).clamp(.08, .30);
      final split = (.20 + bass * .5 + climax * .5).clamp(0.0, 1.0);
      for (final direction in const [-1.0, 1.0]) {
        final location = direction > 0 ? center : (1 - center) % 1;
        final distance = (u - location + .5) % 1 - .5;
        if (distance.abs() >= width) continue;
        final envelope = .5 + .5 * math.cos(math.pi * distance / width);
        final wave = math.sin(distance / width * math.pi * (1.2 + 1.5 * density) - phase * math.pi * 2);
        value += envelope * wave * flow * (direction > 0 ? 1 : split) * (2.5 + 4.5 * bass + 3 * climax);
      }
    }
    for (final p in pulses) {
      final life = p.age / p.duration;
      final amplitude = p.strength * math.sin(math.pi * .5 * math.min(1.0, life / .055)) * math.exp(-3.3 * life);
      // At higher energy split into counter-travelling, symmetric lobes.
      final split = (bass * .65 + climax * .65).clamp(0.0, 1.0);
      final travel = p.age * (.15 + .22 * climax);
      for (final direction in const [-1.0, 1.0]) {
        final center = (p.origin + direction * travel) % 1;
        var distance = (u - center + .5) % 1 - .5;
        final width = (65 + 55 * energy) / math.max(1, perimeter);
        if (distance.abs() > width) continue;
        final envelope = .5 + .5 * math.cos(math.pi * distance / width);
        final carrier = math.cos(math.pi * distance / width * (1 + treble));
        final weight = direction > 0 ? 1.0 : split;
        value += amplitude * envelope * carrier * weight * (3.5 + 2.5 * climax);
      }
    }
    return (value * intensity).clamp(-12.0, 12.0);
  }

  void reset() {
    energy = bass = treble = sustained = _energy = _bass = _treble = _meanBass = 0;
    flow = phase = density = _beatDensity = 0;
    _age = _sinceBeat = 10; pulses.clear(); beatCount = 0; notifyListeners();
  }
}

class KdaLinePulse {
  KdaLinePulse(this.strength, this.origin);
  final double strength, origin;
  double age = 0;
  double get duration => .8 + strength * .45;
}
